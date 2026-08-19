defmodule NominatorWeb.PageController do
  use NominatorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
