# Elixdo — Phased Development Plan

An incremental, scaffold-first development process where each phase produces a runnable, testable slice of the system.

---

## Phase Summary

| Phase | Name | Key Deliverable |
|---|---|---|
| 1 | Scaffold & Deploy | Fly.io deployment, schema, auth |
| 2 | Data Layer & Context | Fully-tested `Lists` context + `SearchIndex` + behaviours/mocks |
| 3 | GenServer Architecture | Per-date GenServer pool, async persistence |
| 4 | LiveView Navigation | Navigable list UI, DateWatcher |
| 5 | Item Actions & Toolbar | CRUD, status changes, selection, PubSub sync |
| 6 | Drag Reorder | Touch + desktop drag ordering |
| 7 | Search | ETS full-text search with navigation |
| 8 | Agent API | All `/api/v1` routes, Bearer auth |
| 9 | OCR Input | Photo → items via OpenAI vision |
| 10 | Voice Input | Android mic → item via Web Speech API |
| 11 | PWA | Installable, cached shell, standalone mode |

---

## Phase 1 — Scaffold & Deploy

**Goal:** A deployable Phoenix app on Fly.io with SQLite, secret-URL authentication, and the `list_items` schema in place.

**What gets built:**
- `mix phx.new elixdo` with `Exqlite` adapter configured in place of Postgres
- Ecto migration: `list_items` table with all columns, enums, and indexes (including the FTS5 virtual table)
- `ListItem` schema with `Ecto.Enum` for `status` and `color`
- `ElixdoWeb.AuthPlug` — reads `SECRET_PATH` from env, checks `conn.request_path`, sets session cookie; any other path returns 404
- A bare `PageController` at the secret path that renders "Elixdo is alive" and the current America/Denver date
- `fly.toml`, persistent volume mount, `SECRET_PATH` and `AGENT_TOKEN` wired as Fly.io secrets
- GitHub Actions CI: `mix test` passes on every push

**Done when:**
- `fly deploy` succeeds
- Visiting `https://app.fly.dev/<SECRET_PATH>` renders the placeholder page
- Visiting any other path returns 404
- `mix test` has at least one smoke test confirming the migration ran and `ListItem.changeset/2` validates required fields

**Deferred:** Everything else — no LiveView, no GenServer, no API.

---

## Phase 2 — Data Layer & Context

**Goal:** A fully-tested `Lists` context that all future layers (LiveView and API) will call without duplication. Behaviours and mock infrastructure are established here so all subsequent phases can test in isolation.

**What gets built:**
- `Elixdo.Lists` context module with:
  - `get_items_for_date/1` — returns items sorted by position
  - `get_items_for_range/3` — date range query with optional status filter
  - `create_items/2` — bulk atomic insert, auto-assigns positions after existing max
  - `update_item/2` — partial update with status transition validation (returns `{:error, :forbidden_transition}` for `arrowed_out` source)
  - `arrow_item/2` — transactional two-write arrow operation
  - `reorder_items/2` — transactional position reassignment, rejects partial lists
- `Elixdo.DateHelper` — resolves `"today"`, `"yesterday"`, `"tomorrow"`, ISO strings to `Date.t()` using `America/Denver`; delegates to `Elixdo.Clock` behaviour so tests are not time-coupled
- `Elixdo.SearchIndex` GenServer — ETS-backed, started in supervisor; `rebuild_from_db/0` at boot, `update_entry/1` and `search/1` calls
- **Behaviours (defined before the modules that use them, required by Mox at compile time):**
  - `Elixdo.Clock.Behaviour` — `@callback today() :: Date.t()`; real impl: `Elixdo.Clock.System`; test impl: `Elixdo.Clock.Mock`
  - `Elixdo.OCR.Behaviour` — `@callback extract_items(binary()) :: {:ok, [String.t()]} | {:error, term()}`; real impl: `Elixdo.OCR.OpenAI`; test impl: `Elixdo.OCR.Mock`
