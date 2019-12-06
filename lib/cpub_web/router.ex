defmodule CPubWeb.Router do
  use CPubWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CPubWeb do
    pipe_through :api
  end
end
