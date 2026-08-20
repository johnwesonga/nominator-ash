defmodule Nominator.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Nominator.Accounts.Admin,
        _opts,
        _context
      ) do
    Application.fetch_env(:nominator, :token_signing_secret)
  end
end
