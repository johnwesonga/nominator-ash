defmodule Nominator.Voting.Vote do
  use Ash.Resource,
    otp_app: :nominator,
    domain: Nominator.Voting,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "votes"
    repo Nominator.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      argument :voter_id, :uuid, allow_nil?: false
      argument :candidate_id, :uuid, allow_nil?: false

      change manage_relationship(:voter_id, :voter, type: :append_and_remove)

      change manage_relationship(
               :candidate_id,
               :candidate,
               type: :append_and_remove
             )
    end
  end

  attributes do
    uuid_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :voter, Nominator.Admin.Swimmer do
      source_attribute :voter_id
      allow_nil? false
    end

    belongs_to :candidate, Nominator.Admin.Swimmer do
      source_attribute :candidate_id
      allow_nil? false
    end
  end

  identities do
    identity :one_vote_per_voter, [:voter_id]
  end
end
