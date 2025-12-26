defmodule TraderPoc.Trading.TradeVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trade_versions" do
    field :version_number, :integer
    field :price, :decimal
    field :quantity, :integer
    field :description, :string
    field :change_reason, :string

    belongs_to :trade, TraderPoc.Trading.Trade
    belongs_to :changed_by, TraderPoc.Accounts.User

    field :inserted_at, :utc_datetime
  end

  @doc false
  def changeset(trade_version, attrs) do
    trade_version
    |> cast(attrs, [:version_number, :price, :quantity, :description, :change_reason, :trade_id, :changed_by_id, :inserted_at])
    |> validate_required([:version_number, :price, :quantity, :trade_id, :changed_by_id])
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:version_number, greater_than: 0)
    |> unique_constraint([:trade_id, :version_number], name: :trade_versions_trade_id_version_number_index)
  end
end
