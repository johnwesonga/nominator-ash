defmodule NominatorWeb.VoteLive do
  use NominatorWeb, :live_view

  def mount(%{"id" => family_token}, _session, socket) do
    with {:ok, ballot} <-
           Nominator.Voting.Ballots.get_by_family_token(family_token) do
      candidates = Nominator.Admin.list_swimmers!()

      candidate_options =
        candidates
        |> Enum.map(fn candidate ->
          %{id: candidate.id, name: candidate.name, group: candidate.group || "No group"}
        end)
        |> Jason.encode!()

      settings =
        Nominator.Voting.list_voting_settings!()
        |> List.first()

      ballot_forms =
        Map.new(ballot, fn entry ->
          {entry.swimmer_id,
           to_form(%{"candidate" => ""},
             as: :ballot,
             id: "ballot-form-#{entry.swimmer_id}"
           )}
        end)

      {:ok,
       socket
       |> assign(:voting_open, settings && settings.is_open in [true, 1])
       |> assign(:ballot_forms, ballot_forms)
       |> assign(:candidate_options, candidate_options)
       |> stream(:ballot, ballot, dom_id: fn entry -> "ballot-#{entry.swimmer_id}" end)}
    else
      _error ->
        {:ok,
         socket
         |> put_flash(:error, "That voting link is invalid.")
         |> push_navigate(to: ~p"/")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="view-parent" class="view active">
        <div class="ballot-intro">
          <h1>Vote: Most Inspirational Swimmer</h1>
          <p>
            One vote per swimmer below — you're welcome to nominate your own child. <strong>Votes can't be changed once submitted</strong>, so take your time on each one.
          </p>
        </div>

        <div id="ballot" phx-update="stream">
          <section
            :for={{id, entry} <- @streams.ballot}
            id={id}
            class="lane"
            data-lane={entry.lane_number}
          >
            <div class="lane-number"><span>{entry.lane_number}</span></div>
            <div class="lane-head">
              <div>
                <span class="eyebrow">Vote for</span>
                <h2>{entry.swimmer_name}</h2>
              </div>
              <span class={[
                "status-pill",
                if(entry.has_voted, do: "done", else: "open")
              ]}>
                {if entry.has_voted, do: "Submitted", else: "Not yet submitted"}
              </span>
            </div>

            <%= if entry.has_voted do %>
              <div class="voted-row">
                <span class="check">✓</span>
                <span class="txt">
                  Vote submitted for <b>{entry.voted_for_name}</b>
                </span>
              </div>
            <% else %>
              <.form
                for={@ballot_forms[entry.swimmer_id]}
                id={"vote-form-#{entry.swimmer_id}"}
                phx-hook="CandidateAutocomplete"
                phx-update="ignore"
                data-candidates={@candidate_options}
                data-voting-open={to_string(@voting_open)}
              >
                <div class="search-wrap">
                  <.input
                    field={@ballot_forms[entry.swimmer_id][:candidate]}
                    type="text"
                    placeholder="Start typing a teammate's name..."
                    disabled={!@voting_open}
                    autocomplete="off"
                    data-role="candidate-search"
                  />
                  <input
                    id={"candidate-id-#{entry.swimmer_id}"}
                    name="ballot[candidate_id]"
                    type="hidden"
                    value=""
                    data-role="candidate-id"
                  />
                </div>
                <div class="lane-foot">
                  <span class="hint">
                    <%= if @voting_open do %>
                      Start typing a teammate's name to search the roster.
                    <% else %>
                      Voting is currently closed.
                    <% end %>
                  </span>
                  <button
                    class="btn btn-primary"
                    type="button"
                    data-role="submit-vote"
                    disabled
                  >
                    Submit this vote
                  </button>
                </div>
              </.form>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
