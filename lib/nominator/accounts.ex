defmodule Nominator.Accounts do
  use Ash.Domain,
    otp_app: :nominator

  resources do
    resource Nominator.Accounts.Token
    resource Nominator.Accounts.Admin
  end
end
