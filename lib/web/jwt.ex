defmodule CPub.Web.JWT do
  @moduledoc """
  Token configuration for Joken.
  """

  use Joken.Config

  import Joken, only: [current_time: 0]

  alias CPub.Config

  @doc """
  Customizes default token generation and validation.
  """
  @spec token_config :: Joken.token_config()
  def token_config do
    gen_exp_func = fn -> current_time() + Config.oauth2_token_expires_in() end

    %{}
    |> add_claim("iss", fn -> Config.base_url() end, &(&1 == Config.base_url()))
    |> add_claim("iat", fn -> current_time() end)
    |> add_claim("exp", gen_exp_func, &(&1 > current_time()))
  end
end
