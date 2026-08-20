defmodule Nominator.Voting do
  use Ash.Domain,
    otp_app: :nominator

  resources do
    resource Nominator.Voting.Vote do
      define :create_vote, action: :create
      define :list_votes, action: :read
    end

    resource Nominator.Voting.VotingSettings do
      define :list_voting_settings, action: :read
      define :create_voting_settings, action: :create
      define :update_voting_settings, action: :update
    end
  end
end
