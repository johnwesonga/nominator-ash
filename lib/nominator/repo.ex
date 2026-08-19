defmodule Nominator.Repo do
  use AshSqlite.Repo,
    otp_app: :nominator
end
