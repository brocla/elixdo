# Elixdo

A personal daily todo list, built with Phoenix LiveView and deployed on Fly.io. Each day gets its own list. Items can be formatted, colored, reordered, and pushed forward to future dates.

![Elixdo screenshot](design/Screenshot%202026-05-01%20232656.png)

## Access

The app is protected by a secret URL segment rather than a login. The URL looks like:

```
https://elixdo.fly.dev/<your-secret>/list/today
```

The secret is set via an environment variable (`SECRET_PATH`) on the server. Anyone who knows the URL can use the app — keep it private.

## Using the App

- **Add items** — type in the input bar at the bottom and press Enter (Shift+Enter for a newline)
- **Complete an item** — click the circle on the left
- **Select an item** — click anywhere on the item text to select it; the toolbar activates
- **Format** — with an item selected, use the toolbar to toggle Bold, Italic, Highlight, color, or a text prefix
- **Arrow forward** — push a selected item to a future date (→ button in toolbar); the original stays struck through with an annotation showing where it went
- **Remove all formats** — the ✕ button clears formatting and restores an arrowed item to active
- **Navigate dates** — use ‹ › arrows or the calendar picker; "Today" button jumps back to today
- **Reorder** — drag and drop items within a day
- **Search** — click the magnifying glass to search across all items

## Updating the Secret

The secret URL path is controlled by the `SECRET_PATH` environment variable on Fly.io.

To change it:

```bash
fly secrets set SECRET_PATH=your-new-secret
```

Fly will automatically redeploy the app with the new secret. Anyone using the old URL will get a 404 until they update their bookmarks.

## Local Development

```bash
# Install dependencies and set up the database
mix setup

# Start the dev server
mix phx.server
```

Visit [http://localhost:4000/dev-secret/list/today](http://localhost:4000/dev-secret/list/today). The local secret defaults to `dev-secret`.

## Running Tests

```bash
mix test
```

## Deployment

The app is deployed on [Fly.io](https://fly.io). Database migrations run automatically on deploy via the `release_command` in `fly.toml`.

```bash
# Deploy
fly deploy

# View logs
fly logs

# Open a remote IEx console
fly ssh console --pty -C "/app/bin/elixdo remote"
```

## Tech Stack

- [Elixir](https://elixir-lang.org) / [Phoenix](https://phoenixframework.org) — web framework
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) — real-time UI without JavaScript
- [SQLite](https://sqlite.org) via [Exqlite](https://github.com/elixir-sqlite/exqlite) — embedded database
- [Fly.io](https://fly.io) — hosting, with a persistent volume for the SQLite file
