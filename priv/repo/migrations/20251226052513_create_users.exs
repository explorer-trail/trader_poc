defmodule TraderPoc.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:users, [:name])
  end
end
