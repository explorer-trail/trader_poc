defmodule TraderPoc.Repo.Migrations.CreateTrades do
  use Ecto.Migration

  def change do
    create table(:trades) do
      add :title, :string, null: false
      add :description, :text
      add :initial_price, :decimal, precision: 15, scale: 2, null: false
      add :current_price, :decimal, precision: 15, scale: 2, null: false
      add :quantity, :integer, null: false
      add :status, :string, null: false, default: "draft"
      add :seller_id, references(:users, on_delete: :nothing), null: false
      add :buyer_id, references(:users, on_delete: :nothing), null: false
      add :buyer_name, :string, null: false
      add :invitation_code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trades, [:invitation_code])
    create index(:trades, [:seller_id])
    create index(:trades, [:buyer_id])
    create index(:trades, [:status])
  end
end
