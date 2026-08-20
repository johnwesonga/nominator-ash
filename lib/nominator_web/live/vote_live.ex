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

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Nominator.PubSub, "voting_settings")
      end

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
       |> assign(:family_token, family_token)
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
                phx-submit="submit_vote"
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
                    id={"voter-id-#{entry.swimmer_id}"}
                    name="ballot[voter_id]"
                    type="hidden"
                    value={entry.swimmer_id}
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
                  <span class="hint" data-role="voting-hint">
                    <%= if @voting_open do %>
                      Start typing a teammate's name to search the roster.
                    <% else %>
                      Voting is currently closed.
                    <% end %>
                  </span>
                  <button
                    id={"submit-vote-#{entry.swimmer_id}"}
                    class="btn btn-primary"
                    type="submit"
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

  def handle_event(
        "submit_vote",
        %{"ballot" => %{"voter_id" => voter_id, "candidate_id" => candidate_id}},
        socket
      ) do
    with true <- voting_open?(),
         {:ok, ballot} <-
           Nominator.Voting.Ballots.get_by_family_token(socket.assigns.family_token),
         %{has_voted: false} = entry <- Enum.find(ballot, &(&1.swimmer_id == voter_id)),
         {:ok, candidate} <- Nominator.Admin.get_swimmer_by_id(candidate_id),
         {:ok, _vote} <-
           Nominator.Voting.create_vote(%{voter_id: voter_id, candidate_id: candidate_id}) do
      Phoenix.PubSub.broadcast(Nominator.PubSub, "votes", :vote_recorded)

      updated_entry =
        entry
        |> Map.put(:has_voted, true)
        |> Map.put(:voted_for_name, candidate.name)

      {:noreply,
       socket
       |> put_flash(:info, "Vote submitted for #{candidate.name}.")
       |> stream_insert(:ballot, updated_entry)}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Voting is currently closed.")}

      nil ->
        {:noreply, put_flash(socket, :error, "That swimmer is not on this family ballot.")}

      %{has_voted: true} ->
        {:noreply,
         socket
         |> put_flash(:error, "That vote has already been submitted.")
         |> refresh_ballot()}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't submit that vote. Please try again.")
         |> refresh_ballot()}
    end
  end

  def handle_event("submit_vote", _params, socket) do
    {:noreply, put_flash(socket, :error, "Choose a swimmer before submitting your vote.")}
  end

  def handle_info({:voting_status_changed, voting_open}, socket) do
    {:noreply,
     socket
     |> assign(:voting_open, voting_open)
     |> push_event("voting-status-changed", %{open: voting_open})}
  end

  defp voting_open? do
    Nominator.Voting.list_voting_settings!()
    |> List.first()
    |> case do
      %{is_open: is_open} when is_open in [true, 1] -> true
      _ -> false
    end
  end

  defp refresh_ballot(socket) do
    case Nominator.Voting.Ballots.get_by_family_token(socket.assigns.family_token) do
      {:ok, ballot} -> stream(socket, :ballot, ballot, reset: true)
      _error -> socket
    end
  end
end