- **Application config wiring:**
  ```elixir
  # config/test.exs
  config :elixdo, clock: Elixdo.Clock.Mock
  config :elixdo, ocr:   Elixdo.OCR.Mock

  # config/runtime.exs
  config :elixdo, clock: Elixdo.Clock.System
  config :elixdo, ocr:   Elixdo.OCR.OpenAI
  ```
- `Mox` added to deps; mocks declared in `test/support/mocks.ex`
- Unit tests covering: all context functions, status transition rules, arrow atomicity, reorder rejection on partial list, search index rebuild and incremental update; `DateHelper` tests use `Clock.Mock` to fix the current date

**Done when:**
- All context functions have passing ExUnit tests, including failure cases
- `DateHelper` tests pass with a fixed mock date — no wall-clock dependency
- `SearchIndex` GenServer starts, rebuilds from an empty DB, and returns results for inserted items
- `Elixdo.Clock.Mock` and `Elixdo.OCR.Mock` are declared and usable by future phases
- Zero LiveView or HTTP changes in this phase

**Deferred:** GenServer write buffer, PubSub, LiveView, API.

---

## Phase 3 — GenServer Architecture

**Goal:** List state lives in supervised per-date GenServer processes; all reads and writes go through GenServer, with async SQLite persistence.

**What gets built:**
- `Elixdo.Lists.Server` GenServer:
  - State: `{date, items, dirty?, last_activity}`
  - `init/1` loads items from DB via `Lists` context
  - Handles: `:get_items`, `:create_items`, `:update_item`, `:arrow_item`, `:reorder_items`
  - On each mutating call: updates in-memory state, marks dirty, resets inactivity timer, broadcasts on `"list:<date>"` PubSub topic
  - Flush timer (configurable, default 2s): persists dirty state to SQLite, clears dirty flag
  - Inactivity timer (configurable, default 10min): `Process.send_after` → clean shutdown after flush
  - `terminate/2` flushes if dirty
- `Elixdo.Lists.Supervisor` — `DynamicSupervisor` + `Registry` keyed by `{Elixdo.Lists.Server, date}`
- `Elixdo.Lists.ServerPool` — `get_or_start/1` by date, wraps Registry lookup and DynamicSupervisor start
- `Lists.Server` accepts `context` as an init option (defaults to `Elixdo.Lists`); tests pass a mock context module to exercise the GenServer without hitting the DB
- Context functions updated to route through `ServerPool` instead of direct Ecto calls
- `SearchIndex` cast updated inside GenServer after every write

**Done when:**
- All Phase 2 context tests still pass (same public API)
- GenServer processes are visible in Observer under the DynamicSupervisor
- A write to one GenServer and a simulated process restart shows data persisted in SQLite
- Inactivity timeout test: process terminates after configured idle period and is restarted on next access

**Deferred:** LiveView, PubSub subscriptions in UI, API, DateWatcher.

---

## Phase 4 — LiveView Navigation

**Goal:** A working daily list LiveView — readable and navigable across days, deployable and usable on a phone.

**What gets built:**
- `ElixdoWeb.ListLive` — mounts to the secret-URL root, assigns `@date`, `@today`, `@items`
- Day navigation: left/right arrow icon buttons (CSS-positioned at screen edges), keyboard `ArrowLeft`/`ArrowRight` via `phx-window-keydown`, touch swipe via a minimal JS hook (`swipe.js`)
- Date display: human-readable header (`Monday, April 28`)
- "Return to Today" icon button — shown only when `@date != @today`, unobtrusive icon style
- Direct date jump: a `<input type="date">` shown on click of the date header, `phx-change` navigates to selected date
- Item rendering: body text, CSS decorations per status (`line-through`, `wavy`, `arrowed_out` with `→` via `::after`), color applied to full item, bold/italic/highlighted applied to body, prefix shown in gutter
- Tailwind CSS setup; color palette classes defined
- Responsive layout that works on 375px mobile width
- `DateWatcher` GenServer — calculates ms to next America/Denver midnight, `send_after` to self, broadcasts `{:new_day, date}` on `"date:change"` PubSub topic, reschedules; LiveView subscribes and updates `@today`

