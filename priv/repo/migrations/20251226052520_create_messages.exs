defmodule TraderPoc.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :trade_id, references(:trades, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :content, :text, null: false

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:messages, [:trade_id])
    create index(:messages, [:inserted_at])
  end
end
