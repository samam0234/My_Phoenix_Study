# study15 · 성능과 캐시

**① 목표**  
게시글 첫 페이지를 짧게 캐시하고, 문서 요약을 프로세스 큐로 넘기며, 병목이 어디인지 재는 방법을 Phoenix 안에서 정리한다.

## ② 📖 이론

### 왜 쓰는지

같은 목록을 새로고침할 때마다 같은 SQL을 돌리면 글이 늘수록 느려진다. 반대로 요약을 요청 안에서 끝까지 기다리면 업로드 응답이 모델 시간만큼 길어진다. 자주 같은 결과는 짧게 저장하고, 오래 걸리는 일은 순서를 지켜 뒤에서 처리한다.

### 핵심 개념

- **ETS 캐시**: `Board.Blog.Cache`. 키 `posts:first`, TTL 15초. 테스트는 `:cache_enabled`가 false라 항상 DB를 본다.
- **무효화**: 글이 생기거나 바뀌거나 지워지면 `Cache.invalidate("posts:first")`.
- **캐시 조건**: 1페이지, limit 10, 검색어 없음, 정렬 `-createdAt`일 때만.
- **백그라운드**: `Board.Jobs.SummaryWorker` GenServer. `summarize_now/1`은 응답을 기다리고, `enqueue/1`은 넣고 바로 돌아온다.
- **측정**: `BoardWeb.Telemetry`와 `liveSocket.enableLatencySim(1000)`.

### 비유

캐시는 계산대 옆 10초짜리 메모지고, 워커는 주방에서 한 장씩 처리하는 주문서다. 메모지 시간이 지나면 다시 주방에서 확인하고, 메뉴가 바뀌면 메모지를 바로 버린다.

## ③ 🛠️ 실기

목록은 `Board.Blog.list_posts/1`이 로더를 캐시에 넘긴다.

```elixir
def fetch(key, loader) when is_function(loader, 0) do
  if Application.get_env(:board, :cache_enabled, true) do
    now = System.system_time(:second)

    case :ets.lookup(@table, key) do
      [{^key, value, expires}] when expires > now ->
        value

      _other ->
        value = loader.()
        :ets.insert(@table, {key, value, now + @ttl})
        value
    end
  else
    loader.()
  end
end
```

| 줄 | 설명 |
| --- | --- |
| `:board_cache` | 이름이 있는 ETS. 앱 시작 때 `Cache.setup/0` |
| `expires > now` | 15초 안이면 DB 함수를 부르지 않는다 |
| `loader.()` | 캐시가 없을 때만 목록 SQL |
| `now + @ttl` | `@ttl`은 15 |
| 테스트 false | 샌드박스가 다른 프로세스의 ETS를 보지 않게 |

가입과 로그인은 `RateLimit`이 IP와 경로를 60초 창으로 센다. 기본 한도는 호출부 옵션이고, 넘으면 429 `RATE_LIMITED`와 `retry-after`다. 테스트에서는 꺼 둔다.

문서 등록은 기본이 `summarize_now`다. `create_document(user, attrs, async: true)`이면 `enqueue`만 하고 요약 칸은 잠시 비어 있다. 워커는 한 프로세스라 요약이 동시에 겹쳐 DB를 두 번 쓰지 않는다. 실패는 로그만 남기고 문서 행은 유지한다.

재는 순서:

1. 개발자도구 네트워크에서 `GET /api/posts?page=1`을 두 번 호출하고 시간을 적는다.
2. 15초 안에 두 번째가 같은 JSON인지 본다. 글을 하나 만들면 캐시 키가 지워져 다음 조회는 DB다.
3. `iex -S mix`에서 `:telemetry_test` 없이, 엔드포인트 로그의 `GET /api/posts` 마이크로초를 비교한다.
4. 브라우저 콘솔 `liveSocket.enableLatencySim(1000)`으로 화면 지연만 재현하고, 끝나면 `disableLatencySim()` 한다.

## ④ 🔗 연동 포인트

캐시 값은 study6 목록과 같은 `{posts, meta}`다. 글 변경 방송(study17) 직전에 캐시를 지우므로, 다른 브라우저 목록이 옛 첫 페이지를 다시 그리지 않는다. 워커가 저장한 `summary`는 study18 화면과 `/api/documents/:id`가 읽는다. 운영에서 프로세스가 여러 대면 이 ETS는 그 노드 안에서만 보인다. 그때는 study11의 서버 DB와 별개로 캐시 위치를 다시 정해야 하고, 이 학습 앱은 노드 하나 ETS로 둔다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 지운 글이 15초간 목록에 남음 | invalidate를 빼먹음 | `after_post`가 성공 뒤에만 키를 지운다 |
| 검색 결과가 첫 페이지와 같음 | 검색에도 캐시를 씀 | `cacheable?/1`이 `q: nil`일 때만 true |
| 테스트가 이전 목록을 봄 | 테스트에서 캐시가 켜짐 | `:cache_enabled`는 test에서 false |
| 업로드가 모델만큼 느림 | `summarize_now` | 연습으로 `async: true`를 넘긴다 |
| 429가 정상 가입을 막음 | 같은 IP로 반복 | `retry-after`초 만큼 기다린다. 테스트 환경은 제한이 꺼져 있다 |

## ⑥ 직접 해보기

1. 목록 API를 두 번 부른 뒤 글을 만들고 세 번째 응답에 새 글이 있는지 확인한다.
2. 같은 IP로 로그인 API를 한도보다 많이 호출해 429 `RATE_LIMITED`를 본다.
3. `async: true`로 문서를 만들고, 직후 응답의 `summary`와 잠시 뒤 상세의 `summary`를 비교한다.

## ⑦ ☐ 체크리스트

- [ ] 첫 페이지 캐시가 15초이며 글 변경 시 지워진다
- [ ] 검색과 2페이지는 캐시를 타지 않는다
- [ ] 테스트에서는 캐시와 호출 제한이 꺼져 있다
- [ ] 요약 워커의 즉시 호출과 넣기만 하는 호출을 구분했다
- [ ] 지연 시간 또는 요청 로그로 한 번은 숫자를 적었다

## ⑧ 다음 단계

측정한 앱을 같은 방식으로 매번 올리려면 [study16.md](study16.md)의 이미지와 자동 테스트가 필요하다.
