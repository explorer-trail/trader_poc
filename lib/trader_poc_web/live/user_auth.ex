defmodule TraderPocWeb.UserAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  alias TraderPoc.Accounts

  def on_mount(:require_authenticated_user, _params, session, socket) do
    case session["user_id"] do
      nil ->
        socket =
          socket
          |> put_flash(:error, "You must be logged in to access this page")
          |> redirect(to: "/")

        {:halt, socket}

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            socket =
              socket
              |> put_flash(:error, "User not found")
              |> redirect(to: "/")

            {:halt, socket}

          user ->
            {:cont, assign(socket, current_user: user)}
        end
    end
  end

  def on_mount(:maybe_authenticated_user, _params, session, socket) do
    case session["user_id"] do
      nil ->
        {:cont, assign(socket, current_user: nil)}

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            {:cont, assign(socket, current_user: nil)}

          user ->
            {:cont, assign(socket, current_user: user)}
        end
    end
  end
end
