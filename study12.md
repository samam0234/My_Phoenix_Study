# study12 · 프런트와 UI 연동

**① 목표**  
Phoenix 안에서 Tailwind, 코어 컴포넌트, 소켓 상태, changeset 폼을 한 화면으로 묶는다.

## ② 📖 이론

### 왜 쓰는지

HEEx만으로도 동작하지만, 버튼과 입력의 간격이 없으면 검증 오류가 있는지 알아보기 어렵다. Phoenix 1.8 생성 앱은 Tailwind 4와 daisyUI, `CoreComponents`의 버튼·입력을 이미 포함한다. 화면 상태는 별도 저장소 라이브러리 없이 LiveView assign이 맡는다.

### 핵심 개념

- **UI**: `assets/css/app.css`의 Tailwind, 클래스 `btn`, `input`, `textarea`.
- **컴포넌트**: `BoardWeb.CoreComponents`의 `<.input>`, `<.button>` 자리. 우리 폼은 `<.input field={...}>`를 쓴다.
- **상태**: `assign`과 `stream`. 목록 항목은 DOM id로 부분 갱신된다.
- **폼**: `to_form(changeset)`. 입력 이름 `post[title]`이 서버 맵 키가 된다.
- **JS 훅**: 서버 상태에 둘 필요가 없는 초안만 `DraftTitle` 훅이 맡는다.

### 비유

Tailwind는 진열대 치수, 코어 컴포넌트는 규격 상자, assign은 계산대의 현재 주문표다. 주문표를 브라우저 전역 변수에 복사해 두면 서버와 두 장이 되어 어긋난다. 그래서 글 내용은 소켓에만 둔다.

## ③ 🛠️ 실기

### 화면이 붙는 순서

1. `root.html.heex`가 `/assets/css/app.css`와 `/assets/js/app.js`를 읽는다.
2. `Layouts.app`이 위쪽 메뉴와 `<.flash_group>`을 그린다.
3. LiveView `render/1`이 그 안에 제목과 폼을 넣는다.
4. `<.input field={@form[:body]} type="textarea" label="본문">`이 라벨, 값, 오류를 함께 그린다.
5. 검색 입력은 `phx-debounce="300"`으로 키 입력마다 요청이 나가지 않게 한다.

상태 변경은 전부 서버 함수다.

```elixir
{:noreply, assign(socket, :form, form)}
{:noreply, stream_insert(socket, :posts, post, at: 0)}
```

브라우저에 상태 라이브러리를 추가하지 않는다. 디버그는 콘솔의 `liveSocket.enableDebug()`다.

폼 라이브러리를 따로 설치하지 않는 이유: changeset + `to_form` + `<.input>`이 값, 이름, 오류를 이미 묶기 때문이다. `<.form for={@form} phx-change="validate" phx-submit="save">`가 그 묶음의 시작이다.

### 줄별 설명

| 줄 | 설명 |
| --- | --- |
| `class="btn btn-primary"` | daisyUI 버튼. 컴포넌트 `<.button>`도 `btn` 클래스를 만든다 |
| `<.input field>` | `form[field].id`, `name`, `value`, `errors`를 읽는다 |
| `type="textarea"` | 본문처럼 여러 줄 |
| `phx-debounce="300"` | 300ms 동안 더 입력하면 이전 검색 요청을 보내지 않는다 |
| `stream` | 행 단위 갱신. 목록 전체를 innerHTML로 갈아끼우지 않는다 |
| `DraftTitle` | 서버 assign과 별개인 브라우저 초안 |
| `Layouts.app` | `current_user`로 메뉴를 바꾼다. 로그인 상태는 여기 한곳 |

## ④ 🔗 연동 포인트

폼이 성공하면 study4의 `push_navigate`로 상세 URL에 간다. 입력값은 study5 changeset을 통과한 뒤 study6 Repo에 저장된다. 메뉴의 닉네임은 study7 세션 사용자다. 나중에 다른 호스트의 화면이 이 API를 부르면 study8의 `CORS_ORIGIN`만 맞춘다. 그 화면을 이 저장소에 합치지 않는다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 스타일이 없음 | 에셋 워처가 안 뜸 | `mix phx.server` 로그에 tailwind, esbuild가 있는지 |
| 입력 이름이 `title`만 감 | `for` 폼이 없음 | `<.form for={@form}>` 안에서 `<.input field>` |
| 목록이 통째로 깜빡임 | stream 없이 전체 assign만 사용 | `phx-update="stream"`과 `id` |
| 훅이 두 번 복구 | `updated`에서 값을 다시 씀 | `mounted`에서만 localStorage를 읽는다 |

## ⑥ 직접 해보기

1. 브라우저 너비를 줄여 메뉴와 본문 여백이 깨지지 않는지 본다.
2. 검색창에 빠르게 타이핑하고 네트워크 탭에서 요청이 글자마다 나가지 않는지 본다.
3. `<.input>`을 일반 `<input>`으로 바꿨을 때 오류 문장이 사라지는지 확인하고 되돌린다.

## ⑦ ☐ 체크리스트

- [ ] Tailwind/daisyUI 클래스가 버튼과 입력에 적용된다
- [ ] 화면 상태가 assign과 stream에 있다
- [ ] 폼은 changeset과 `<.input>`으로 오류까지 묶인다
- [ ] 브라우저 훅은 초안만 맡고 글 저장은 서버가 한다

## ⑧ 다음 단계

화면이 안정되면 [study13.md](study13.md)에서 메일, 파일, 소셜 로그인처럼 앱 밖 서비스를 붙인다.
