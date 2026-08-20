# Admin authentication plan

## Goal

Require an authenticated administrator for `/admin` and every future admin
route while keeping family ballot links at `/vote/:family_token` accessible
without an administrator session.

This document is both the implementation plan and its completion checklist.
Check an item only after its code and tests have been verified.

## Review summary

- [x] Confirmed that `/admin` is currently in the public `:browser` scope.
- [x] Confirmed that the project has no user, administrator, session, or
  authentication resource.
- [x] Confirmed that the endpoint already has signed cookie sessions and the
  LiveView socket receives session data.
- [x] Confirmed that `AdminLive` currently receives no authenticated scope.
- [x] Confirmed that the public family ballot must remain outside the protected
  admin `live_session`.
- [x] Confirmed that Phoenix 1.8's `phx.gen.auth` task is available locally and
  supports LiveView authentication.
- [x] Evaluated `phx.gen.auth` against `ash_authentication` and
  `ash_authentication_phoenix` for this application.
- [x] Confirmed that AshAuthenticationPhoenix provides session-loading plugs,
  router helpers, sign-in UI, CSRF-protected sign-out, and a LiveView session
  wrapper.
- [x] Confirmed that AshAuthentication supports password and single-use magic
  link strategies, stored tokens, password-change token revocation, and Ash
  policies.
- [x] Confirmed that `Nominator.Repo` is an AshSqlite repo, making Ash-native
  administrator and token resources a better fit than Ecto-only schemas.

## Recommended design

Use AshAuthentication and AshAuthenticationPhoenix to create dedicated
`Nominator.Accounts.Admin` and `Nominator.Accounts.Token` Ash resources:

```sh
mix igniter.install ash_authentication \
  --accounts Nominator.Accounts \
  --user Nominator.Accounts.Admin \
  --token Nominator.Accounts.Token \
  --auth-strategy password

mix igniter.install ash_authentication_phoenix
```

Why this approach:

- Administrator identities and tokens remain Ash resources using the existing
  AshSqlite data layer and repository.
- Authentication actions, sensitive arguments, policies, and identities use the
  same domain model as the rest of the application.
- AshAuthenticationPhoenix provides session loading, authentication route
  macros, sign-in components, and a LiveView session wrapper.
- It avoids adding Ecto-only account schemas beside the existing Ash resources.
- It supports adding magic links or OAuth later without replacing the account
  model.

Phoenix `phx.gen.auth` remains a valid alternative and provides excellent
generated tests, but its account schemas and context would introduce a separate
Ecto architecture into this Ash-native application. That tradeoff is not
justified for the current project.

### Access policy

- `/admin` and future `/admin/*` management routes require an authenticated
  administrator.
- `/vote/:family_token` remains public and token-protected.
- `/` remains public.
- Public administrator registration is disabled before deployment.
- The first administrator is created by a one-time, environment-driven Mix task
  or release command. Credentials must never be committed to seeds or source.
- Authentication answers **who is signed in**. Any future roles or permissions
  require a separate authorization design.

## Implementation checklist

### 1. Install and inspect authentication

- [ ] Commit or stash unrelated changes so Igniter edits are easy to review.
- [x] Run both Ash authentication installer commands above.
- [x] Review every generated and modified file before accepting the result.
- [x] Confirm `Nominator.Accounts.Admin` and `Nominator.Accounts.Token` use
  `AshSqlite.DataLayer`, `Nominator.Repo`, UUID primary keys, and the intended
  tables.
- [x] Confirm `Nominator.Accounts` is included in the configured Ash domains.
- [x] Confirm `{AshAuthentication.Supervisor, otp_app: :nominator}` is in the
  application supervision tree.
- [x] Store the token-signing secret in runtime configuration; never commit it.
- [x] Generate and review Ash migrations and resource snapshots for the admin
  and token resources.
- [x] Run `mix ecto.migrate` and confirm both authentication tables are created.
- [x] Confirm both resources work through `Nominator.Repo` alongside the
  existing Ash resources.

Acceptance check: an administrator can be created and retrieved in development,
and a clean test database migrates successfully.

### 2. Establish the administrator bootstrap policy

- [x] Disable public registration actions and remove registration links/routes
  from the supplied authentication UI.
- [x] Add a one-time bootstrap command that reads the initial email and password
  from environment variables without logging either secret.
- [x] Make the bootstrap command fail safely when the account already exists or
  required environment variables are absent.
- [ ] Document credential rotation and administrator recovery.
- [x] Confirm development seeds contain no administrator credentials.

Acceptance check: an anonymous visitor cannot register an administrator, and an
operator can create the first administrator without editing source code.

### 3. Protect the route correctly

- [x] Import the AshAuthenticationPhoenix router helpers and add
  `plug :load_from_session` to the `:browser` pipeline.
- [x] Add the Ash authentication, sign-in, and CSRF-protected sign-out routes.
- [x] Implement a LiveView `on_mount` hook that redirects when
  `socket.assigns.current_admin` is absent.
- [x] Move `live "/admin", AdminLive` into one protected
  `ash_authentication_live_session` block using that hook.
