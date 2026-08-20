defmodule NominatorWeb.VoteLiveTest do
  use NominatorWeb.ConnCase

  import Phoenix.LiveViewTest

  test "submits and persists a selected candidate", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "voting-family@example.com"})

    voter =
      Nominator.Admin.create_swimmer!(%{
        name: "Voting Swimmer",
        family_id: family.id
      })

    candidate_family =
      Nominator.Admin.create_family!(%{email: "candidate-family@example.com"})

    candidate =
      Nominator.Admin.create_swimmer!(%{
        name: "Inspirational Candidate",
        family_id: candidate_family.id
      })

    {:ok, view, _html} = live(conn, ~p"/vote/#{family.family_token}")

    assert has_element?(view, "#vote-form-#{voter.id}[phx-submit='submit_vote']")

    render_submit(view, "submit_vote", %{
      "ballot" => %{
        "voter_id" => voter.id,
        "candidate" => candidate.name,
        "candidate_id" => candidate.id
      }
    })

    assert [vote] = Nominator.Voting.list_votes!()
    assert vote.voter_id == voter.id
    assert vote.candidate_id == candidate.id
    assert has_element?(view, "#ballot-#{voter.id} .voted-row")
    refute has_element?(view, "#vote-form-#{voter.id}")
  end

  test "rejects a voter who is not part of the token's family ballot", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "token-family@example.com"})

    ballot_voter =
      Nominator.Admin.create_swimmer!(%{
        name: "Ballot Voter",
        family_id: family.id
      })

    other_family = Nominator.Admin.create_family!(%{email: "other-family@example.com"})

    other_voter =
      Nominator.Admin.create_swimmer!(%{
        name: "Other Voter",
        family_id: other_family.id
      })

    {:ok, view, _html} = live(conn, ~p"/vote/#{family.family_token}")

    render_submit(view, "submit_vote", %{
      "ballot" => %{"voter_id" => other_voter.id, "candidate_id" => ballot_voter.id}
    })

    assert Nominator.Voting.list_votes!() == []
    assert has_element?(view, "#vote-form-#{ballot_voter.id}")
  end

  test "rejects a second vote for the same swimmer", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "duplicate-family@example.com"})

    voter =
      Nominator.Admin.create_swimmer!(%{
        name: "Single Vote Swimmer",
        family_id: family.id
      })

    candidate =
      Nominator.Admin.create_swimmer!(%{
        name: "First Candidate",
        family_id: family.id
      })

    Nominator.Voting.create_vote!(%{voter_id: voter.id, candidate_id: candidate.id})

    {:ok, view, _html} = live(conn, ~p"/vote/#{family.family_token}")

    render_submit(view, "submit_vote", %{
      "ballot" => %{"voter_id" => voter.id, "candidate_id" => candidate.id}
    })

    assert [_vote] = Nominator.Voting.list_votes!()
    assert has_element?(view, "#ballot-#{voter.id} .voted-row")
  end
end
