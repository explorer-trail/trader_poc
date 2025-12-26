defmodule TraderPoc.Trading.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string

    belongs_to :trade, TraderPoc.Trading.Trade
    belongs_to :user, TraderPoc.Accounts.User

    field :inserted_at, :utc_datetime
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :trade_id, :user_id, :inserted_at])
    |> validate_required([:content, :trade_id, :user_id])
    |> validate_length(:content, min: 1, max: 5000)
  end
end
