defmodule NominatorWeb.LiveAdminAuth do
  @moduledoc """
  LiveView authentication hooks for the administrator account.
  """

  import Phoenix.Component
  use NominatorWeb, :verified_routes

  def on_mount(:admin_required, _params, _session, socket) do
    if socket.assigns[:current_admin] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:no_admin, _params, _session, socket) do
    if socket.assigns[:current_admin] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin")}
    else
      {:cont, assign(socket, :current_admin, nil)}
    end
  end
end
