defmodule Board.Jobs.SummaryWorker do
  @moduledoc """
  문서 요약을 차례로 처리하는 프로세스.
  화면 요청은 summarize_now/1, 백그라운드는 enqueue/1.
  """

  use GenServer
  alias Board.AI.Client
  alias Board.Documents
  alias Board.Repo
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def enqueue(document_id), do: GenServer.cast(__MODULE__, {:summarize, document_id})

  def summarize_now(document_id),
    do: GenServer.call(__MODULE__, {:summarize, document_id}, 30_000)

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:summarize, document_id}, state) do
    _ = do_summarize(document_id)
    {:noreply, state}
  end

  @impl true
  def handle_call({:summarize, document_id}, _from, state) do
    {:reply, do_summarize(document_id), state}
  end

  defp do_summarize(document_id) do
    document = Repo.get(Board.Documents.Document, document_id)

    cond do
      is_nil(document) ->
        {:error, :not_found}

      true ->
        case Client.summarize(document.original_text) do
          {:ok, summary} ->
            Documents.save_summary(document, summary)

          {:error, reason} ->
            Logger.warning("summary failed document=#{document_id}")
            {:error, reason}
        end
    end
  end
end
