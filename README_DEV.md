# Elixdo — Developer & Maintenance Reference

This is the cheat sheet for working on Elixdo after being away for a while. It covers the dev loop, deployment, and key rotation.

---

## Local Development

```bash
# First time (or after pulling changes that touch deps or migrations)
mix setup

# Start the dev server
mix phx.server
```

Visit: [http://localhost:4000/dev-secret/list/today](http://localhost:4000/dev-secret/list/today)

The local secret is hardcoded to `dev-secret` in `lib/elixdo_web/plugs/auth_plug.ex`.

Run tests:

```bash
mix test
```

---

## Deploying to Production (Fly.io)

The app runs on Fly.io at `elixdo.fly.dev`. Use the deploy script to embed the git SHA so you can track which commit is live:

```powershell
# PowerShell (preferred — embeds current git SHA)
.\deploy.ps1
```

Or manually:

```bash
fly deploy --build-arg GIT_SHA=$(git rev-parse --short HEAD)
```

The first deploy of a session takes longer — Fly cold-starts the builder. Subsequent ones are faster.

### Check what's deployed

```powershell
.\check_deployment_level.ps1
```

Or manually:

```bash
curl https://elixdo.fly.dev/health
# {"status":"ok","sha":"a1b2c3d"}

git log --oneline | head -5
```

Compare the `sha` from the health endpoint against the git log to see if production is current.

---

## Secrets (Fly.io)

All secrets are managed via `fly secrets`. Changes trigger an automatic redeploy.

Current secrets:

| Name | Purpose |
|---|---|
| `SECRET_KEY_BASE` | Phoenix session signing key |
| `SECRET_PATH` | Private URL segment that protects the app |
| `AGENT_TOKEN` | Bearer token for MCP / AI access |
| `VAPID_PRIVATE_KEY` | Web Push signing (private) |
| `VAPID_PUBLIC_KEY` | Web Push signing (public) |
| `VAPID_SUBJECT` | Web Push contact email (`mailto:...`) |

### Rotate the secret URL path

The app is protected by a secret URL segment — no login. The URL is:

```
https://elixdo.fly.dev/<SECRET_PATH>/list/today
```

To change it:

```bash
fly secrets set SECRET_PATH=your-new-secret
```

Fly redeploys automatically. Anyone using the old URL gets a 404. Update all bookmarks and the MCP config after rotating.

### Rotate the Phoenix secret key base

```bash
mix phx.gen.secret
fly secrets set SECRET_KEY_BASE=<paste-output>
```

This invalidates all existing sessions — users (you) will be redirected on next visit.

### Rotate the agent token (MCP access)

Generate any random string, e.g.:

```bash
mix phx.gen.secret 32
```

Set it:

```bash
fly secrets set AGENT_TOKEN=<new-token>
```

Then update the Claude Code MCP registration:

```bash
claude mcp remove elixdo
claude mcp add --transport http --scope user elixdo https://elixdo.fly.dev/api/v1/mcp \
  --header "Authorization: Bearer <new-token>"
```

### Rotate VAPID keys (Web Push)

Only needed if push notifications break or you want to fully reset them. **Rotating VAPID keys invalidates all existing push subscriptions** — all devices will need to re-subscribe in Settings.

Generate new keys:

```bash
mix run -e "IO.inspect Web.Push.generate_vapid_keys()"
# or use: https://vapidkeys.com
```

Set them:

```bash
fly secrets set VAPID_PRIVATE_KEY=<private> VAPID_PUBLIC_KEY=<public>
```

---

## Viewing Logs

```bash
fly logs
```

Follow live:

```bash
fly logs --tail
```

---

## Remote Console (Production DB / IEx)

```bash
fly ssh console --pty -C "/app/bin/elixdo remote"
```

This opens a live IEx session connected to the running production app. You can query the database, inspect state, etc. Be careful — this is production.

---

## Database

SQLite lives on a Fly persistent volume (`elixdo_data`). It survives deploys and restarts.

Migrations run automatically on every deploy (via the release step in `rel/`).

To inspect the local dev database directly:

```bash
sqlite3 elixdo_dev.db
```

---

## MCP Server (AI Access)

The app exposes an MCP endpoint at `POST /api/v1/mcp`. Claude Code is configured to use it.

To re-register after rotating the agent token or secret path:

```bash
claude mcp remove elixdo
claude mcp add --transport http --scope user elixdo https://elixdo.fly.dev/api/v1/mcp \
  --header "Authorization: Bearer <AGENT_TOKEN>"
```

Check current MCP config:

```bash
claude mcp list
```

---

## Infrastructure at a Glance

- **Host:** Fly.io — app name `elixdo`, region `dfw`
- **Machine:** shared-CPU, 512MB RAM (~$2–3/month)
- **Database:** SQLite on Fly volume `elixdo_data`
- **Health endpoint:** `https://elixdo.fly.dev/health`
- **Fly dashboard:** https://fly.io/apps/elixdo
