defmodule TraderPoc.Repo.Migrations.AddExpirationToTrades do
  use Ecto.Migration

  def change do
    alter table(:trades) do
      add :expires_at, :utc_datetime
      add :oban_job_id, :bigint
    end

    # Also add "expired" as a valid status
    execute """
    ALTER TABLE trades DROP CONSTRAINT IF EXISTS trades_status_check;
    """, ""

    execute """
    ALTER TABLE trades ADD CONSTRAINT trades_status_check
    CHECK (status IN ('draft', 'in_negotiation', 'accepted', 'rejected', 'expired'));
    """, """
    ALTER TABLE trades DROP CONSTRAINT IF EXISTS trades_status_check;
    """
  end
end
