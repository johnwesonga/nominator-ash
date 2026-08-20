defmodule Mix.Tasks.Nominator.Admin.Create do
  use Mix.Task

  @shortdoc "Creates the first Nominator administrator"

  @moduledoc """
  Creates an administrator from the `ADMIN_EMAIL` and `ADMIN_PASSWORD`
  environment variables.

      ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD='a strong password' \
        mix nominator.admin.create

  The task refuses to create a second administrator with the same email.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    email = fetch_env!("ADMIN_EMAIL")
    password = fetch_env!("ADMIN_PASSWORD")

    if String.length(password) < 8 do
      Mix.raise("ADMIN_PASSWORD must contain at least 8 characters")
    end

    params = %{
      email: email,
      password: password,
      password_confirmation: password
    }

    Nominator.Accounts.Admin
    |> Ash.Changeset.for_create(:register_with_password, params)
    |> Ash.create(authorize?: false)
    |> case do
      {:ok, _admin} ->
        Mix.shell().info("Administrator created for #{email}")

      {:error, error} ->
        Mix.raise("Could not create administrator: #{Ash.Error.error_descriptions(error)}")
    end
  end

  defp fetch_env!(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> value
      _ -> Mix.raise("Missing required environment variable #{name}")
    end
  end
end
