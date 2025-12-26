defmodule TraderPocWeb.PageController do
  use TraderPocWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
