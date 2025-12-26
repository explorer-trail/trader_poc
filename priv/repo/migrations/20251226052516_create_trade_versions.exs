defmodule TraderPoc.Repo.Migrations.CreateTradeVersions do
  use Ecto.Migration

  def change do
    create table(:trade_versions) do
      add :trade_id, references(:trades, on_delete: :delete_all), null: false
      add :version_number, :integer, null: false
      add :price, :decimal, precision: 15, scale: 2, null: false
      add :quantity, :integer, null: false
      add :description, :text
      add :changed_by_id, references(:users, on_delete: :nothing), null: false
      add :change_reason, :text

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:trade_versions, [:trade_id])
    create unique_index(:trade_versions, [:trade_id, :version_number])
  end
end
