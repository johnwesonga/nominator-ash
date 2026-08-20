defmodule Nominator.Admin do
  use Ash.Domain,
    otp_app: :nominator

  resources do
    resource Nominator.Admin.Family do
      define :list_families, action: :read
      define :create_family, action: :create
      define :update_family, action: :update
      define :delete_family, action: :destroy

      define :get_family_by_id,
        action: :read,
        get_by: [:id]

      define :get_family_by_token,
        action: :read,
        get_by: [:family_token]
    end

    resource Nominator.Admin.Swimmer do
      define :list_swimmers, action: :read
      define :create_swimmer, action: :create
      define :update_swimmer, action: :update
      define :delete_swimmer, action: :destroy

      define :get_swimmer_by_id,
        action: :read,
        get_by: [:id]

      define :get_swimmers_by_family_id,
        action: :read,
        get_by: [:family_id]

      define :get_swimmers_by_family_token,
        action: :read,
        get_by: [:family_token]
    end
  end
end
