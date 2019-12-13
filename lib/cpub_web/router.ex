defmodule CPubWeb.Router do
  use CPubWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CPubWeb do
    pipe_through :api
    resources "/objects", ObjectController
  end


end
