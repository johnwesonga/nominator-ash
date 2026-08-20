defmodule Nominator.Admin.Swimmer do
  use Ash.Resource,
    otp_app: :nominator,
    domain: Nominator.Admin,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "swimmers"
    repo Nominator.Repo
  end

  actions do
    defaults [:read, :destroy, update: [:name, :group]]

    create :create do
      accept [:name, :group]

      argument :family_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:family_id, :family, type: :append_and_remove)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :group, :string do
      allow_nil? true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :family, Nominator.Admin.Family do
      destination_attribute :id
      allow_nil? false
    end

    has_one :cast_vote, Nominator.Voting.Vote do
      destination_attribute :voter_id
    end
  end
end
