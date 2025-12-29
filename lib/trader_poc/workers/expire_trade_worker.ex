defmodule TraderPoc.Workers.ExpireTradeWorker do
  use Oban.Worker, queue: :default

  alias TraderPoc.{Repo, Trading}
  alias TraderPoc.Trading.Trade

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"trade_id" => trade_id}}) do
    case Repo.get(Trade, trade_id) do
      nil ->
        {:ok, :trade_not_found}

      trade ->
        expire_trade(trade)
    end
  end

  defp expire_trade(%Trade{status: status}) when status in ["accepted", "rejected", "expired"] do
    # Trade is already completed or expired, nothing to do
    {:ok, :already_completed}
  end

  defp expire_trade(trade) do
    case Trading.update_trade(trade, %{status: "expired"}) do
      {:ok, updated_trade} ->
        # Broadcast expiry to all participants
        Phoenix.PubSub.broadcast(
          TraderPoc.PubSub,
          "trade:#{updated_trade.id}",
          {:trade_expired, updated_trade}
        )

        {:ok, updated_trade}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
