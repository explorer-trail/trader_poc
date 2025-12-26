defmodule TraderPoc.Trading.Trade do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trades" do
    field :title, :string
    field :description, :string
    field :initial_price, :decimal
    field :current_price, :decimal
    field :quantity, :integer
    field :status, :string, default: "draft"
    field :buyer_name, :string
    field :invitation_code, :string

    belongs_to :seller, TraderPoc.Accounts.User
    belongs_to :buyer, TraderPoc.Accounts.User

    has_many :versions, TraderPoc.Trading.TradeVersion
    has_many :actions, TraderPoc.Trading.TradeAction
    has_many :messages, TraderPoc.Trading.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trade, attrs) do
    trade
    |> cast(attrs, [:title, :description, :initial_price, :current_price, :quantity, :status, :buyer_name, :invitation_code, :seller_id, :buyer_id])
    |> validate_required([:title, :initial_price, :current_price, :quantity, :buyer_name, :seller_id, :buyer_id])
    |> validate_number(:initial_price, greater_than: 0)
    |> validate_number(:current_price, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_inclusion(:status, ["draft", "in_negotiation", "accepted", "rejected"])
    |> unique_constraint(:invitation_code)
  end
end
