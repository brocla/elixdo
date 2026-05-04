# Deploying Your Own Elixdo

This guide walks through forking Elixdo and running your own private instance on Fly.io.

## Prerequisites

### Elixir and Erlang

Install via [asdf](https://asdf-vm.com) (recommended) or the [official installer](https://elixir-lang.org/install.html).

Check the `.tool-versions` file in this repo for the exact versions, or use:

```bash
elixir --version   # should be 1.17+
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt()' -noshell  # should be 27+
```

### Fly.io CLI

```bash
# macOS
brew install flyctl

# Other platforms: https://fly.io/docs/hands-on/install-flyctl/
```

Create an account and log in:

```bash
fly auth signup   # or: fly auth login
```

---

## 1. Fork and clone

Fork this repo on GitHub, then clone your fork:

```bash
git clone https://github.com/<your-username>/elixdo.git
cd elixdo
```

---

## 2. Pick an app name

The app name in `fly.toml` is currently `elixdo` — this is taken. Change it to something unique:

```toml
# fly.toml
app = "your-app-name"
```

Also update `PHX_HOST` in `fly.toml` to match:

```toml
[env]
  PHX_HOST = "your-app-name.fly.dev"
```

---

## 3. Create the Fly app

```bash
fly apps create your-app-name
```

---

## 4. Create a persistent volume for SQLite

The database is stored on a Fly volume so it survives deploys and restarts.

```bash
fly volumes create elixdo_data --region dfw --size 1
```

Use any [Fly region](https://fly.io/docs/reference/regions/) that's close to you. The volume name `elixdo_data` must match the `source` in `fly.toml`.

---

## 5. Set required secrets

### Secret key base (Phoenix session signing)

Generate a secure value:

```bash
mix phx.gen.secret
```

Set it on Fly:

```bash
fly secrets set SECRET_KEY_BASE=<paste-generated-value>
```

### Your secret URL path

This is the private path segment that protects your app. Choose anything — a random word, phrase, or UUID:

```bash
fly secrets set SECRET_PATH=your-private-path
```

Your app will be accessible at `https://your-app-name.fly.dev/your-private-path/list/today`. Keep this URL private — anyone who knows it can use the app.

---

## 6. Deploy

```bash
fly deploy
```

This builds the app, runs database migrations automatically, and starts the server. The first deploy takes a few minutes.

Visit your app at:

```
https://your-app-name.fly.dev/your-private-path/list/today
```

---

## Local development

Install dependencies and set up the local database:

```bash
mix setup
mix phx.server
```

Visit [http://localhost:4000/dev-secret/list/today](http://localhost:4000/dev-secret/list/today). The local secret defaults to `dev-secret` (set in `lib/elixdo_web/plugs/auth_plug.ex`).

## Running tests

```bash
mix test
```

---

## Ongoing operations

### Update the secret URL

```bash
fly secrets set SECRET_PATH=your-new-secret
```

Fly redeploys automatically. Anyone using the old URL gets a 404 until they update their bookmark.

### Redeploy after code changes

```bash
fly deploy
```

### View logs

```bash
fly logs
```

### Open a remote console

```bash
fly ssh console --pty -C "/app/bin/elixdo remote"
```

### Scaling

The default configuration uses a single shared-CPU machine with 512MB RAM, which is more than sufficient for personal use and costs ~$2–3/month. Fly's free tier may cover it depending on your usage.
