defmodule Nominator.Voting.VotingSettings do
  use Ash.Resource,
    otp_app: :nominator,
    domain: Nominator.Voting,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "voting_settings"
    repo Nominator.Repo
  end

  actions do
    defaults [:read, create: [:is_open, :closed_at], update: [:is_open, :closed_at]]
  end

  attributes do
    uuid_primary_key :id

    attribute :is_open, :integer do
      allow_nil? false
      public? true
    end

    attribute :closed_at, :datetime do
      allow_nil? true
      public? true
    end

    timestamps()
  end
end
