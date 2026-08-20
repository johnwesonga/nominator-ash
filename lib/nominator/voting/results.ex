defmodule Nominator.Voting.Results do
  @moduledoc """
  Builds the ranked leaderboard from persisted votes.
  """

  def list do
    votes =
      Nominator.Voting.list_votes!()
      |> Ash.load!(:candidate, domain: Nominator.Voting)

    votes
    |> Enum.group_by(& &1.candidate_id)
    |> Enum.map(fn {candidate_id, candidate_votes} ->
      candidate = candidate_votes |> List.first() |> Map.fetch!(:candidate)

      %{
        id: candidate_id,
        candidate_name: candidate.name,
        vote_count: length(candidate_votes)
      }
    end)
    |> Enum.sort_by(fn result -> {-result.vote_count, String.downcase(result.candidate_name)} end)
    |> add_rank_and_percentage()
  end

  defp add_rank_and_percentage([]), do: []

  defp add_rank_and_percentage(results) do
    max_votes = results |> List.first() |> Map.fetch!(:vote_count)

    results
    |> Enum.with_index(1)
    |> Enum.map_reduce({nil, nil}, fn {result, position}, {previous_count, previous_rank} ->
      rank = if result.vote_count == previous_count, do: previous_rank, else: position

      result =
        result
        |> Map.put(:rank, rank)
        |> Map.put(:percentage, round(result.vote_count / max_votes * 100))

      {result, {result.vote_count, rank}}
    end)
    |> elem(0)
  end
end
