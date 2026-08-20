# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Nominator.Repo.insert!(%Nominator.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

case Nominator.Voting.list_voting_settings!() do
  [] -> Nominator.Voting.create_voting_settings!(%{is_open: 1})
  _settings -> :ok
end
