defmodule TraderPocWeb.SessionController do
  use TraderPocWeb, :controller

  alias TraderPoc.Accounts

  def create(conn, %{"name" => name}) do
    case Accounts.get_or_create_user(String.trim(name)) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome, #{user.name}!")
        |> put_session(:user_id, user.id)
        |> redirect(to: "/trades")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Invalid name. Please try again.")
        |> redirect(to: "/")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: "/")
  end
end
