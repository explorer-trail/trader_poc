defmodule TraderPoc.Trading.TradeAction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trade_actions" do
    field :action_type, :string
    field :details, :map

    belongs_to :trade, TraderPoc.Trading.Trade
    belongs_to :user, TraderPoc.Accounts.User

    field :inserted_at, :utc_datetime
  end

  @valid_action_types ~w(created invited joined amended accepted rejected amendment_requested message_sent)

  @doc false
  def changeset(trade_action, attrs) do
    trade_action
    |> cast(attrs, [:action_type, :details, :trade_id, :user_id, :inserted_at])
    |> validate_required([:action_type, :trade_id, :user_id])
    |> validate_inclusion(:action_type, @valid_action_types)
  end
end
