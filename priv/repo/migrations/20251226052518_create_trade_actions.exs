defmodule TraderPoc.Repo.Migrations.CreateTradeActions do
  use Ecto.Migration

  def change do
    create table(:trade_actions) do
      add :trade_id, references(:trades, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :action_type, :string, null: false
      add :details, :map, default: %{}

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:trade_actions, [:trade_id])
    create index(:trade_actions, [:user_id])
    create index(:trade_actions, [:action_type])
  end
end
