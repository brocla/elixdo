# Push Notifications Plan

## Goal

When a new list item is added, subscribed devices receive a Web Push notification.

This is a **multi-user app** — many people can view and add items. The design must require
zero setup or choices from regular users. Only the owner adjusts their personal devices.

Each device independently controls two flags stored in `localStorage`:

| Flag | Default | Meaning |
|---|---|---|
| `receive_notifications` | **OFF** | This device wants to receive push notifications |
| `suppress_notifications` | **OFF** | This device will NOT trigger pushes when adding items |

**Regular users** — both flags OFF, nothing to configure, no notifications sent or received.

**Owner's personal devices** — `receive=ON, suppress=ON`. You get notified when others
(collaborators, AI/MCP) add items, but not when you type items yourself.

**MCP / AI context** — `suppress=OFF` (default). AI-added items trigger pushes to all
subscribed devices.

---

## Platform Support

| Platform | Notes |
|---|---|
| Android Chrome | Full support |
| Desktop Chrome / Edge | Full support |
| Firefox | Full support |
| iOS Safari | Requires iOS 16.4+, app must be added to home screen first |

---

## Architecture

```
Browser                          Server (Phoenix)
──────                           ────────────────
SW registers                     VAPID keypair (env secrets)
Owner opts in ──subscribe──►     push_subscriptions table
                                 {device_id, endpoint, p256dh, auth}

User adds item ──add_item──►     Lists.create_items/3
  + device_id                      └─ notify_devices/2
  + suppress=false                    └─ skips originating device_id
                                       └─ POST to each endpoint (web_push_elixir)

Push service ──► SW ──► Notification shown on owner's device
```

---

## Phase 1 — Server: VAPID keypair and DB table

### VAPID keypair

Generate using the mix task provided by `web_push_elixir`:
```bash
mix generate.vapid.keys
```

This outputs a map with `vapid_public_key`, `vapid_private_key`, and `vapid_subject`.
Store the values as Fly secrets:
```bash
fly secrets set \
  VAPID_PUBLIC_KEY=<vapid_public_key value> \
  VAPID_PRIVATE_KEY=<vapid_private_key value> \
  VAPID_SUBJECT=mailto:you@example.com
```

**Important:** Generate the keys only once. If you regenerate them, all existing browser
push subscriptions become invalid and every subscribed device must re-subscribe.

Read in `config/runtime.exs`:
```elixir
config :web_push_elixir,
  vapid_public_key: System.get_env("VAPID_PUBLIC_KEY"),
  vapid_private_key: System.get_env("VAPID_PRIVATE_KEY"),
  vapid_subject: System.get_env("VAPID_SUBJECT", "mailto:admin@elixdo.fly.dev")
```

### Migration

```elixir
create table(:push_subscriptions) do
  add :device_id, :string, null: false
  add :endpoint,  :string, null: false
  add :p256dh,    :string, null: false
  add :auth,      :string, null: false
  timestamps()
end
create unique_index(:push_subscriptions, [:device_id])
create unique_index(:push_subscriptions, [:endpoint])
```

### Schema

```elixir
defmodule Elixdo.PushSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "push_subscriptions" do
    field :device_id, :string
    field :endpoint,  :string
    field :p256dh,    :string
    field :auth,      :string
    timestamps()
  end

  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [:device_id, :endpoint, :p256dh, :auth])
    |> validate_required([:device_id, :endpoint, :p256dh, :auth])
    |> unique_constraint(:device_id)
    |> unique_constraint(:endpoint)
  end
end
```

### Dependency

Add to `mix.exs`:
```elixir
{:web_push_elixir, "~> 0.3"}
```

---

## Phase 2 — Server: Push controller

`lib/elixdo_web/controllers/api/push_controller.ex`

The subscribe/unsubscribe endpoints are scoped under the secret URL path (same as the
LiveView) — no bearer token needed. Anyone who knows the secret URL can access the app,
so using it as the auth boundary is consistent with the rest of the app's design.

**POST `/<secret>/push/subscribe`**
Body: `{device_id, endpoint, p256dh, auth}`
- Upserts the subscription (insert or update on device_id conflict)
- Returns 200

**DELETE `/<secret>/push/subscribe`**
Body: `{device_id}`
- Deletes the subscription for that device_id
- Returns 204

**GET `/push/vapid-public-key`**
- Unauthenticated — the public key is not sensitive
- Returns `{public_key: "..."}`

