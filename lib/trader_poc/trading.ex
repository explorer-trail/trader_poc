defmodule TraderPoc.Trading do
  @moduledoc """
  The Trading context.
  """

  import Ecto.Query, warn: false
  alias TraderPoc.Repo

  alias TraderPoc.Trading.{Trade, TradeVersion, TradeAction, Message}
  alias TraderPoc.Accounts

  @doc """
  Returns the list of trades for a specific user (either as seller or buyer).

  ## Examples

      iex> list_trades(user_id)
      [%Trade{}, ...]

  """
  def list_trades(user_id) do
    Trade
    |> where([t], t.seller_id == ^user_id or t.buyer_id == ^user_id)
    |> preload([:seller, :buyer])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns all trades in the system (for admin/dashboard views).

  ## Examples

      iex> list_all_trades()
      [%Trade{}, ...]

  """
  def list_all_trades do
    Trade
    |> preload([:seller, :buyer])
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single trade by invitation code.

  Returns `nil` if the Trade does not exist.

  ## Examples

      iex> get_trade_by_code("ABC123")
      %Trade{}

      iex> get_trade_by_code("invalid")
      nil

  """
  def get_trade_by_code(invitation_code) do
    Trade
    |> where([t], t.invitation_code == ^invitation_code)
    |> preload([:seller, :buyer])
    |> Repo.one()
  end

  @doc """
  Gets a single trade by ID.

  Returns `nil` if the Trade does not exist.
  """
  def get_trade(id) do
    Trade
    |> preload([:seller, :buyer])
    |> Repo.get(id)
  end

  @doc """
  Creates a trade.

  ## Examples

      iex> create_trade(%{field: value}, seller_id)
      {:ok, %Trade{}}

      iex> create_trade(%{field: bad_value}, seller_id)
      {:error, %Ecto.Changeset{}}

  """
  def create_trade(attrs \\ %{}, seller_id) do
    # Get or create buyer
    buyer_name = attrs["buyer_name"] || attrs[:buyer_name]
    {:ok, buyer} = Accounts.get_or_create_user(buyer_name)

    # Generate unique invitation code
    invitation_code = generate_invitation_code()

    # Get price from attrs
    price = attrs["price"] || attrs[:price]

    # Prepare trade attributes with string keys
    trade_attrs = %{
      "title" => attrs["title"] || attrs[:title],
      "description" => attrs["description"] || attrs[:description],
      "quantity" => attrs["quantity"] || attrs[:quantity],
      "buyer_name" => buyer_name,
      "seller_id" => seller_id,
      "buyer_id" => buyer.id,
      "invitation_code" => invitation_code,
      "initial_price" => price,
      "current_price" => price
    }

    # Create trade in a transaction
    Repo.transaction(fn ->
      with {:ok, trade} <- do_create_trade(trade_attrs),
           {:ok, _version} <- create_initial_version(trade, seller_id),
           {:ok, _action} <- log_action(trade, seller_id, "created", %{initial_price: trade.initial_price}) do
        trade
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp do_create_trade(attrs) do
    %Trade{}
    |> Trade.changeset(attrs)
    |> Repo.insert()
  end

  defp create_initial_version(trade, user_id) do
    %TradeVersion{}
    |> TradeVersion.changeset(%{
      trade_id: trade.id,
      version_number: 1,
      price: trade.current_price,
      quantity: trade.quantity,
      description: trade.description,
      changed_by_id: user_id,
      inserted_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Updates a trade.

  ## Examples

      iex> update_trade(trade, %{field: new_value})
      {:ok, %Trade{}}

      iex> update_trade(trade, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trade(%Trade{} = trade, attrs) do
    trade
    |> Trade.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Amends a trade, creating a new version.

  ## Examples

      iex> amend_trade(trade, %{price: 900}, user_id)
      {:ok, %Trade{}}

  """
  def amend_trade(%Trade{} = trade, attrs, user_id) do
    Repo.transaction(fn ->
      # Get the latest version number
      latest_version = get_latest_version_number(trade.id)
      new_version_number = latest_version + 1

      # Update trade with new values
      new_price = attrs["price"] || attrs[:price] || trade.current_price
      new_quantity = attrs["quantity"] || attrs[:quantity] || trade.quantity
      new_description = attrs["description"] || attrs[:description] || trade.description

      trade_attrs = %{
        current_price: new_price,
        quantity: new_quantity,
        description: new_description
      }

      with {:ok, updated_trade} <- update_trade(trade, trade_attrs),
           {:ok, _version} <- create_version(updated_trade, new_version_number, user_id, attrs["change_reason"] || attrs[:change_reason]),
           {:ok, _action} <- log_action(updated_trade, user_id, "amended", %{version: new_version_number, price: new_price, quantity: new_quantity}) do
        updated_trade
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp create_version(trade, version_number, user_id, change_reason) do
    %TradeVersion{}
    |> TradeVersion.changeset(%{
      trade_id: trade.id,
      version_number: version_number,
      price: trade.current_price,
      quantity: trade.quantity,
      description: trade.description,
      changed_by_id: user_id,
      change_reason: change_reason,
      inserted_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp get_latest_version_number(trade_id) do
    TradeVersion
    |> where([v], v.trade_id == ^trade_id)
    |> select([v], max(v.version_number))
    |> Repo.one()
    |> case do
      nil -> 0
      number -> number
    end
  end

  @doc """
  Accepts a trade.

  ## Examples

      iex> accept_trade(trade, user_id)
      {:ok, %Trade{}}

  """
  def accept_trade(%Trade{} = trade, user_id) do
    Repo.transaction(fn ->
      with {:ok, updated_trade} <- update_trade(trade, %{status: "accepted"}),
           {:ok, _action} <- log_action(updated_trade, user_id, "accepted", %{final_price: updated_trade.current_price}) do
        updated_trade
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Rejects a trade.

  ## Examples

      iex> reject_trade(trade, user_id)
      {:ok, %Trade{}}

  """
  def reject_trade(%Trade{} = trade, user_id) do
    Repo.transaction(fn ->
      with {:ok, updated_trade} <- update_trade(trade, %{status: "rejected"}),
           {:ok, _action} <- log_action(updated_trade, user_id, "rejected", %{}) do
        updated_trade
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Requests an amendment to a trade.

  ## Examples

      iex> request_amendment(trade, user_id, "Please lower the price")
      {:ok, %TradeAction{}}

  """
  def request_amendment(%Trade{} = trade, user_id, reason) do
    log_action(trade, user_id, "amendment_requested", %{reason: reason})
  end

  @doc """
  Logs an action for a trade.

  ## Examples

      iex> log_action(trade, user_id, "created", %{})
      {:ok, %TradeAction{}}

  """
  def log_action(%Trade{} = trade, user_id, action_type, details \\ %{}) do
    %TradeAction{}
    |> TradeAction.changeset(%{
      trade_id: trade.id,
      user_id: user_id,
      action_type: action_type,
      details: details,
      inserted_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Updates trade status to in_negotiation when buyer joins.
  """
  def mark_buyer_joined(%Trade{} = trade, user_id) do
    Repo.transaction(fn ->
      with {:ok, updated_trade} <- update_trade(trade, %{status: "in_negotiation"}),
           {:ok, _action} <- log_action(updated_trade, user_id, "joined", %{}) do
        updated_trade
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns the list of versions for a trade.

  ## Examples

      iex> list_versions(trade_id)
      [%TradeVersion{}, ...]

  """
  def list_versions(trade_id) do
    TradeVersion
    |> where([v], v.trade_id == ^trade_id)
    |> preload(:changed_by)
    |> order_by([v], desc: v.version_number)
    |> Repo.all()
  end

  @doc """
  Returns the list of actions for a trade.

  ## Examples

      iex> list_actions(trade_id)
      [%TradeAction{}, ...]

  """
  def list_actions(trade_id) do
    TradeAction
    |> where([a], a.trade_id == ^trade_id)
    |> preload(:user)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(trade, user_id, "Hello!")
      {:ok, %Message{}}

  """
  def create_message(%Trade{} = trade, user_id, content) do
    Repo.transaction(fn ->
      with {:ok, message} <- do_create_message(trade, user_id, content),
           {:ok, _action} <- log_action(trade, user_id, "message_sent", %{content: content}) do
        message
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp do_create_message(trade, user_id, content) do
    %Message{}
    |> Message.changeset(%{
      trade_id: trade.id,
      user_id: user_id,
      content: content,
      inserted_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Returns the list of messages for a trade.

  ## Examples

      iex> list_messages(trade_id)
      [%Message{}, ...]

  """
  def list_messages(trade_id) do
    Message
    |> where([m], m.trade_id == ^trade_id)
    |> preload(:user)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  # Generate a unique invitation code
  defp generate_invitation_code do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
    |> String.upcase()
  end
end
