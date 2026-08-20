defmodule Nominator.Admin.Family do
  use Ash.Resource,
    otp_app: :nominator,
    domain: Nominator.Admin,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "families"
    repo Nominator.Repo
  end

  actions do
    defaults [:read, :destroy, update: [:email]]

    create :create do
      accept [:email]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
    end

    attribute :family_token, :uuid do
      default &Ash.UUID.generate/0
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    has_many :swimmers, Nominator.Admin.Swimmer do
      destination_attribute :family_id
    end
  end

  identities do
    identity :unique_name, [:email]
    identity :unique_family_token, [:family_token]
  end
end
