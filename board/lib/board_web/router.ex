defmodule BoardWeb.Router do
  use BoardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BoardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug BoardWeb.Plugs.FetchUser
  end

  pipeline :public_json do
    plug :accepts, ["json"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug BoardWeb.Plugs.Authenticate
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug BoardWeb.Plugs.Authenticate
    plug BoardWeb.Plugs.RequireAuth
  end

  pipeline :api_credentials do
    plug :accepts, ["json"]
    plug BoardWeb.Plugs.RateLimit, limit: 10, window: 60
  end

  scope "/", BoardWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/hello", PageController, :hello
    get "/session/adopt", SessionController, :adopt
    delete "/session", SessionController, :delete
    get "/auth/oauth/mock", OauthController, :request
    get "/auth/oauth/mock/callback", OauthController, :callback
    post "/documents", DocumentController, :create
    get "/api-docs", ApiDocsController, :index

    live_session :public, on_mount: [{BoardWeb.UserAuth, :mount_current_user}] do
      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Form, :new
      live "/posts/:id", PostLive.Show, :show
      live "/posts/:id/edit", PostLive.Form, :edit
      live "/login", AuthLive.Login, :new
      live "/signup", AuthLive.Signup, :new
      live "/me", AuthLive.Me, :show
      live "/documents", DocumentLive.Index, :index
      live "/documents/:id", DocumentLive.Show, :show
    end
  end

  scope "/", BoardWeb do
    pipe_through :public_json

    get "/health", HealthController, :show
    get "/api-docs/openapi.json", ApiDocsController, :spec
  end

  scope "/api", BoardWeb do
    pipe_through :api_credentials

    post "/auth/signup", AuthController, :signup
    post "/auth/login", AuthController, :login
  end

  scope "/api", BoardWeb do
    pipe_through :api

    get "/posts", PostController, :index
    get "/posts/:id", PostController, :show
    get "/posts/:id/comments", CommentController, :index
  end

  scope "/api", BoardWeb do
    pipe_through :api_auth

    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
    post "/posts", PostController, :create
    patch "/posts/:id", PostController, :update
    delete "/posts/:id", PostController, :delete
    post "/posts/:id/comments", CommentController, :create
    delete "/comments/:id", CommentController, :delete
    get "/documents", DocumentController, :index
    post "/documents", DocumentController, :create
    get "/documents/:id", DocumentController, :show
    post "/documents/:id/questions", DocumentController, :ask
    post "/ai/summarize/stream", AiController, :stream
  end

  if Application.compile_env(:board, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BoardWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
