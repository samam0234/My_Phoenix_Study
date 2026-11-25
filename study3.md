# study3 · 데이터 다루기

**① 목표**  
소켓 assign, Ecto 스키마, changeset, 브라우저 `localStorage`로 같은 게시글 데이터를 다른 층에 둔다.

## ② 📖 이론

### 왜 쓰는지

화면의 "지금 입력 중인 제목"과 데이터베이스의 "저장된 글"은 수명이 다르다. 입력은 소켓과 브라우저에 잠시 있고, 저장본은 Repo가 디스크의 SQLite에 남긴다. 둘을 한 맵에 섞으면 새로고침과 재시작에서 깨진다.

### 핵심 개념

- **assign**: LiveView 프로세스 메모리. 연결이 끊기면 사라진다.
- **스키마** `Board.Blog.Post`: 테이블 컬럼과 구조체 필드.
- **changeset**: 바깥에서 온 맵을 캐스팅하고 검증한 뒤, 통과한 변경만 DB에 쓴다.
- **virtual 필드** `tags_text`, `comment_count`: 컬럼이 아니다. 폼과 화면 계산용이다.
- **localStorage**: 브라우저만의 저장. 서버로 가기 전 제목 초안을 남긴다.

### 비유

assign은 종업원의 손노트, 스키마는 장부 양식, changeset은 장부에 올리기 전에 지우는 빨간 펜, localStorage는 손님 휴대폰 메모장이다. 메모장은 서버가 꺼져도 남지만 다른 기기에서는 안 보인다.

## ③ 🛠️ 실기

### 전체 코드

스키마의 핵심은 `board/lib/board/blog/post.ex`다.

```elixir
schema "posts" do
  field :title, :string
  field :body, :string
  field :tags, {:array, :string}, default: []
  field :tags_text, :string, virtual: true
  field :comment_count, :integer, virtual: true, default: 0
  belongs_to :author, Board.Accounts.User
  has_many :comments, Board.Blog.Comment
  timestamps(type: :utc_datetime)
end
```

폼은 `Blog.change_post/2`가 `tags_text`를 쉼표로 잘라 `tags` 배열로 바꾼 뒤 `Post.changeset/2`에 넘긴다. 화면은 `<.input field={@form[:title]}>` 로 그 changeset을 묶는다. 값이 바뀌면 `phx-change="validate"`가 새 changeset을 소켓에 다시 assign한다.

제목 초안 훅은 `assets/js/app.js`의 `DraftTitle`이다. `/posts/new`의 제목 입력칸을 감싼 `#draft-title`에 `phx-hook="DraftTitle"`가 붙어 있다.

```javascript
DraftTitle: {
  mounted() {
    const input = this.el.querySelector("input")
    const key = "board-draft-title"
    const saved = localStorage.getItem(key)
    if (saved && !input.value) input.value = saved
    input.addEventListener("input", () => localStorage.setItem(key, input.value))
    const form = this.el.closest("form")
    form && form.addEventListener("submit", () => localStorage.removeItem(key))
  }
}
```

### 줄별 설명

| 위치 | 설명 |
| --- | --- |
| `schema "posts"` | 마이그레이션의 `posts` 테이블과 같은 이름 |
| `field :title, :string` | 컬럼. cast가 문자열로 받는다 |
| `{:array, :string}` | SQLite에는 JSON 문자열로 저장되고 Elixir에서는 리스트다 |
| `virtual: true` | `tags_text`는 SELECT에 없다. 폼이 쉼표 문자열을 들고 있기 위한 자리다 |
| `belongs_to :author` | `author_id` 컬럼과 `User` 구조체를 연결한다 |
| `timestamps(type: :utc_datetime)` | `inserted_at`, `updated_at`. API에서는 `createdAt`, `updatedAt`으로 이름을 바꾼다 |
| `change_post` | 화면용 changeset. 저장 함수도 같은 검증을 탄다 |
| `phx-change` | 키 입력마다 서버가 changeset을 다시 만들어 오류 문장을 돌려준다 |
| `localStorage.getItem` | 새로고침 뒤 제목을 복구한다. 서버 메모리와는 별개다 |
| `submit`에서 removeItem | 저장에 성공해 폼이 제출되면 초안을 지운다 |

데이터를 화면에 묶는 방법은 한 가지다. changeset → `to_form` → `<.input field={@form[:title]}>` → 사용자는 보고, `handle_event`가 다시 changeset을 만든다.

## ④ 🔗 연동 포인트

이 스키마의 `id`, `title`, `body`, `tags`, `author`, `comment_count`, `inserted_at`이 study6 `PostJSON`의 `data` 필드가 된다. `author_id`는 로그인 사용자에서 넣고, 요청 바디로는 받지 않는다. localStorage 초안은 서버 API로 가지 않는다. 저장 버튼을 눌러야 `Blog.create_post/2`가 Repo에 쓴다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `tags`가 문자열로 저장되려다 실패 | 폼은 `tags_text`, API는 리스트 | `normalize_attrs/1`이 둘 다 리스트로 맞춘다 |
| 댓글 수가 항상 0 | virtual 필드는 DB가 채우지 않음 | 조회 때 `count`를 구조체에 다시 넣는다 |
| 초안이 안 돌아옴 | 훅이 `input`을 못 찾음 | `#draft-title` 안에 `<.input>`이 있는지 확인 |
| 다른 브라우저에 초안이 없음 | localStorage는 그 브라우저만의 저장 | 정상이다. 공유 데이터는 DB다 |

## ⑥ 직접 해보기

1. `/posts/new`에 제목만 입력하고 새로고침한다. 제목이 남아 있어야 한다.
2. `iex -S mix`에서 `Board.Blog.change_post(%Board.Blog.Post{}, %{"title" => ""})`의 `valid?`가 거짓인지 본다.
3. 개발자 도구 Application 탭에서 `board-draft-title` 키를 지우고 입력이 비는지 확인한다.

## ⑦ ☐ 체크리스트

- [ ] assign, 스키마 필드, virtual 필드를 구분했다
- [ ] changeset이 빈 제목을 거절하는 것을 봤다
- [ ] 폼 필드와 `@form`이 연결된다
- [ ] localStorage 초안이 새로고침 뒤에 남고, 제출 뒤 지워진다

## ⑧ 다음 단계

데이터가 준비되면 [study4.md](study4.md)에서 URL이 그 데이터를 어떻게 집어오는지 연결한다.
