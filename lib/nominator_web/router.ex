defmodule NominatorWeb.Router do
  use NominatorWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NominatorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :admin
  end

  scope "/", NominatorWeb do
    pipe_through :browser

    ash_authentication_live_session :admin_authentication_required,
      on_mount: [{NominatorWeb.LiveAdminAuth, :admin_required}] do
      live "/admin", AdminLive
    end
  end

  scope "/", NominatorWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/vote/:id", VoteLive
    auth_routes AuthController, Nominator.Accounts.Admin, path: "/auth"
    sign_out_route AuthController

    sign_in_route reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{NominatorWeb.LiveAdminAuth, :no_admin}],
                  overrides: [
                    NominatorWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  NominatorWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]
  end

  # Other scopes may use custom stacks.
  # scope "/api", NominatorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:nominator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NominatorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
