defmodule TraderPoc.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias TraderPoc.Repo

  alias TraderPoc.Accounts.User

  @doc """
  Gets a single user.

  Returns `nil` if the User does not exist.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets or creates a user by name.

  ## Examples

      iex> get_or_create_user("Alice")
      {:ok, %User{}}

  """
  def get_or_create_user(name) when is_binary(name) do
    case Repo.get_by(User, name: name) do
      nil ->
        %User{}
        |> User.changeset(%{name: name})
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
