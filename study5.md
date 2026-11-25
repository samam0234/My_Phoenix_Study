# study5 · 폼, 입력, 검증

**① 목표**  
사용자 입력을 changeset으로 검사하고, 오류 문장을 보여 주며, 저장 버튼을 중복으로 누르지 못하게 한다. JSON API는 200대 성공, 400 검증 실패, 422를 같은 오류 화면 분기로 받을 수 있게 한다.

## ② 📖 이론

### 왜 쓰는지

빈 제목은 데이터베이스에 들어가면 안 된다. 검사 실패를 서버 예외로 두면 사용자는 원인 없이 500만 본다. changeset 오류를 필드 문장으로 돌려주고, 저장 중에는 버튼을 잠가 같은 글을 두 번 넣지 않는다.

### 핵심 개념

- **validate**: `phx-change`마다 `action: :validate`를 달아 오류를 미리 보여 준다.
- **save**: `phx-submit`에서 `create_post/2` 또는 `update_post/2`.
- **phx-disable-with**: 제출 직후 버튼 문구를 "저장 중..."으로 바꾸고 다시 누르지 못하게 한다.
- **상태 코드**: 이 앱의 검증 실패는 공통 스펙에 맞춰 **400** `VALIDATION_ERROR`다. 화면 분기는 400과 422를 같은 필드 오류로 취급할 수 있다. 201/200은 성공이다.

### 비유

changeset은 창구 직원이다. 필수 칸이 비면 도장을 찍지 않고 칸 옆에 이유를 적는다. 도장을 찍는 동안 접수 버튼을 손으로 막아 두 장 접수되지 않게 한다.

## ③ 🛠️ 실기

### 전체 코드

회원가입 검증은 `Board.Accounts.User.form_changeset/2`다. 이메일 형식, 닉네임 길이, 비밀번호 8자 이상을 본다. 저장용 `registration_changeset/2`는 거기에 이메일 유니크와 비밀번호 해시를 더한다. 폼에서는 해시를 하지 않아서 입력 중인 비밀번호가 지워지지 않는다.

게시글 폼 `PostLive.Form`:

```elixir
def handle_event("validate", %{"post" => params}, socket) do
  form =
    socket.assigns.post
    |> Blog.change_post(params)
    |> Map.put(:action, :validate)
    |> to_form()

  {:noreply, assign(socket, :form, form)}
end

def handle_event("save", %{"post" => params}, socket) do
  socket = assign(socket, :submitting, true)
  save(socket, socket.assigns.live_action, params)
end
```

템플릿 버튼:

```heex
<button class="btn btn-primary" phx-disable-with="저장 중..." disabled={@submitting}>
  저장
</button>
```

JSON은 `FallbackController`가 changeset을 400으로 바꾼다.

```elixir
BoardWeb.ApiError.send(
  conn,
  400,
  "VALIDATION_ERROR",
  "입력값을 확인하세요.",
  BoardWeb.ApiError.fields(changeset)
)
```

응답 예:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "입력값을 확인하세요.",
    "fields": {"title": ["필수입니다."]},
    "requestId": "..."
  }
}
```

화면을 나누는 기준은 다음 함수로 생각하면 된다. LiveView는 상태 코드 없이 changeset을 직접 받고, `fetch`를 쓰는 클라이언트는 코드를 본다.

```javascript
function showResult(response, body) {
  if (response.status === 201 || response.status === 200) return "저장됨"
  if (response.status === 400 || response.status === 422) return body.error.fields
  return body.error.message
}
```

이 프로젝트의 검증 응답은 400이다. 422 분기를 같이 둔 이유는 다른 클라이언트가 같은 필드 모양을 422로 보낼 때도 문장을 잃지 않기 위해서다.

### 줄별 설명

| 줄 | 설명 |
| --- | --- |
| `"validate"` | `phx-change` 이름과 같아야 한다 |
| `%{"post" => params}` | 폼 이름이 `post`라 입력이 한 단계 감싸진다 |
| `Map.put(:action, :validate)` | action이 nil이면 일부 입력 컴포넌트가 오류를 숨긴다 |
| `to_form` | changeset을 HEEx 입력 필드가 읽는 구조로 바꾼다 |
| `:submitting` | 서버가 저장을 처리하는 동안 버튼을 막는다 |
| 실패 시 `submitting: false` | 오류가 나면 다시 누를 수 있어야 한다 |
| `fields/1` | `{메시지, 옵션}`을 문자열 리스트로 편다 |
| 이메일 유니크 | changeset 제약이면 400이 아니라 409 `EMAIL_TAKEN` |

## ④ 🔗 연동 포인트

폼이 성공하면 `push_navigate`로 `/posts/:id`로 간다. API가 성공하면 `201`과 `Location: /api/posts/:id`다. 둘 다 같은 `Blog.create_post/2`를 탄다. 필드 오류 키 `title`, `body`, `tags`는 study6 오류 본문의 `fields`와 같다. 로그인 폼의 실패는 필드가 아니라 401 `INVALID_CREDENTIALS` 한 문장이다. 어느 쪽이 틀렸는지 말하지 않는다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 오류가 안 보임 | changeset `action`이 nil | `:validate` 또는 `:insert`를 넣는다 |
| 버튼을 연타하면 글이 두 개 | disable이 없음 | `phx-disable-with`와 `:submitting` |
| 422를 기다렸는데 400 | 이 앱은 스펙 v1을 따른다 | 화면은 400과 422를 같은 분기에서 처리 |
| 비밀번호가 입력 중에 사라짐 | 폼 changeset에서 해시하며 `delete_change` | 폼용 changeset과 저장용 changeset을 나눈다 |

## ⑥ 직접 해보기

1. `/posts/new`에서 제목을 비우고 본문만 입력해 제목 오류가 보이는지 확인한다.
2. `POST /api/posts`에 빈 JSON을 보내고 `error.fields`가 있는지 본다.
3. 저장 버튼을 누르는 동안 문구가 "저장 중..."으로 바뀌는지 본다.

## ⑦ ☐ 체크리스트

- [ ] `phx-change` 검증과 `phx-submit` 저장을 나눴다
- [ ] 필드 오류 문장이 입력칸 옆에 나온다
- [ ] 중복 제출을 `phx-disable-with`로 막았다
- [ ] 200/201은 성공, 400은 검증 실패, 422도 같은 필드 오류로 다루도록 분기했다

## ⑧ 다음 단계

검증된 값을 디스크와 JSON으로 내보내는 일이 [study6.md](study6.md)다.
