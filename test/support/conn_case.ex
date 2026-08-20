defmodule NominatorWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use NominatorWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint NominatorWeb.Endpoint

      use NominatorWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import NominatorWeb.ConnCase
    end
  end

  setup tags do
    Nominator.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def register_and_log_in_admin(%{conn: conn} = context) do
    {seeded_admin, password} = create_admin()

    strategy = AshAuthentication.Info.strategy!(Nominator.Accounts.Admin, :password)

    {:ok, admin} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: seeded_admin.email,
        password: password
      })

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(admin)

    context
    |> Map.put(:admin, admin)
    |> Map.put(:conn, conn)
  end

  def create_admin do
    email = "admin-#{System.unique_integer([:positive])}@example.com"
    password = "valid admin password"
    {:ok, hashed_password} = AshAuthentication.BcryptProvider.hash(password)

    admin =
      Ash.Seed.seed!(Nominator.Accounts.Admin, %{
        email: email,
        hashed_password: hashed_password
      })

    {admin, password}
  end
end
