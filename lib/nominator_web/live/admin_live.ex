defmodule NominatorWeb.AdminLive do
  use NominatorWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Nominator.PubSub, "votes")
    end

    swimmers =
      Nominator.Admin.list_swimmers!()
      |> Ash.load!([:family, cast_vote: :candidate], domain: Nominator.Admin)

    families =
      Nominator.Admin.list_families!()
      |> Ash.load!(:swimmers, domain: Nominator.Admin)

    results = Nominator.Voting.Results.list()
    voting_settings = Nominator.Voting.list_voting_settings!() |> List.first()
    voting_open = voting_settings && voting_settings.is_open in [true, 1]

    family_forms =
      Map.new(families, fn family ->
        {family.id,
         to_form(%{"email" => family.email},
           as: :family,
           id: "edit-family-#{family.id}"
         )}
      end)

    swimmer_forms =
      Map.new(families, fn family ->
        {family.id,
         to_form(%{"name" => "", "group" => ""},
           as: :swimmer,
           id: "add-swimmer-#{family.id}"
         )}
      end)

    swimmer_edit_forms =
      Map.new(swimmers, fn swimmer ->
        {swimmer.id,
         to_form(%{"name" => swimmer.name, "group" => swimmer.group || ""},
           as: :swimmer,
           id: "edit-swimmer-#{swimmer.id}"
         )}
      end)

    {:ok,
     socket
     |> assign(:swimmer_count, length(swimmers))
     |> assign(:families_count, length(families))
     |> assign(:roster_count, length(swimmers))
     |> assign(:voting_settings, voting_settings)
     |> assign(:voting_open, voting_open)
     |> assign(:results_empty?, results == [])
     |> assign(:total_votes, Enum.sum(Enum.map(results, & &1.vote_count)))
     |> assign(
       :max_result_votes,
       results |> List.first() |> then(&if(&1, do: &1.vote_count, else: 0))
     )
     |> assign(:family_form, to_form(%{"email" => ""}, as: :family))
     |> assign(:search_form, to_form(%{"query" => ""}, as: :search))
     |> assign(:family_forms, family_forms)
     |> assign(:swimmer_forms, swimmer_forms)
     |> assign(:swimmer_edit_forms, swimmer_edit_forms)
     |> stream(:families, families)
     |> stream(:swimmers, swimmers)
     |> stream(:results, results, dom_id: fn result -> "result-#{result.id}" end)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_admin={@current_admin}>
      <div id="view-admin" class="view active">
        <div class="admin-head">
          <div>
            <h1>Admin Dashboard</h1>
            <div class="sub">Season 2026 · Most Inspirational Swimmer</div>
          </div>
          <span id="voting-status" class={["status-badge", !@voting_open && "closed"]}>
            <span class="dot"></span>{if @voting_open, do: "Voting open", else: "Voting closed"}
          </span>
        </div>
        <div class="controls">
          <button
            id="close-voting"
            class="btn btn-ghost"
            type="button"
            phx-click="set_voting_status"
            phx-value-open="false"
            disabled={!@voting_open}
          >
            Close voting
          </button>
          <button
            id="reopen-voting"
            class="btn btn-ghost"
            type="button"
            phx-click="set_voting_status"
            phx-value-open="true"
            disabled={@voting_open}
          >
            Reopen voting
          </button>
          <button class="btn btn-primary">Email all parents their voting link</button>
        </div>
        <section id="results-panel" class="panel">
          <h3>
            Results · <span id="total-votes">{@total_votes}</span>
            {if @total_votes == 1, do: "vote", else: "votes"}
          </h3>
          <div :if={@results_empty?} id="empty-results">
            No votes have been submitted yet.
          </div>
          <div id="leaderboard" phx-update="stream">
            <div
              :for={{id, result} <- @streams.results}
              id={id}
              class={["leaderboard-row", result.rank == 1 && "top"]}
              data-rank={result.rank}
            >
              <span class="rank">{result.rank}</span>
              <span class="cand-name">{result.candidate_name}</span>
              <div
                class="bar-track"
                role="progressbar"
                aria-label={"#{result.candidate_name}: #{result.vote_count} votes"}
                aria-valuenow={result.vote_count}
                aria-valuemin="0"
                aria-valuemax={@max_result_votes}
              >
                <div class="bar-fill" style={"width:#{result.percentage}%;"}></div>
              </div>
              <span id={"result-vote-count-#{result.id}"} class="vote-count">
                {result.vote_count}
              </span>
            </div>
          </div>
        </section>

        <section class="panel family-management">
          <div class="family-management-head">
            <div>
              <h3>Families</h3>
              <p>
                {@families_count} families. IDs and private voting tokens are generated automatically.
              </p>
            </div>
            <button
              id="show-add-family-form"
              class="btn btn-primary"
              type="button"
              phx-click={show("#add-family-form")}
            >
              Add family
            </button>
          </div>
          <.form
            for={@family_form}
            id="add-family-form"
            class="management-form"
            style="display: none"
            phx-submit="create_family"
          >
            <h4>Add family</h4>
            <.input
              field={@family_form[:email]}
              type="email"
              label="Parent or family email"
              autocomplete="email"
            />
            <div class="management-actions">
              <button id="save-family" class="btn btn-primary" type="submit">Save</button>
              <button
                id="cancel-add-family"
                class="btn btn-ghost"
                type="button"
                phx-click={hide("#add-family-form")}
              >
                Cancel
              </button>
            </div>
          </.form>
          <div id="families" class="family-list" phx-update="stream">
            <article :for={{id, family} <- @streams.families} class="family-card" id={id}>
              <button
                id={"family-disclosure-#{family.id}"}
                aria-controls={"family-details-#{family.id}"}
                aria-expanded="false"
                class="family-disclosure"
                type="button"
                phx-click={
                  JS.toggle(to: "#family-details-#{family.id}")
                  |> JS.toggle_attribute(
                    {"aria-expanded", "true", "false"},
                    to: "#family-disclosure-#{family.id}"
                  )
                  |> JS.toggle(to: "#family-disclosure-plus-#{family.id}")
                  |> JS.toggle(to: "#family-disclosure-minus-#{family.id}")
                }
              >
                <span
                  id={"family-disclosure-plus-#{family.id}"}
                  class="family-disclosure-icon"
                >
                  +
                </span>
                <span
                  id={"family-disclosure-minus-#{family.id}"}
                  class="family-disclosure-icon"
                  style="display: none"
                >
                  −
                </span>
                <span class="family-disclosure-label">
                  <b>{family.email}</b>
                  <span class="sub">
                    {length(family.swimmers)}
                    {if length(family.swimmers) == 1, do: "swimmer", else: "swimmers"}
                  </span>
                </span>
              </button>
              <div
                id={"family-details-#{family.id}"}
                class="family-details"
                style="display: none"
              >
                <div class="family-actions">
                  <button
                    id={"show-edit-family-form-#{family.id}"}
                    class="btn btn-ghost btn-small"
                    type="button"
                    phx-click={show("#edit-family-form-#{family.id}")}
                  >
                    Edit family
                  </button>
                  <button
                    class="btn btn-ghost btn-small"
                    type="button"
                    disabled={family.swimmers != []}
                    title={
                      family.swimmers != [] &&
                        "Remove every swimmer before deleting this family"
                    }
                  >
                    Delete family
                  </button>
                </div>
                <.form
                  for={@family_forms[family.id]}
                  id={"edit-family-form-#{family.id}"}
                  class="management-form"
                  style="display: none"
                  phx-submit="update_family"
                  phx-value-id={family.id}
                >
                  <h4>Edit family</h4>
                  <.input
                    field={@family_forms[family.id][:email]}
                    type="email"
                    label="Parent or family email"
                    autocomplete="email"
                  />
                  <div class="management-actions">
                    <button
                      id={"save-family-#{family.id}"}
                      class="btn btn-primary"
                      type="submit"
                    >
                      Save
                    </button>
                    <button
                      id={"cancel-edit-family-#{family.id}"}
                      class="btn btn-ghost"
                      type="button"
                      phx-click={hide("#edit-family-form-#{family.id}")}
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
                <div class="family-link">
                  <.input
                    id={"family-voting-path-#{family.id}"}
                    name={"family-voting-path-#{family.id}"}
                    type="text"
                    value={"/vote/#{family.family_token}"}
                    aria-label="Private family voting path"
                    readonly
                  />
                  <button
                    id={"copy-family-link-#{family.id}"}
                    class="btn btn-ghost btn-small"
                    type="button"
                    phx-hook="CopyVoteLink"
                    phx-update="ignore"
                    data-vote-path={"/vote/#{family.family_token}"}
                  >
                    Copy link
                  </button>
                </div>
                <div class="family-swimmers">
                  <ul>
                    <li :for={swimmer <- family.swimmers} id={"family-swimmer-#{swimmer.id}"}>
                      <div>
                        <b>{swimmer.name}</b>
                        <span class="sub">{swimmer.group || "No group"}</span>
                      </div>
                      <div class="family-actions">
                        <button
                          id={"show-edit-swimmer-form-#{swimmer.id}"}
                          class="btn btn-ghost btn-small"
                          type="button"
                          phx-click={show("#edit-swimmer-form-#{swimmer.id}")}
                        >
                          Edit
                        </button>
                        <button
                          class="btn btn-ghost btn-small"
                          type="button"
                          title="Delete swimmer if no vote references them"
                        >
                          Delete
                        </button>
                      </div>
                      <.form
                        for={@swimmer_edit_forms[swimmer.id]}
                        id={"edit-swimmer-form-#{swimmer.id}"}
                        class="management-form"
                        style="display: none"
                        phx-submit="update_swimmer"
                        phx-value-id={swimmer.id}
                      >
                        <h4>Edit swimmer</h4>
                        <div class="management-fields">
                          <.input
                            field={@swimmer_edit_forms[swimmer.id][:name]}
                            type="text"
                            label="Swimmer name"
                          />
                          <.input
                            field={@swimmer_edit_forms[swimmer.id][:group]}
                            type="text"
                            label="Group (optional)"
                          />
                        </div>
                        <div class="management-actions">
                          <button
                            id={"save-swimmer-edit-#{swimmer.id}"}
                            class="btn btn-primary"
                            type="submit"
                          >
                            Save
                          </button>
                          <button
                            id={"cancel-edit-swimmer-#{swimmer.id}"}
                            class="btn btn-ghost"
                            type="button"
                            phx-click={hide("#edit-swimmer-form-#{swimmer.id}")}
                          >
                            Cancel
                          </button>
                        </div>
                      </.form>
                    </li>
                  </ul>
                  <button
                    id={"show-add-swimmer-form-#{family.id}"}
                    class="btn btn-ghost btn-small"
                    type="button"
                    phx-click={show("#add-swimmer-form-#{family.id}")}
                  >
                    Add swimmer
                  </button>
                  <.form
                    for={@swimmer_forms[family.id]}
                    id={"add-swimmer-form-#{family.id}"}
                    class="management-form"
                    style="display: none"
                    phx-submit="create_swimmer"
                    phx-value-id={family.id}
                  >
                    <h4>Add swimmer</h4>
                    <div class="management-fields">
                      <.input
                        field={@swimmer_forms[family.id][:name]}
                        type="text"
                        label="Swimmer name"
                      />
                      <.input
                        field={@swimmer_forms[family.id][:group]}
                        type="text"
                        label="Group (optional)"
                      />
                    </div>
                    <div class="management-actions">
                      <button
                        id={"save-swimmer-#{family.id}"}
                        class="btn btn-primary"
                        type="submit"
                      >
                        Save
                      </button>
                      <button
                        id={"cancel-add-swimmer-#{family.id}"}
                        class="btn btn-ghost"
                        type="button"
                        phx-click={hide("#add-swimmer-form-#{family.id}")}
                      >
                        Cancel
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            </article>
          </div>
        </section>

        <section class="panel">
          <h3>Roster — {@roster_count} of {@swimmer_count} swimmers</h3>
          <.form for={@search_form} id="roster-search-form" phx-change="filter_roster">
            <.input
              field={@search_form[:query]}
              id="roster-search"
              class="roster-search"
              type="search"
              placeholder="Search by swimmer, parent email, or group…"
              autocomplete="off"
              phx-debounce="250"
            />
          </.form>
          <table class="roster">
            <thead>
              <tr>
                <th>Swimmer</th>
                <th>Group</th>
                <th>Parent email</th>
                <th>Voted?</th>
              </tr>
            </thead>
            <tbody id="swimmers" phx-update="stream">
              <tr id="empty-swimmer-roster" class="hidden only:table-row">
                <td colspan="4">No swimmers have been added yet.</td>
              </tr>
              <tr :for={{id, swimmer} <- @streams.swimmers} id={id}>
                <td>{swimmer.name}</td>
                <td><span class="grp-tag">{swimmer.group || "Not assigned"}</span></td>
                <td>{swimmer.family.email}</td>
                <td
                  id={"vote-status-#{swimmer.id}"}
                  class={if swimmer.cast_vote, do: "voted-yes", else: "voted-no"}
                >
                  <%= if swimmer.cast_vote do %>
                    Yes {swimmer.cast_vote.candidate.name}
                  <% else %>
                    No
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("create_family", %{"family" => params}, socket) do
    case Nominator.Admin.create_family(params) do
      {:ok, family} ->
        family = Ash.load!(family, :swimmers, domain: Nominator.Admin)

        family_form =
          to_form(%{"email" => family.email},
            as: :family,
            id: "edit-family-#{family.id}"
          )

        swimmer_form =
          to_form(%{"name" => "", "group" => ""},
            as: :swimmer,
            id: "add-swimmer-#{family.id}"
          )

        {:noreply,
         socket
         |> assign(:family_form, to_form(%{"email" => ""}, as: :family))
         |> assign(:family_forms, Map.put(socket.assigns.family_forms, family.id, family_form))
         |> assign(
           :swimmer_forms,
           Map.put(socket.assigns.swimmer_forms, family.id, swimmer_form)
         )
         |> assign(:families_count, socket.assigns.families_count + 1)
         |> stream_insert(:families, family)
         |> put_flash(:info, "Family added successfully.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not add family.")}
    end
  end

  def handle_event("set_voting_status", %{"open" => open}, socket) do
    voting_open = open == "true"

    params = %{
      is_open: if(voting_open, do: 1, else: 0),
      closed_at: if(voting_open, do: nil, else: DateTime.utc_now())
    }

    case Nominator.Voting.update_voting_settings(socket.assigns.voting_settings, params) do
      {:ok, voting_settings} ->
        Phoenix.PubSub.broadcast(
          Nominator.PubSub,
          "voting_settings",
          {:voting_status_changed, voting_open}
        )

        {:noreply,
         socket
         |> assign(:voting_settings, voting_settings)
         |> assign(:voting_open, voting_open)
         |> put_flash(
           :info,
           if(voting_open, do: "Voting reopened.", else: "Voting closed.")
         )}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not update the voting status.")}
    end
  end

  def handle_event("filter_roster", %{"search" => %{"query" => search}}, socket) do
    swimmers = search_roster(search)

    {:noreply,
     socket
     |> assign(:roster_count, length(swimmers))
     |> stream(:swimmers, swimmers, reset: true)}
  end

  def handle_event("create_swimmer", %{"id" => family_id, "swimmer" => params}, socket) do
    input = Map.put(params, "family_id", family_id)

    with {:ok, swimmer} <- Nominator.Admin.create_swimmer(input),
         {:ok, swimmer} <-
           Ash.load(swimmer, [:family, cast_vote: :candidate], domain: Nominator.Admin),
         {:ok, family} <- Nominator.Admin.get_family_by_id(family_id),
         {:ok, family} <- Ash.load(family, :swimmers, domain: Nominator.Admin) do
      swimmer_form =
        to_form(%{"name" => "", "group" => ""},
          as: :swimmer,
          id: "add-swimmer-#{family.id}"
        )

      swimmer_edit_form =
        to_form(%{"name" => swimmer.name, "group" => swimmer.group || ""},
          as: :swimmer,
          id: "edit-swimmer-#{swimmer.id}"
        )

      {:noreply,
       socket
       |> assign(
         :swimmer_forms,
         Map.put(socket.assigns.swimmer_forms, family.id, swimmer_form)
       )
       |> assign(
         :swimmer_edit_forms,
         Map.put(socket.assigns.swimmer_edit_forms, swimmer.id, swimmer_edit_form)
       )
       |> assign(:swimmer_count, socket.assigns.swimmer_count + 1)
       |> stream_insert(:families, family)
       |> stream_insert(:swimmers, swimmer)
       |> put_flash(:info, "Swimmer added successfully.")}
    else
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not add swimmer.")}
    end
  end

  def handle_event("update_family", %{"id" => id, "family" => params}, socket) do
    with {:ok, family} <- Nominator.Admin.get_family_by_id(id),
         {:ok, family} <- Nominator.Admin.update_family(family, params),
         {:ok, family} <- Ash.load(family, :swimmers, domain: Nominator.Admin) do
      family_forms =
        Map.put(
          socket.assigns.family_forms,
          family.id,
          to_form(%{"email" => family.email},
            as: :family,
            id: "edit-family-#{family.id}"
          )
        )

      {:noreply,
       socket
       |> assign(:family_forms, family_forms)
       |> stream_insert(:families, family)
       |> put_flash(:info, "Family updated successfully.")}
    else
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not update family.")}
    end
  end

  def handle_event("update_swimmer", %{"id" => id, "swimmer" => params}, socket) do
    with {:ok, swimmer} <- Nominator.Admin.get_swimmer_by_id(id),
         {:ok, swimmer} <- Nominator.Admin.update_swimmer(swimmer, params),
         {:ok, swimmer} <-
           Ash.load(swimmer, [:family, cast_vote: :candidate], domain: Nominator.Admin),
         {:ok, family} <- Nominator.Admin.get_family_by_id(swimmer.family_id),
         {:ok, family} <- Ash.load(family, :swimmers, domain: Nominator.Admin) do
      swimmer_edit_form =
        to_form(%{"name" => swimmer.name, "group" => swimmer.group || ""},
          as: :swimmer,
          id: "edit-swimmer-#{swimmer.id}"
        )

      {:noreply,
       socket
       |> assign(
         :swimmer_edit_forms,
         Map.put(socket.assigns.swimmer_edit_forms, swimmer.id, swimmer_edit_form)
       )
       |> stream_insert(:families, family)
       |> stream_insert(:swimmers, swimmer)
       |> refresh_results()
       |> put_flash(:info, "Swimmer updated successfully.")}
    else
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not update swimmer.")}
    end
  end

  def handle_info(:vote_recorded, socket) do
    {:noreply, refresh_results(socket)}
  end

  defp refresh_results(socket) do
    results = Nominator.Voting.Results.list()

    socket
    |> assign(:results_empty?, results == [])
    |> assign(:total_votes, Enum.sum(Enum.map(results, & &1.vote_count)))
    |> assign(
      :max_result_votes,
      results |> List.first() |> then(&if(&1, do: &1.vote_count, else: 0))
    )
    |> stream(:results, results, reset: true)
  end

  defp search_roster(search) do
    search = String.trim(search)

    query =
      if search == "" do
        Nominator.Admin.Swimmer
      else
        search = String.downcase(search)

        Ash.Query.filter(
          Nominator.Admin.Swimmer,
          contains(string_downcase(name), ^search) or
            contains(string_downcase(group), ^search) or
            contains(string_downcase(family.email), ^search)
        )
      end

    query
    |> Ash.read!(domain: Nominator.Admin)
    |> Ash.load!([:family, cast_vote: :candidate], domain: Nominator.Admin)
  end
end
