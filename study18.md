# study18 · AI와 MCP

**① 목표**  
문서 본문을 요약하고, 발췌만 근거로 답하며, 그 호출을 스트리밍 응답과 MCP 도구로 Phoenix 안에서 연다.

## ② 📖 이론

### 왜 쓰는지

긴 글을 올릴 때마다 사람이 세 줄로 줄이지 않아도 되게 하려면, 모델 호출을 앱의 한 함수로 숨겨야 한다. 모델이 없을 때도 학습이 되게 가짜 답을 두고, 있을 때만 주소와 키를 환경 변수로 바꾼다. MCP는 그 함수를 에디터 같은 다른 프로세스가 표준 입력 JSON으로 부르게 하는 얇은 입구다.

노션의 AI 미니 프로젝트 DocuForge는 문서를 올리고, 요약하고, 문서 발췌를 근거로 질문에 답하는 흐름이다. 이 글은 그 흐름만 Phoenix 한 앱의 텍스트(txt, md) 예제로 다시 만든다. 다른 언어로 만든 DocuForge 서버를 호출하지 않는다. DocuForge 초안에는 로그인이 없지만, 이 보드는 글을 사용자에게 붙이므로 문서도 로그인한 사용자 것으로 저장한다.

### 핵심 개념

- **드라이버**: `AI_DRIVER=mock`(기본), `ollama`, `openai`.
- **프롬프트**: `Board.AI.Prompt`. 문서 밖 내용을 만들지 말 것, 근거가 없으면 "문서에서 찾을 수 없습니다".
- **발췌**: `Board.AI.Search`. 임베딩 없이 단어와 두 글자 묶음이 겹치는 조각만 고른다.
- **스트리밍**: `POST /api/ai/summarize/stream`이 `text/event-stream`으로 토큰을 자른다. 기본 mock은 완성된 요약을 공백으로 나누어 보낸다.
- **MCP**: `mix board.mcp`. 프로토콜 `2024-11-05`. 도구 `summarize_document`, `ask_document`.

### 비유

mock은 주방에 요리사가 없을 때 내놓는 정찰 메뉴다. 프롬프트는 주문서에 "메뉴판에 있는 것만"이라고 적는 일이고, MCP는 홀의 다른 직원이 같은 주방에 쪽지로 주문하는 창구다.

## ③ 🛠️ 실기

### 화면과 API

1. 로그인 후 `/documents`에서 txt 또는 md를 올린다.
2. `SummaryWorker`가 `Client.summarize/1`을 호출하고 `documents.summary`에 저장한다.
3. 상세에서 질문을 보내면 `Search.top_excerpts/3`로 상위 3조각을 고르고, `Prompt.ask/2`로 답을 만든다.
4. 겹치는 조각이 없으면 모델 없이 "문서에서 찾을 수 없습니다."를 저장한다.

요약 지시문:

```elixir
def summarize(text) do
  """
  다음 문서만 근거로 3문장 이내 한국어 요약을 작성하세요.
  문서에 없는 내용은 만들지 마세요.

  #{text}
  """
end
```

| 줄 | 설명 |
| --- | --- |
| "다음 문서만" | 학습 데이터로 사실을 보태지 말라는 지시 |
| "3문장 이내" | 요약 길이 |
| `#{text}` | 사용자가 올린 본문. 프롬프트와 본문을 한 문자열로 보낸다 |

mock 요약은 공백을 줄인 앞 80자에 `요약: `을 붙인다. ollama는 `AI_API_URL`(기본 `http://127.0.0.1:11434`)의 `/api/generate`, openai는 `/v1/chat/completions`다. 키는 `AI_API_KEY`다. 상태 코드가 200대가 아니거나 본문이 비면 `{:error, :unavailable}`이고 HTTP는 502 `AI_UNAVAILABLE`이다.

스트림 한 덩어리는 `data: {"token":"요약:"}\n\n` 형태이고 마지막에 `data: [DONE]\n\n`이다. `decode_ollama_line/1`은 Ollama NDJSON의 `response`와 `done`을 읽는다. 지금 스트림 응답은 한 번에 받은 답을 잘라 보내는 연습이다.

### MCP

```bash
cd board
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | mix board.mcp
```

`tools/list` 다음에 `tools/call`로 `summarize_document`에 `arguments.text`를 넘긴다. `ask_document`는 `text`와 `question`이 둘 다 있어야 한다. 없으면 JSON-RPC 오류 `-32602`다. 알림처럼 `id`가 없는 메시지는 응답을 쓰지 않는다.

## ④ 🔗 연동 포인트

입력 파일은 study13 업로드 규칙(txt, md, 10MB, UTF-8)을 그대로 쓴다. 요약 저장은 study15 워커다. 문서는 study7 사용자 id로 걸러서 남의 문서는 404다. 스트림과 MCP는 같은 `Client.summarize/1`을 쓴다. 모델을 켜려면 study16 compose의 `AI_DRIVER`만 바꾸고, 키는 환경 변수로 둔다. 게시판 API 스펙의 오류 모양(`error.code`)은 스트림이 아닌 JSON 오류에 적용된다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 요약이 `요약: `으로 시작 | `AI_DRIVER`가 mock | 로컬 모델이 있을 때만 ollama로 바꾼다 |
| 502 `AI_UNAVAILABLE` | 주소 거부, 타임아웃, 빈 본문 | `AI_API_URL`, `AI_TIMEOUT`, 서버 로그의 status |
| 답이 문서 밖 내용 | 프롬프트를 빼거나 발췌가 아닌 전문만 보냄 | `Prompt.ask`와 `top_excerpts`를 유지 |
| MCP가 아무 것도 안 찍음 | JSON이 한 줄이 아니거나 id 없음 | 한 줄 JSON에 `id`를 넣는다 |
| 다른 사용자 문서가 보임 | 조회에 user_id 조건이 없음 | `get_document/2`가 id와 user_id를 같이 본다 |

## ⑥ 직접 해보기

1. 짧은 md를 올리고 상세의 요약이 비어 있지 않은지 본다.
2. 본문에 없는 단어를 질문해서 "문서에서 찾을 수 없습니다"가 나오는지 확인한다.
3. `initialize` 한 줄을 `mix board.mcp`에 넣어 `protocolVersion`이 `2024-11-05`인지 본다.

## ⑦ ☐ 체크리스트

- [ ] mock이 기본이고 키를 소스에 적지 않았다
- [ ] 요약 프롬프트가 문서 밖 내용을 만들지 말라고 적는다
- [ ] 질문은 발췌가 있을 때만 모델 호출로 이어진다
- [ ] 스트림이 `text/event-stream`과 `[DONE]`으로 끝난다
- [ ] MCP 도구 이름 `summarize_document`, `ask_document`를 호출해 봤다
- [ ] DocuForge의 올리기·요약·발췌 답을 Phoenix 문서 기능과 대응했다

## ⑧ 다음 단계

게시판, DB, 외부 입출력, 배포, 실시간, 문서 AI를 한 점검으로 닫는 글이 [studyFinal.md](studyFinal.md)다.
