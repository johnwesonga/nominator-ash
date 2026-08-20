# Nominator

Nominator is a Phoenix LiveView application for running a **Most Inspirational
Swimmer** vote. An administrator manages families and swimmers, then shares a
private voting link with each family. Every swimmer in that family receives one
vote, and submitted votes cannot be changed.

## Features

- Manage families and their swimmers from a LiveView admin dashboard
- Generate a private, tokenized ballot link for each family
- Search the roster by swimmer name or group
- Record one vote per swimmer
- Show each swimmer's ballot status and selected nominee
- Open or close ballot inputs using the voting settings record

## Stack

- Elixir and Phoenix 1.8
- Phoenix LiveView 1.1
- Ash Framework with AshSqlite
- Tailwind CSS 4 and daisyUI
- Bandit

## Local setup

### Prerequisites

- Elixir 1.15 or later with a compatible Erlang/OTP release
- SQLite 3

Install dependencies, create and migrate the database, seed the voting
settings, and build the assets:

```sh
mix setup
```

Start the application:

```sh
mix phx.server
```

For an interactive Elixir shell, use `iex -S mix phx.server` instead. The app
will be available at [http://localhost:4000](http://localhost:4000).

## Routes

| Path | Purpose |
| --- | --- |
| `/` | Current public landing page |
| `/admin` | Manage families and swimmers, copy ballot links, and view roster status |
| `/vote/:family_token` | Private family ballot |
| `/dev/dashboard` | Phoenix LiveDashboard in development |
| `/dev/mailbox` | Local email preview in development |

To try the voting flow locally:

1. Create the first administrator as described below.
2. Sign in at `/sign-in`, then visit `/admin` and add a family.
3. Add one or more swimmers to that family.
4. Expand the family and copy its private voting link.
5. Open the link and submit one nomination for each swimmer.

Treat family ballot links as private: possession of the token grants access to
that family's ballot.

## Administrator access

Public administrator registration is disabled. Create an administrator from
environment variables after setting up the database:

```sh
ADMIN_EMAIL=admin@example.com \
ADMIN_PASSWORD='replace with a strong password' \
mix nominator.admin.create
```

The command does not print the password and refuses duplicate email addresses.
Administrators sign in at `/sign-in` and can reset their password through the
local email preview at `/dev/mailbox` during development.

## Database tasks

```sh
mix ecto.migrate  # Apply pending migrations
mix ecto.reset    # Recreate, migrate, and seed the development database
```

Development and test databases are local SQLite files. They may be removed and
recreated when you do not need to preserve their contents.

## Tests and checks

Run the test suite with:

```sh
mix test
```

Before committing, run the project checks (compilation with warnings treated as
errors, unused dependency cleanup, formatting, and tests):

```sh
mix precommit
```

## Current status

Nominator is under active development. The admin route requires an authenticated
administrator, but the landing page is still the default Phoenix page and the
admin voting-window, results, deletion, and bulk-email controls are not yet fully
wired.

The reviewed implementation plan and completion checklist are in
[docs/admin-authentication.md](docs/admin-authentication.md).

## Production

Production startup expects at least these environment variables:

- `DATABASE_URL`
- `SECRET_KEY_BASE` (generate one with `mix phx.gen.secret`)
- `TOKEN_SIGNING_SECRET` (use a separate, cryptographically random secret)
- `PHX_HOST`
- `PHX_SERVER=true` when starting an Elixir release directly

Review the runtime database configuration before deploying: the application
resources currently use AshSqlite, while the generated production runtime
configuration expects a database URL. See the
[Phoenix deployment guide](https://hexdocs.pm/phoenix/deployment.html) for the
general release and deployment workflow.