Add to router:
```elixir
scope "/:secret", ElixdoWeb do
  pipe_through [:browser, :require_secret]
  post   "/push/subscribe",   PushController, :subscribe
  delete "/push/subscribe",   PushController, :unsubscribe
end

scope "/", ElixdoWeb do
  get "/push/vapid-public-key", PushController, :vapid_key
end
```

---

## Phase 3 — Server: Notification dispatch

`lib/elixdo/push_notifications.ex`

```elixir
defmodule Elixdo.PushNotifications do
  alias Elixdo.{Repo, PushSubscription}
  import Ecto.Query

  def notify_devices(message, except_device_id \\ nil) do
    subscriptions =
      from(s in PushSubscription,
        where: s.device_id != ^(except_device_id || ""))
      |> Repo.all()

    Enum.each(subscriptions, fn sub ->
      payload = Jason.encode!(%{title: "Elixdo", body: message})
      subscription = %{
        endpoint: sub.endpoint,
        keys: %{p256dh: sub.p256dh, auth: sub.auth}
      }
      Task.start(fn -> WebPushElixir.send_web_push(payload, subscription) end)
    end)
  end
end
```

Hook into `Lists.create_items/2` — add an optional `opts` argument:

```elixir
def create_items(date, attrs_list, opts \\ []) do
  # existing implementation ...
  # after successful creation:
  unless opts[:suppress_push] do
    device_id = opts[:device_id]
    Enum.each(items, fn item ->
      PushNotifications.notify_devices(item.body, device_id)
    end)
  end
end
```

The LiveView `handle_event("add_item", ...)` passes `device_id` and the suppress flag
from the socket assigns.

---

## Phase 4 — Client: Service worker

`assets/static/sw.js` (served as a static file at `/sw.js`)

```javascript
self.addEventListener("push", (event) => {
  const data = event.data?.json() ?? {};
  event.waitUntil(
    self.registration.showNotification(data.title ?? "Elixdo", {
      body: data.body ?? "",
      icon:  "/images/web-app-manifest-192x192.png",
      badge: "/images/badge-96x96.png"
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow("/"));
});
```

---

## Phase 5 — Client: JS and device registration

`assets/js/push_notifications.js`

On page load:
1. Generate or retrieve `device_id` from `localStorage` (UUID, generated once per browser)
2. Register the service worker at `/sw.js`
3. If `receive_notifications` flag is ON: subscribe to push, POST subscription to server
4. Expose `shouldSuppress()` — reads `suppress_notifications` from localStorage

```javascript
const DEVICE_ID_KEY = "elixdo_device_id";
const RECEIVE_KEY   = "elixdo_receive_notifications";
const SUPPRESS_KEY  = "elixdo_suppress_notifications";

function getDeviceId() {
  let id = localStorage.getItem(DEVICE_ID_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(DEVICE_ID_KEY, id);
  }
  return id;
}

export function shouldSuppress() {
  return localStorage.getItem(SUPPRESS_KEY) === "true";
}

export async function setupPush(secretPath) {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) return;

  const receive = localStorage.getItem(RECEIVE_KEY) === "true";
  const reg = await navigator.serviceWorker.register("/sw.js");

  if (!receive) {
    const existing = await reg.pushManager.getSubscription();
    if (existing) {
      await existing.unsubscribe();
      await fetch(`/${secretPath}/push/subscribe`, {
        method: "DELETE",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({device_id: getDeviceId()})
      });
    }
    return;
  }

  const {public_key} = await fetch("/push/vapid-public-key").then(r => r.json());

  const subscription = await reg.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: public_key
  });

  const {endpoint, keys: {p256dh, auth}} = subscription.toJSON();

  await fetch(`/${secretPath}/push/subscribe`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({device_id: getDeviceId(), endpoint, p256dh, auth})
  });
}
```