**Done when:**
- Navigating left/right changes the displayed date and loads items from the GenServer
- Swipe gesture navigates on an Android device
- Arrow keys navigate on desktop
- Date picker jump works
- "Return to Today" button appears only when off-today and navigates home
- `DateWatcher` broadcasts are received by a LiveView test that simulates midnight firing
- CSS decorations render correctly for all four statuses in a browser

**Deferred:** Selection, toolbar, item editing, drag reorder, search, PWA, API.

---

## Phase 5 — Item Actions & Toolbar

**Goal:** Users can add, edit, and change the status of items; the toolbar and selection model are functional.

**What gets built:**
- Add-item text area at bottom of list: `Enter` submits, `Shift-Enter` inserts newline, auto-focuses after submit
- Inline item body editing: click body to activate `<textarea>`, `Enter` saves, `Escape` cancels
- Selection model: `@selected` MapSet assign, per-item selection button (open circle), "Select All" sticky header button
- Fixed top toolbar with actions: `completed`, `wiggled_out`, `arrowed_out` (prompts date picker), `bold`, `italic`, `highlighted`, color swatches (5 + nil), prefix input
- Toolbar applies action to all selected items via `Lists.ServerPool` calls
- Arrow-out flow: toolbar arrow button → modal/inline date picker → atomic two-write via `Lists.arrow_item/2` → PubSub broadcast
- Multi-item arrow-out: all selected items copied to single prompted date
- PubSub subscription: `ElixdoWeb.ListLive` subscribes to `"list:<date>"`, merges broadcast updates into `@items` — multiple tabs stay in sync
- Status CSS classes wired to item status field

**Done when:**
- Add item, edit body, mark complete, wiggle out, arrow out all work end-to-end in the browser
- Two browser tabs on the same date show real-time sync via PubSub
- Toolbar applies decoration to multi-selected items
- Arrow-out creates the copy on the target date (verifiable by navigating there)
- All toolbar actions covered by LiveView integration tests

**Deferred:** Drag reorder, search, voice, OCR, PWA, API.

---

## Phase 6 — Drag Reorder

**Goal:** Items can be reordered by dragging on both desktop and Android Chrome.

**What gets built:**
- Drag handle element on each item (grip icon)
- `SortableJS` wired via a Phoenix JS hook (`dragSort.js`)
- Hook fires `pushEvent("reorder", %{order: [ids...]})` on drag end
- `ElixdoWeb.ListLive` handles `"reorder"` event → `Lists.reorder_items/2` → PubSub broadcast
- Drag works on Android touch (SortableJS touch support)
- Optimistic local reorder in JS while server confirms

**Done when:**
- Drag reorder works on desktop Chrome
- Drag reorder works on Android Chrome
- Reorder is reflected on a second open tab via PubSub
- After a page reload, the order persists from SQLite

**Deferred:** Search, voice, OCR, PWA, API.

---

## Phase 7 — Search

**Goal:** Full-text search across all items, navigating to the matched day and highlighting the item.

**What gets built:**
- Search icon in the top bar opens a search overlay/modal
- `phx-change` on search input calls `SearchIndex.search/1` (ETS lookup)
- Results list shows item body snippet and date label
- Clicking a result: closes overlay, navigates LiveView to result's date, sets `@highlighted_item_id`
- Highlighted item receives a CSS highlight class (ring, background) that clears on next interaction
- Integration test covering the full search → navigate → highlight flow

**Done when:**
- Typing in search returns matching items from any date
- Clicking a result navigates to the correct date with the item visually highlighted
- Search still works after adding new items in the same session (incremental update verified)

**Deferred:** Voice, OCR, PWA, API.

---

## Phase 8 — Agent API

**Goal:** All `/api/v1` routes are implemented, authenticated, and tested; AI agents can fully interact with lists.

