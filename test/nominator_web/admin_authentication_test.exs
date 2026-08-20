defmodule NominatorWeb.AdminAuthenticationTest do
  use NominatorWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirects anonymous visitors away from the admin dashboard", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin")
  end

  test "allows an authenticated administrator to mount the dashboard", context do
    %{conn: conn, admin: admin} = register_and_log_in_admin(context)

    assert {:ok, view, _html} = live(conn, ~p"/admin")
    assert has_element?(view, "#current-admin-email", to_string(admin.email))
    assert has_element?(view, "#admin-sign-out")
  end

  test "does not expose public administrator registration", %{conn: conn} do
    conn = get(conn, "/register")
    assert response(conn, 404)
  end

  test "signs in with valid administrator credentials", %{conn: conn} do
    {admin, password} = create_admin()

    conn =
      conn
      |> init_test_session(%{})
      |> post("/auth/admin/password/sign_in", %{
        "admin" => %{"email" => to_string(admin.email), "password" => password}
      })

    assert redirected_to(conn) == "/admin"

    conn = recycle(conn)
    assert {:ok, _view, _html} = live(conn, ~p"/admin")
  end

  test "rejects invalid administrator credentials", %{conn: conn} do
    {admin, _password} = create_admin()

    conn =
      conn
      |> init_test_session(%{})
      |> post("/auth/admin/password/sign_in", %{
        "admin" => %{"email" => to_string(admin.email), "password" => "incorrect password"}
      })

    assert redirected_to(conn) == "/sign-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Incorrect email or password"
  end

  test "keeps family ballots public", %{conn: conn} do
    family = Nominator.Admin.create_family!(%{email: "public-ballot@example.com"})

    assert {:ok, view, _html} = live(conn, ~p"/vote/#{family.family_token}")
    assert has_element?(view, "#view-parent")
  end

  test "logout removes access to the admin dashboard", context do
    %{conn: conn} = register_and_log_in_admin(context)

    conn = delete(conn, ~p"/sign-out")
    assert redirected_to(conn) == "/"

    conn = recycle(conn)
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin")
  end
end
