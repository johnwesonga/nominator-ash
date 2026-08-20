defmodule Nominator.Voting.Ballots do
  def get_by_family_token(token) do
    with {:ok, family} <- Nominator.Admin.get_family_by_token(token),
         {:ok, family} <-
           Ash.load(
             family,
             [swimmers: [cast_vote: :candidate]],
             domain: Nominator.Admin
           ) do
      swimmers =
        family.swimmers
        |> Enum.sort_by(&String.downcase(&1.name))
        |> Enum.with_index(1)
        |> Enum.map(fn {swimmer, lane_number} ->
          to_ballot_entry(swimmer, lane_number)
        end)

      {:ok, swimmers}
    end
  end

  defp to_ballot_entry(swimmer, lane_number) do
    %{
      lane_number: lane_number,
      swimmer_id: swimmer.id,
      swimmer_name: swimmer.name,
      has_voted: not is_nil(swimmer.cast_vote),
      voted_for_name: voted_for_name(swimmer.cast_vote)
    }
  end

  defp voted_for_name(nil), do: nil
  defp voted_for_name(vote), do: vote.candidate.name
end
