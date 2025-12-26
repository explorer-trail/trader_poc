defmodule TraderPocWeb.Router do
  use TraderPocWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TraderPocWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TraderPocWeb do
    pipe_through :browser

    # Public routes
    live "/", HomeLive, :index

    # Session management
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete

    # Authenticated routes
    live_session :require_authenticated_user,
      on_mount: [{TraderPocWeb.UserAuth, :require_authenticated_user}] do
      live "/trades", TradeListLive, :index
      live "/trades/new", TradeFormLive, :new
      live "/room/:invitation_code", TradeRoomLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", TraderPocWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trader_poc, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TraderPocWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