- [x] Keep `/vote/:family_token` and `/` outside the authenticated admin block.
- [ ] Put every future admin LiveView in the same protected authentication live
  session.
- [x] Pass the authenticated administrator to layouts or components that display
  account state.

The intended router shape is:

```elixir
scope "/", NominatorWeb do
  pipe_through :browser

  get "/", PageController, :home
  live "/vote/:id", VoteLive
end

scope "/", NominatorWeb do
  pipe_through :browser

  ash_authentication_live_session :admin_authentication_required,
    on_mount: [{NominatorWeb.LiveAdminAuth, :admin_required}] do
    live "/admin", AdminLive
  end
end
```

Use the actual installed controller, routes, and assign names if they differ
from this sketch. The `on_mount` hook is mandatory: the live-session wrapper
loads session state but does not, by itself, reject an absent administrator.

Acceptance check: a logged-out request to `/admin` redirects to login, while
the home page and a valid family ballot still load without an admin session.

### 4. Integrate the authenticated scope into the UI

- [x] Update `AdminLive` to use the `@current_admin` assign supplied by the Ash
  authentication live session.
- [x] Show the signed-in administrator email in the admin navigation.
- [x] Add a logout control that opens the CSRF-protected sign-out flow.
- [ ] Avoid placing account or logout controls on the family ballot unless that
  is an intentional product decision.
- [ ] Ensure login, magic-link, settings, and error states match the existing
  Nominator layout and remain keyboard accessible.

Acceptance check: the admin can identify the active account, log out, and is
immediately unable to revisit `/admin` without signing in again.

### 5. Configure email and production security

- [x] Confirm password-only login for the first release, or explicitly approve
  adding magic links.
- [ ] If magic links or confirmation emails remain enabled, configure a
  production Swoosh adapter and verified sender domain.
- [ ] Set a strong `TOKEN_SIGNING_SECRET` in every deployed environment.
- [ ] Set the canonical application URL used in authentication emails.
- [ ] Ensure production uses HTTPS and secure session cookies.
- [ ] Set an explicit session lifetime appropriate for admin access.
- [x] Enable logout-everywhere/token revocation behavior after
  password changes and logout.
- [ ] Add rate limiting or upstream protection to login and magic-link request
  endpoints before public deployment.
- [ ] Avoid revealing whether an administrator email exists in login or recovery
  responses.

Acceptance check: authentication works over the production-like HTTPS setup,
email links target the correct host, and repeated login attempts are limited.

### 6. Add focused tests

- [x] Test that an anonymous `live(conn, ~p"/admin")` is redirected to the admin
  login route.
- [x] Test that an authenticated administrator can mount `AdminLive`.
- [x] Update existing `AdminLive` tests to log in through a shared fixture or
  generated helper before visiting `/admin`.
- [x] Test that `/vote/:family_token` remains accessible when logged out.
- [x] Test login with valid and invalid credentials.
- [x] Test logout and verify the old session no longer grants admin access.
- [x] Test the disabled-registration policy.
- [ ] Test expired, invalid, and reused authentication tokens; include magic-link
  cases only if that strategy is enabled.
- [x] Use stable DOM IDs and `Phoenix.LiveViewTest` selectors rather than raw HTML
  assertions.

Acceptance check: tests fail if `/admin` is accidentally returned to a public
scope or if logout leaves the route accessible.

### 7. Final verification

- [x] Run the authentication-specific test files.
- [x] Run `mix test`.
- [x] Run `mix precommit` and resolve all failures.
- [ ] Manually verify anonymous redirect, login, refresh, LiveView reconnect,
  logout, and direct navigation to `/admin`.
- [ ] Manually verify the public voting flow after the router changes.
- [x] Update `README.md` to remove the unauthenticated-admin warning and document
  the bootstrap command.
- [ ] Confirm no passwords, login tokens, session cookies, or local databases
  are tracked by Git.

## Decisions to record during implementation

Fill these in before marking the plan complete:

- Authentication library: **AshAuthentication + AshAuthenticationPhoenix**
- Login methods: **Password only**
- Password hashing library: **bcrypt_elixir**
- Session lifetime: **TBD**
- Initial administrator bootstrap command: **`mix nominator.admin.create`**
- Production email adapter: **TBD if email login is enabled**
- Login rate-limiting mechanism: **TBD**

## Definition of done

Authentication is complete only when every implementation and verification item
above is checked, `/admin` cannot be mounted anonymously, public family voting
still works, public admin registration is unavailable, and the full project
precommit checks pass.

## References

- [AshAuthentication getting started](https://ash-authentication.hexdocs.pm/get-started.html)
- [AshAuthenticationPhoenix overview](https://ash-authentication-phoenix.hexdocs.pm/AshAuthentication.Phoenix.html)
- [AshAuthenticationPhoenix LiveView routes](https://hexdocs.pm/ash_authentication_phoenix/liveview.html)
- [AshAuthenticationPhoenix router API](https://hexdocs.pm/ash_authentication_phoenix/AshAuthentication.Phoenix.Router.html)
