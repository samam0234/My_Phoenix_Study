# study14 · API 설계

**① 목표**  
REST 경로, OpenAPI 문서, 버전을 깨지 않는 방법, 페이지네이션, 오류 본문 규칙을 한 스펙으로 고정한다.

## ② 📖 이론

### 왜 쓰는지

화면과 클라이언트가 경로 이름을 따로 정하면 수정할 때마다 둘 다 깨진다. 문서는 `/api-docs`에 두고, 버전은 기본 경로 `/api`를 v1으로 유지한다. 호환이 깨지는 변경만 `/api/v2`를 새로 연다.

### 핵심 개념

- **자원 이름**: 복수, 소문자. `/api/posts`, `/api/comments`. 동사 경로를 만들지 않는다.
- **메서드**: 읽기 GET, 생성 POST, 부분 수정 PATCH, 삭제 DELETE.
- **문서**: `priv/openapi.json`을 `GET /api-docs/openapi.json`이 돌려준다.
- **페이지**: `page`는 1부터, `limit` 기본 10, 최대 50.
- **오류**: 항상 `error.code`, `error.message`, `error.requestId`. 검증만 `fields`.

### 비유

API는 식당 주문 번호 체계다. 메뉴 이름이 바뀌어도 주문 번호 자릿수를 갑자기 바꾸지 않는다. OpenAPI는 그 번호 체계를 붙인 메뉴판이다.

## ③ 🛠️ 실기

### 경로

study6 표와 같다. 추가 자원:

| 메서드 | 경로 | 설명 |
| --- | --- | --- |
| GET | `/api/documents` | 내 문서 |
| POST | `/api/documents` | 본문 등록, 201 |
| GET | `/api/documents/:id` | 내 문서만. 아니면 404 |
| POST | `/api/documents/:id/questions` | 질문 |
| POST | `/api/ai/summarize/stream` | `text/event-stream` |

### 오류 규칙

| 상태 | code |
| --- | --- |
| 400 | `VALIDATION_ERROR` 또는 `BAD_REQUEST` |
| 401 | `UNAUTHORIZED`, `INVALID_CREDENTIALS` |
| 403 | `FORBIDDEN` |
| 404 | `NOT_FOUND` |
| 409 | `EMAIL_TAKEN` |
| 413 | `PAYLOAD_TOO_LARGE` |
| 429 | `RATE_LIMITED` |
| 500 | `INTERNAL` |
| 502 | `AI_UNAVAILABLE` |

500 본문에는 예외 원문을 넣지 않는다.

### 버전

현재 클라이언트는 `/api/posts`를 v1으로 본다. 필드 이름을 지우거나 타입을 바꾸는 변경은 `/api/v2/posts`를 새로 만들고 v1을 당장 지우지 않는다. 필드를 추가하는 것만으로는 버전을 올리지 않는다.

### 줄별 설명 (`openapi.json`)

| 항목 | 설명 |
| --- | --- |
| `openapi: 3.0.3` | 문서 형식 |
| `paths./api/posts.get.parameters` | q, page, limit, sort |
| `page minimum 1` | 0페이지를 계약으로 받지 않음 |
| `limit maximum 50` | 서버가 50으로 자르는 계약과 같음 |
| 201, 204 | 생성과 삭제의 본문 유무가 다름 |
| `/api-docs` HTML | 사람이 여는 입구. JSON은 기계가 읽는다 |

## ④ 🔗 연동 포인트

study6 구현이 이 문서의 경로와 같아야 한다. 테스트 `ApiTest`가 상태 코드와 `meta`를 고정하므로, 문서를 바꿀 때는 테스트를 같이 고친다. 페이지 응답의 `meta.totalPages`는 프런트 "다음" 버튼이 `page < totalPages`인지 보는 값이다. 오류 `requestId`는 study9 로그와 같다.

## ⑤ 오류 노트

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 문서와 실제 경로가 다름 | json을 고치지 않고 라우터만 변경 | 라우터와 `openapi.json`을 같이 수정 |
| 삭제 응답에 `data: null` | 204에 본문을 넣음 | `send_resp(conn, 204, "")` |
| 목록이 0페이지 | page를 0부터 셈 | `Pagination`이 1 미만을 1로 |
| 검증 오류에 스택 | `inspect(exception)`을 JSON에 넣음 | code와 message만 |

## ⑥ 직접 해보기

1. `/api-docs`에서 JSON 링크를 열고 `/api/posts` 항목이 있는지 본다.
2. 없는 경로 `GET /api/nope`의 code가 `NOT_FOUND`인지 확인한다.
3. 필드를 하나 추가한다면 v2가 필요한지, 추가만으로는 v1을 유지할 수 있는지 한 문장으로 적는다.

## ⑦ ☐ 체크리스트

- [ ] 자원 경로가 복수 명사이고 동사로 시작하지 않는다
- [ ] OpenAPI JSON이 `/api-docs/openapi.json`에서 열린다
- [ ] page, limit, sort 규칙이 문서와 코드에 같다
- [ ] 오류 코드 표를 테스트 하나 이상과 대응했다
- [ ] 호환을 깨는 변경만 새 버전 경로를 쓴다고 적었다

## ⑧ 다음 단계

계약이 고정되면 [study15.md](study15.md)에서 그 계약의 응답을 캐시와 백그라운드로 가볍게 만든다.