**What gets built:**
- `ElixdoWeb.ApiAuthPlug` — checks `Authorization: Bearer <AGENT_TOKEN>`, returns 401 JSON envelope on failure
- Phoenix Router `/api` scope with plug applied
- Controllers (thin, delegating to `Lists` context / `ServerPool`):
  - `GET /api/v1/lists/:date`
  - `GET /api/v1/lists?from=&to=&status=`
  - `POST /api/v1/lists/:date/items`
  - `PATCH /api/v1/items/:id`
  - `POST /api/v1/items/:id/arrow`
  - `PATCH /api/v1/lists/:date/reorder`
- `DateHelper` used for all relative date resolution
- JSON error envelope for all error cases per spec
- All timestamps UTC with `Z` suffix
- API writes go through `ServerPool`, triggering PubSub sync to open LiveView sessions

**Done when:**
- All six routes return correct responses per spec
- A curl request with a valid Bearer token creates an item that immediately appears in an open LiveView session
- Auth failure returns `{"error": {"code": "unauthorized", ...}}` with HTTP 401
- All API tests pass in CI

**Deferred:** Voice, OCR, PWA.

---

## Phase 9 — OCR Input

**Goal:** Users can photograph a whiteboard or note; each recognized item is added to the current list.

**What gets built:**
- Camera/file input button in the UI (camera on mobile, file picker on desktop)
- JS hook uploads image via Phoenix `live_file_input`
- `Elixdo.OCR` module: base64-encodes image, sends to OpenAI vision API (`gpt-4o`) with prompt to return a JSON array of item strings, parses response
- `OPENAI_API_KEY` stored as Fly.io secret
- Extracted items bulk-created on the currently displayed date via `Lists.create_items/2`
- No confirmation step — items appear immediately and can be edited
- Error handling: API failure shows flash error, no partial creates

**Done when:**
- Photographing a handwritten list on Android creates separate items on the current date
- A test with a mocked OpenAI response confirms parsing and bulk-create path
- OpenAI error returns a flash message and creates no items

**Deferred:** Voice, PWA.

---

## Phase 10 — Voice Input

**Goal:** Users on Android can dictate items using the device microphone; each utterance becomes a list item.

**What gets built:**
- Voice input button (microphone icon) in the add-item area
- JS hook using Web Speech API (`SpeechRecognition` / `webkitSpeechRecognition`): starts recognition, fires `pushEvent("voice_input", %{text: transcript})` on result
- `ElixdoWeb.ListLive` handles `"voice_input"` event: creates item with transcript body on current date
- Button is conditionally shown only if `window.SpeechRecognition || window.webkitSpeechRecognition` is available (silently absent on unsupported browsers)
- Visual feedback during recording (pulsing mic icon via JS hook state)

**Done when:**
- Speaking into the mic on Android Chrome creates a list item with the transcribed text
- The mic button is absent on desktop browsers that lack the API
- A LiveView integration test confirms the `"voice_input"` event handler creates an item

**Deferred:** PWA.

---

## Phase 11 — Progressive Web App

**Goal:** Elixdo is installable on Android and iOS home screens and loads with a native app feel.

**What gets built:**
- `manifest.json` served at `/manifest.json`: `name`, `short_name`, `start_url` (secret path), `display: standalone`, `background_color`, `theme_color`, icon assets (192×192 and 512×512 PNG)
- `<link rel="manifest">` and `<meta name="theme-color">` in root layout
- Service worker (`sw.js`): caches app shell (layout HTML, CSS, JS bundle) using Cache API with network-first strategy; does not cache API or list data
- iOS-specific meta tags: `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `apple-touch-icon`
- `robots.txt` disallowing all crawlers

**Done when:**
- Lighthouse PWA audit passes (installable, has manifest, has service worker)
- App installs to Android home screen and opens in standalone mode at the correct start URL
- App installs to iOS home screen via Safari "Add to Home Screen"
- Subsequent page loads use the cached shell (confirmed in DevTools Network tab)

**Deferred:** Nothing — this is the final phase.
