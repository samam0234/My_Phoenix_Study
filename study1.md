# study1 · Hello World와 기본 문법

**① 목표**  
첫 HTML을 띄우고, 패턴 매칭과 파이프가 HEEx에 어떻게 찍히는지 본다.

## ② 📖 이론

### 왜 쓰는지

라우터와 데이터베이스 전에, 요청이 함수를 거쳐 화면 글자가 되는지부터 확인한다. Elixir는 `if`보다 함수를 여러 머리로 나누는 패턴 매칭을 자주 쓴다. 파이프 `|>`는 앞의 결과를 다음 함수의 첫 인자로 넘긴다.

### 핵심 개념

- **컨트롤러**: `PageController.hello/2`가 쿼리를 받아 준비한다.
- **HEEx**: HTML 안의 `{@greeting}` 이 값을 출력한다. `<script>` 같은 입력은 글자로 이스케이프된다.
- **패턴 매칭**: `classify/1`처럼 인자 모양으로 함수를 고른다.
- **가드**: `when is_integer(n) and n > 0` 처럼 조건이 맞을 때만 그 머리를 탄다.
- **라이브 리로드**: 개발 중 템플릿을 저장하면 브라우저가 다시 그린다. `config/runtime.exs`의 `live_reload` 패턴이 `lib/board_web/**/*.heex`를 감시한다.

### 비유

파이프는 컨베이어 벨트다. 이름을 올리고, 공백을 자르고, 소문자로 바꾸고, 빈칸을 하이픈으로 바꾼 결과가 벨트 끝의 주소용 이름이다. 패턴 매칭은 창구를 여러 개 두고 양수 창구, 0 창구, 음수 창구로 손님을 나누는 일이다.

## ③ 🛠️ 실기

경로: `http://localhost:4000/hello` 와 `http://localhost:4000/hello?name=Mina`

### 전체 코드

`board/lib/board/syntax.ex`

```elixir
defmodule Board.Syntax do
  def greet(name) when is_binary(name) do
    case String.trim(name) do
      "" -> "안녕하세요, Phoenix"
      trimmed -> "안녕하세요, #{trimmed}"
    end
  end

  def greet(_other), do: "안녕하세요, Phoenix"

  def pipeline_demo(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/u, "-")
  end

  def pipeline_demo(_other), do: "phoenix"

  def classify(n) when is_integer(n) and n > 0, do: :positive
  def classify(0), do: :zero
  def classify(n) when is_integer(n) and n < 0, do: :negative
  def classify(_other), do: :other
end
```

`board/lib/board_web/controllers/page_controller.ex`의 `hello/2`는 `name` 쿼리가 없으면 `"Phoenix"`를 넣고, `Board.Syntax` 결과와 샘플 세 개를 템플릿에 넘긴다.

`board/lib/board_web/controllers/page_html/hello.html.heex`는 `{@greeting}`, `{@slug}`, `{number} → {kind}`, `{@name}`을 출력한다.

### 줄별 설명 (`syntax.ex`)

| 줄 | 설명 |
| --- | --- |
| 1 | 모듈 이름. 호출은 `Board.Syntax.greet/1` |
| 2 | 문자열이 들어올 때만 이 머리를 쓴다 |
| 3-4 | 앞뒤 공백을 자른 뒤 빈 문자열이면 기본 인사 |
| 5 | 남은 문자열을 인사 문장에 끼운다. `#{}`는 보간 |
| 8 | 문자열이 아니면 여기로 떨어진다. `_other`는 값을 안 쓴다는 표시 |
| 10-16 | 파이프. trim → downcase → 공백을 `-`로 |
| 18 | 파이프를 탈 수 없는 값의 기본 슬러그 |
| 20 | 0보다 큰 정수만 `:positive` |
| 21 | 정확히 `0`이면 `:zero`. 가드보다 이 정확한 머리가 먼저 매칭되려면 위에 두면 안 되므로, 양수 가드가 0을 통과시키지 않아 이 줄에 도달한다 |
| 22 | 나머지 정수는 `:negative` |
| 23 | 정수가 아니면 `:other` |

HEEx `{@name}`은 HTML로 해석하지 않는다. `name=<script>`를 넘겨도 태그로 실행되지 않고 `&lt;script&gt;`로 보인다. 테스트 `GET /hello escapes the name`이 이 점을 고정한다.

개발자 도구(F12)의 Elements에서 이스케이프된 문자를 확인하고, Network에서 문서가 `200`인지 본다. 템플릿을 저장하면 터미널에 리로드 로그가 남고 브라우저가 새로고침된다. `assets/js/app.js`의 `liveSocket.connect()`가 LiveView용 소켓이고, 이 Hello 페이지는 일반 컨트롤러라 전체 새로고침으로 갱신된다.

## ④ 🔗 연동 포인트

`PageController.hello/2`가 만든 `@greeting`은 다음 단계의 화면 데이터와 같은 자리다. study2의 LiveView는 이 값을 소켓 `assign`에 두고, 페이지를 다시 받지 않고 조각만 바꾼다. 쿼리 `?name=`은 study4의 쿼리 파라미터와 같은 요청 정보다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `UndefinedFunctionError Board.Syntax.greet/1` | 모듈이 컴파일되지 않음 | `mix compile` 또는 서버 재시작 |
| 화면이 예전 문구 | 브라우저 캐시 또는 다른 포트 | 새로고침, 주소가 4000인지 확인 |
| 한글이 깨짐 | 파일 인코딩이 UTF-8이 아님 | 에디터에서 UTF-8로 저장 |
| 라이브 리로드가 안 됨 | `MIX_ENV=prod`로 실행 | 개발은 `mix phx.server` (기본 dev) |

## ⑥ 직접 해보기

1. `/hello?name=Elixir`에서 인사가 `안녕하세요, Elixir`인지, 슬러그가 `elixir`인지 확인한다.
2. 이름을 `<b>굵게</b>`로 넣고 화면에 굵은 글씨가 아니라 글자 그대로 보이는지 개발자 도구로 본다.
3. `hello.html.heex`의 제목을 고치고 저장했을 때 브라우저가 바뀌는지 본다.

## ⑦ ☐ 체크리스트

- [ ] `/` 첫 화면과 `/hello`가 200으로 열린다
- [ ] `greet/1`, `pipeline_demo/1`, `classify/1`의 결과를 화면에서 봤다
- [ ] `{@name}`이 태그를 실행하지 않고 이스케이프한다
- [ ] 개발 서버 저장 시 브라우저가 갱신되고, 개발자 도구로 HTML을 확인했다

## ⑧ 다음 단계

문법이 화면에 닿으면 [study2.md](study2.md)에서 라우터, 컨트롤러, LiveView, HEEx가 서로를 어떻게 부르는지 만든다.
