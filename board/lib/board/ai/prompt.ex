defmodule Board.AI.Prompt do
  @moduledoc """
  모델에 넘길 지시문. 문서 밖 내용은 만들지 말라고 적는다.
  """

  def summarize(text) do
    """
    다음 문서만 근거로 3문장 이내 한국어 요약을 작성하세요.
    문서에 없는 내용은 만들지 마세요.

    #{text}
    """
  end

  def ask(question, excerpts) do
    joined =
      Enum.map_join(excerpts, "\n", fn excerpt ->
        "[발췌 #{excerpt.chunk_index + 1}] #{excerpt.text}"
      end)

    """
    질문: #{question}
    아래 발췌만 근거로 답하세요. 근거가 없으면 "문서에서 찾을 수 없습니다"라고만 답하세요.
    답변 끝에 사용한 발췌 번호를 "(발췌 N)" 형식으로 적으세요.

    #{joined}
    """
  end
end
