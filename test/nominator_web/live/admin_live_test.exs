defmodule NominatorWeb.AdminLiveTest do
  use NominatorWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_admin

  test "renders the swimmer roster", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "family@example.com"})

    swimmer =
      Nominator.Admin.create_swimmer!(%{
        name: "Jane Doe",
        group: "Dolphins",
        family_id: family.id
      })

    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#view-admin")
    assert has_element?(view, "#swimmers #swimmers-#{swimmer.id}")
  end

  test "renders an empty roster", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#empty-swimmer-roster")
  end

  test "updates a family email", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "old@example.com"})
    {:ok, view, _html} = live(conn, ~p"/admin")

    view
    |> form("#edit-family-form-#{family.id}", family: %{email: "new@example.com"})
    |> render_submit()

    assert Nominator.Admin.get_family_by_id!(family.id).email == "new@example.com"
  end

  test "adds a family", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin")

    view
    |> form("#add-family-form", family: %{email: "new-family@example.com"})
    |> render_submit()

    assert [family] = Nominator.Admin.list_families!()
    assert family.email == "new-family@example.com"
    assert has_element?(view, "#families #families-#{family.id}")
  end

  test "adds a swimmer to a family", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "swimmer-family@example.com"})
    {:ok, view, _html} = live(conn, ~p"/admin")

    view
    |> form("#add-swimmer-form-#{family.id}",
      swimmer: %{name: "Jane Doe", group: "Dolphins"}
    )
    |> render_submit()

    assert [swimmer] = Nominator.Admin.list_swimmers!()
    assert swimmer.name == "Jane Doe"
    assert swimmer.group == "Dolphins"
    assert swimmer.family_id == family.id
    assert has_element?(view, "#swimmers #swimmers-#{swimmer.id}")
    assert has_element?(view, "#family-swimmer-#{swimmer.id}")
  end

  test "updates a swimmer", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "edit-swimmer@example.com"})

    swimmer =
      Nominator.Admin.create_swimmer!(%{
        name: "Old Name",
        group: "Old Group",
        family_id: family.id
      })

    {:ok, view, _html} = live(conn, ~p"/admin")

    view
    |> form("#edit-swimmer-form-#{swimmer.id}",
      swimmer: %{name: "New Name", group: "New Group"}
    )
    |> render_submit()

    updated_swimmer = Nominator.Admin.get_swimmer_by_id!(swimmer.id)
    assert updated_swimmer.name == "New Name"
    assert updated_swimmer.group == "New Group"
  end

  test "shows whether a swimmer has voted", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "voted@example.com"})

    voter =
      Nominator.Admin.create_swimmer!(%{
        name: "Voter",
        family_id: family.id
      })

    candidate =
      Nominator.Admin.create_swimmer!(%{
        name: "Candidate",
        family_id: family.id
      })

    Nominator.Voting.create_vote!(%{
      voter_id: voter.id,
      candidate_id: candidate.id
    })

    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#vote-status-#{voter.id}.voted-yes")
    assert has_element?(view, "#vote-status-#{candidate.id}.voted-no")
  end

  test "filters the roster", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "search-family@example.com"})

    matching =
      Nominator.Admin.create_swimmer!(%{
        name: "Alpha Swimmer",
        group: "Dolphins",
        family_id: family.id
      })

    other =
      Nominator.Admin.create_swimmer!(%{
        name: "Beta Swimmer",
        group: "Sharks",
        family_id: family.id
      })

    {:ok, view, _html} = live(conn, ~p"/admin")

    view
    |> form("#roster-search-form", search: %{query: "alpha"})
    |> render_change()

    assert has_element?(view, "#swimmers #swimmers-#{matching.id}")
    refute has_element?(view, "#swimmers #swimmers-#{other.id}")
  end

  test "renders an empty results state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#results-panel")
    assert has_element?(view, "#empty-results")
    assert has_element?(view, "#total-votes", "0")
  end

  test "tallies and ranks persisted votes", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "results@example.com"})

    candidate_one =
      Nominator.Admin.create_swimmer!(%{name: "Alpha Candidate", family_id: family.id})

    candidate_two =
      Nominator.Admin.create_swimmer!(%{name: "Beta Candidate", family_id: family.id})

    zero_vote_candidate =
      Nominator.Admin.create_swimmer!(%{name: "No Votes", family_id: family.id})

    voter_one =
      Nominator.Admin.create_swimmer!(%{name: "First Voter", family_id: family.id})

    voter_two =
      Nominator.Admin.create_swimmer!(%{name: "Second Voter", family_id: family.id})

    voter_three =
      Nominator.Admin.create_swimmer!(%{name: "Third Voter", family_id: family.id})

    Nominator.Voting.create_vote!(%{voter_id: voter_one.id, candidate_id: candidate_one.id})
    Nominator.Voting.create_vote!(%{voter_id: voter_two.id, candidate_id: candidate_one.id})
    Nominator.Voting.create_vote!(%{voter_id: voter_three.id, candidate_id: candidate_two.id})

    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#total-votes", "3")
    refute has_element?(view, "#empty-results")
    assert has_element?(view, "#result-#{candidate_one.id}[data-rank='1']")
    assert has_element?(view, "#result-vote-count-#{candidate_one.id}", "2")
    assert has_element?(view, "#result-#{candidate_two.id}[data-rank='2']")
    assert has_element?(view, "#result-vote-count-#{candidate_two.id}", "1")
    refute has_element?(view, "#result-#{zero_vote_candidate.id}")
  end

  test "gives tied candidates the same rank", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "ties@example.com"})

    candidate_one =
      Nominator.Admin.create_swimmer!(%{name: "First Candidate", family_id: family.id})

    candidate_two =
      Nominator.Admin.create_swimmer!(%{name: "Second Candidate", family_id: family.id})

    voter_one = Nominator.Admin.create_swimmer!(%{name: "Voter One", family_id: family.id})
    voter_two = Nominator.Admin.create_swimmer!(%{name: "Voter Two", family_id: family.id})

    Nominator.Voting.create_vote!(%{voter_id: voter_one.id, candidate_id: candidate_one.id})
    Nominator.Voting.create_vote!(%{voter_id: voter_two.id, candidate_id: candidate_two.id})

    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "#result-#{candidate_one.id}[data-rank='1']")
    assert has_element?(view, "#result-#{candidate_two.id}[data-rank='1']")
  end
end