`secretPath` is already available in the LiveView JS context (it's in the page URL).

In `app.js`, call `setupPush(secretPath)` on load.

In the LiveView `add_item` event, append `device_id` and `suppress` from localStorage
to the event payload via a JS hook before it reaches the server.

---

## Phase 6 — Client: Settings page

A dedicated settings page at `/<secret>/settings` — bookmarkable, invisible to regular
users who don't know it exists.

Route:
```elixir
scope "/:secret", ElixdoWeb do
  pipe_through [:browser, :require_secret]
  live "/settings", SettingsLive, :index
end
```

`lib/elixdo_web/live/settings_live.ex` — a minimal LiveView that renders a static HTML
page. The two toggles are pure client-side: they read/write `localStorage` via a JS hook
and call `setupPush()` when "Receive notifications" is toggled on.

```
┌─────────────────────────────────────────┐
│  Notification Settings                  │
│                                         │
│  [✓] Notify me on this device           │
│      Receive a push notification when   │
│      someone adds a new item.           │
│                                         │
│  [✓] Don't send from this device        │
│      Suppress notifications triggered   │
│      by your own additions.             │
│                                         │
│  Note: iOS requires the app to be       │
│  added to your home screen first.       │
└─────────────────────────────────────────┘
```

The page has no server state — it's just a shell that lets the JS hook read/write
localStorage. The checkboxes reflect current localStorage values on mount and update
them on change.

To reach it on each personal device: visit `/<secret>/settings` and bookmark it.

---

## Phase 7 — LiveView: Pass device_id and suppress flag

In `list_live.ex`:
- On `mount`, set `device_id: nil` and `suppress_push: false` in assigns
- Add `handle_event("set_push_context", %{"device_id" => id, "suppress" => suppress}, socket)`
  that stores these in assigns
- On `add_item`, pass `device_id` and `suppress_push` as opts to `Lists.create_items/3`

The JS hook fires `set_push_context` on `mounted()` with the values from localStorage.
Regular users never set these flags so both remain at their defaults (nil / false) and
`notify_devices` is called with no `except_device_id` — meaning all subscribed devices
get the notification (which is zero devices for a default install).

---

## Test plan

### Schema — `test/elixdo/push_subscription_test.exs`

1. `changeset/2 accepts valid attrs`
2. `changeset/2 rejects missing required fields`
3. `changeset/2 rejects duplicate device_id`
4. `changeset/2 rejects duplicate endpoint`

### Controller — `test/elixdo_web/controllers/push_controller_test.exs`

5. `POST /<secret>/push/subscribe inserts a new subscription`
6. `POST /<secret>/push/subscribe upserts on device_id conflict`
7. `DELETE /<secret>/push/subscribe removes the subscription`
8. `DELETE /<secret>/push/subscribe with unknown device_id returns 204`
9. `GET /push/vapid-public-key returns the public key string`
10. `POST /<secret>/push/subscribe with wrong secret returns 404`
11. `POST /<secret>/push/subscribe with missing fields returns 422`

### Dispatch — `test/elixdo/push_notifications_test.exs`

12. `notify_devices/2 with no subscriptions does nothing`
13. `notify_devices/2 notifies all subscribed devices`
14. `notify_devices/2 skips the originating device_id`
15. `notify_devices/2 with nil except_device_id notifies all subscribers`

### Lists integration — `test/elixdo/lists_test.exs`

16. `create_items/3 with suppress_push: true does not trigger push`
17. `create_items/3 with suppress_push: false triggers push for each item`
18. `create_items/3 with device_id passes it through to notify_devices`

### LiveView — `test/elixdo_web/live/list_live_test.exs`

19. `set_push_context stores device_id and suppress in socket assigns`
20. `add_item with suppress=true does not trigger push`
21. `add_item with suppress=false triggers push`

### Not tested in ExUnit (manual device testing only)

- Service worker registration and push event handling
- `PushManager.subscribe()` and localStorage flag behavior
- Notification appearance on Android status bar and notification drawer
- iOS home screen requirement
These are covered by the deployment checklist manual steps.

---

## Deployment checklist

- [ ] `mix deps.get` (web_push_elixir)
- [ ] Generate VAPID keys: `mix generate.vapid.keys`
- [ ] `fly secrets set VAPID_PUBLIC_KEY=... VAPID_PRIVATE_KEY=... VAPID_SUBJECT=...`
- [ ] `fly deploy --build-arg GIT_SHA=$(git rev-parse --short HEAD)`
- [ ] `mix ecto.migrate` on Fly (runs automatically via release command)
- [ ] On each personal device: visit `/<secret>/settings`, enable both toggles
- [ ] iOS: add app to home screen first, then visit settings
- [ ] Test: add item via MCP → notification appears on personal device
- [ ] Test: add item manually on personal device → no notification on that device

---

## Notes

- Regular users see and configure nothing. Zero friction preserved.
- The settings page URL is effectively secret — it's under the same secret path segment.
- **Icons**: the service worker uses `priv/static/images/web-app-manifest-192x192.png`
  (notification drawer) and `priv/static/images/badge-96x96.png` (status bar). Both
  files exist at `priv/static/images/`.
- **iOS caveat**: document the home screen requirement prominently on the settings page.
