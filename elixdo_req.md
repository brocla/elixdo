# Elixdo Requirements

## 1. Overview

Elixdo is a shared daily todo list application built with Elixir and Phoenix LiveView. The primary goal is to provide a frictionless, always-available replacement for a paper todo system. The app must be accessible from any web browser or phone, shared among multiple people and AI agents without individual logins, and fast enough in navigation that paging between days feels like flipping through photos.

---

## 2. Functional Requirements

### 2.1 Daily Lists

1. Each calendar day has exactly one list. Lists are never deleted.
2. Past, present, and future lists are all editable.
3. The app opens to today's list by default.
4. New days do not start blank by requirement — a future or past day may already contain items that were added in advance.
5. There is no automatic carry-forward of incomplete items from one day to the next.

### 2.2 Navigation

1. The primary navigation method is paging forward (future) and backward (past) one day at a time.
2. Day-paging must respond to:
   - Left/right swipe gestures (on touch devices)
   - Left/right arrow keys (on keyboard devices)
   - Left arrow icon (past) and right arrow icon (future) displayed on the left and right edges of the screen
3. Paging must feel snappy and photo-flip-like in responsiveness.
4. A secondary navigation method must allow jumping directly to dates that are weeks, months, or years away (e.g., a date picker or calendar view).
5. When the currently displayed list is not today's list, a "Return to Today" button is shown. It must be unobtrusive (icon-style, not a large button).

### 2.3 List Items

1. List items are never deleted from the database.
2. Each item has a status that reflects its disposition:

   | Status | Meaning |
   | :--- | :--- |
   | `active` | Item is current and incomplete |
   | `completed` | Item was finished |
   | `wiggled_out` | Item was abandoned (not accomplished, not to be considered) |
   | `arrowed_out` | Item was pushed forward to a future date |

3. Status is communicated through CSS text decoration applied to the item body:

   | Status | CSS |
   | :--- | :--- |
   | `completed` | `text-decoration: line-through` |
   | `wiggled_out` | `text-decoration: line-through wavy` |
   | `arrowed_out` | `text-decoration: line-through` plus `::after { content: ' →' }` |

4. All three decorators are pure CSS with no JavaScript required.
5. The text decoration color is always black regardless of the item's assigned color.
6. The appended arrow character (`→`) for `arrowed_out` items is bold and `+4` font sizes relative to the item text to maximize visibility.

### 2.4 Arrow-Out Action

1. When a user arrows out an item, they are prompted to select a future date.
2. Two writes occur atomically:
   - The original item's status is set to `arrowed_out` and its `arrowed_to_date` field is set to the chosen date.
   - A copy of the item is appended to the target date's list with status `active`.
3. The copy inherits: `body`, `color`, `bold`, `italic`, `highlighted`, `prefix`. It does not inherit `position` or `arrowed_to_date`.
4. There is no link between the original item and the copy. Each can be edited independently.
5. The forward-arrow action on multiple selected items copies all of them to a single prompted date.

### 2.5 Item Formatting and Decoration

1. Items can be decorated with the following independent attributes:
   - **bold**: Text is bold.
   - **italic**: Text is italic.
   - **highlighted**: Text background is yellow.
   - **prefix**: A letter, number, emoji, or icon identifier displayed in the area around the selection button.
2. Items can be assigned one color from the following palette, applied to the entire item. No color (`nil`) is also valid.

   | Name | Hex |
   | :--- | :--- |
   | `red` | `#E53935` (Ruby) |
   | `blue` | `#1E88E5` (Sapphire) |
   | `green` | `#43A047` (Emerald) |
   | `purple` | `#8E24AA` (Amethyst) |
   | `orange` | `#FB8C00` (Tangerine) |

### 2.6 Selection and Toolbar

1. Each list item is prefixed with a selection button (e.g., an open circle).
2. A "Select All" button is displayed above the list and does not scroll away.
3. A fixed toolbar at the top of the screen displays all available decorator actions. The toolbar is not a status indicator — it shows available actions only.
4. Clicking a toolbar action applies that action to all currently selected items.

### 2.7 Item Ordering

1. Items within a day's list have an explicit sort order defined by the `position` field.
2. Items can be reordered by the user via drag handles.
3. Drag handles must work on both web browsers and Android.

### 2.8 Adding Items

1. Items can be added by typing directly into the list.
2. Multi-line items are supported. Shift-Enter inserts a new line within an item; Enter submits the item.
3. Items can be added by voice input. Voice input is implemented for Android only.
4. Items can be added by photographing a text note or whiteboard (OCR). Requirements for OCR:
   - Photos are sent to the OpenAI API for OCR processing. An API key will be provided.
   - It is acceptable for this feature to incur per-use cost.
   - A single photo may contain multiple distinct items; each item in the photo is created as a separate list item.
   - OCR results are added directly to the currently displayed list (which may not be today) without a confirmation step.
   - Results can be reviewed and edited after the fact in the list.

### 2.9 Search

1. The full body text of all list items is searchable.
2. Clicking a search result navigates to that day's list and highlights the matched item.

### 2.10 Multi-User Access

1. There is a single shared account used by multiple people and AI agents simultaneously.
2. All users read and edit the same lists.
3. Last-write-wins conflict resolution applies.
4. There is no presence display or live cursor visibility for other users.

### 2.11 Time Zone

1. The application's concept of "today" is determined by the `America/Denver` IANA timezone.
2. The current date is computed fresh on every request — `DateTime.now!("America/Denver") |> DateTime.to_date()` — with no cached state to invalidate.
3. The displayed list does not automatically jump to the new day when midnight passes. The user navigates there manually.
4. No GenServer reload is required at midnight. Per-list GenServers are keyed by calendar date, not by the concept of "today." A GenServer for April 29 continues to correctly hold April 29's items after midnight with no intervention.

**What happens at midnight:**

| Thing | Behavior | Action required |
| :--- | :--- | :--- |
| Per-list GenServers | Continue running, still correct for their date | None |
| Dirty write buffer | Flushes on its normal timer | None |
| API `"today"` resolution | Computed fresh per request | None |
| Open LiveView sessions | Continue showing whatever date they were on | None — screen does not jump |
| "Return to Today" button | Target date is stale until the page is reloaded | Resolved by `DateWatcher` (see below) |

5. A `DateWatcher` GenServer is added to the application supervisor. At startup it calculates the milliseconds until the next America/Denver midnight and schedules a `Process.send_after` message to itself. When midnight fires, it broadcasts a `{:new_day, date}` message on the `"date:change"` PubSub topic and reschedules for the next midnight. LiveView sessions subscribe to this topic and update their `@today` assign when the broadcast arrives, keeping the "Return to Today" button accurate without requiring a page reload.

### 2.12 Scope Exclusions

1. There are no timers or alarms.
2. There is no calendar or appointment scheduling.
3. There is no task scheduling system (Oban is not used).
4. There is no automatic carry-forward of items between days.

---

## 3. Access Design

### 3.1 Authentication Model

1. There is one shared account. There are no individual user accounts or registration flows.
2. Human users authenticate via a secret URL path. The URL is non-obvious and functions as the sole credential for browser access. Example form: `https://your-app.fly.dev/Zq3mK9vR2xNpL8wY4tFjB6cHdA1eGs7u`
3. A session established via the secret URL is expected to remain active for weeks or months without re-authentication.
4. AI agents authenticate via a static Bearer token in the `Authorization` header on all `/api/*` routes.
5. The secret URL path and the agent Bearer token are stored as Fly.io secrets (`SECRET_PATH` and the token value). To rotate either credential: update the secret via `fly secrets set`, redeploy, and update any stored bookmarks or agent configurations.

### 3.2 Authorization Rules

1. Any request bearing a valid secret URL or valid Bearer token has full read and write access.
2. Missing or invalid Bearer token on `/api/*` routes returns HTTP 401.

---

## 4. Data Model

### 4.1 Table: `list_items`

| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | bigint (PK) | Auto-increment |
| `date` | date | Which day's list. Indexed. |
| `position` | integer | Sort order within the day. Unique per date; need not be contiguous. |
| `body` | text | The item text. |
| `status` | enum | `active` \| `completed` \| `wiggled_out` \| `arrowed_out`. Default: `active`. |
| `color` | enum | `nil` \| `red` \| `blue` \| `green` \| `purple` \| `orange`. Nullable. |
| `bold` | boolean | Default `false`. |
| `italic` | boolean | Default `false`. |
| `highlighted` | boolean | Default `false`. Yellow background when `true`. |
| `prefix` | string | Nullable. Letter, number, emoji, or icon identifier. |
| `arrowed_to_date` | date | Nullable. Set when status is `arrowed_out`. |
| `inserted_at` | utc_datetime | |
| `updated_at` | utc_datetime | |

### 4.2 Indexes

```sql
CREATE INDEX idx_list_items_date_position ON list_items (date, position);
CREATE VIRTUAL TABLE list_items_fts USING fts5(body, content='list_items', content_rowid='id');
```

### 4.3 Ecto Schema

```elixir
schema "list_items" do
  field :date,            :date
  field :position,        :integer
  field :body,            :string
  field :status,          Ecto.Enum, values: [:active, :completed, :wiggled_out, :arrowed_out],
                                     default: :active
  field :color,           Ecto.Enum, values: [:red, :blue, :green, :purple, :orange]
  field :bold,            :boolean,  default: false
  field :italic,          :boolean,  default: false
  field :highlighted,     :boolean,  default: false
  field :prefix,          :string
  field :arrowed_to_date, :date

  timestamps(type: :utc_datetime)
end
```

---

## 5. API Contract

### 5.1 Authentication

All `/api/*` routes require the following header:

```
Authorization: Bearer elix_agt_s3cr3tt0k3nhere
```

Missing or invalid token returns HTTP 401.

### 5.2 Date Handling

The following values are accepted wherever a date parameter is expected:

| Input | Resolves to |
| :--- | :--- |
| `today` | Current date in `America/Denver` timezone |
| `yesterday` | Previous date in `America/Denver` timezone |
| `tomorrow` | Next date in `America/Denver` timezone |
| `2026-04-29` | ISO 8601 literal date |

All dates in responses are returned as resolved ISO 8601 strings. Relative terms are never returned.

### 5.3 Error Envelope

All error responses use the following JSON envelope:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Request body contains invalid fields.",
    "details": { "status": ["is not a valid status"] }
  }
}
```

| HTTP Status | Code | When |
| :--- | :--- | :--- |
| 400 | `bad_request` | Malformed JSON |
| 401 | `unauthorized` | Bad or missing Bearer token |
| 404 | `not_found` | Item does not exist |
| 409 | `conflict` | Forbidden status transition |
| 422 | `validation_error` | Field validation failure |
| 500 | `internal_error` | Server error |

### 5.4 Routes

| Method | Path | Description |
| :--- | :--- | :--- |
| GET | `/api/v1/lists/:date` | All items for one day |
| GET | `/api/v1/lists?from=&to=&status=` | Items across a date range |
| POST | `/api/v1/lists/:date/items` | Create one or more items |
| PATCH | `/api/v1/items/:id` | Update fields on one item |
| POST | `/api/v1/items/:id/arrow` | Arrow an item to another date |
| PATCH | `/api/v1/lists/:date/reorder` | Reorder all items for a day |

### 5.5 GET /api/v1/lists/:date

Returns all items for the given day sorted by `position` ascending. An empty list returns HTTP 200, not 404.

```json
{
  "date": "2026-04-29",
  "items": [
    {
      "id": 1,
      "date": "2026-04-29",
      "position": 1,
      "body": "Review PR from Jordan",
      "status": "active",
      "color": null,
      "bold": false,
      "italic": false,
      "highlighted": false,
      "prefix": null,
      "arrowed_to_date": null,
      "inserted_at": "2026-04-29T07:14:00Z",
      "updated_at": "2026-04-29T07:14:00Z"
    }
  ]
}
```

### 5.6 GET /api/v1/lists?from=&to=&status=

Returns items across a date range. The `status` parameter is optional and accepts a comma-separated list of status values to filter by. Every date in the range is included in the response even if it has no items.

Request example:
```
GET /api/v1/lists?from=2026-04-21&to=yesterday&status=active,wiggled_out
```

Response:
```json
{
  "from": "2026-04-21",
  "to": "2026-04-28",
  "days": [
    { "date": "2026-04-21", "items": [] },
    { "date": "2026-04-22", "items": [ { "id": 7, "body": "Call insurance", "status": "active" } ] }
  ]
}
```

### 5.7 POST /api/v1/lists/:date/items

Creates one or more items atomically (all or nothing). New items are appended after existing positions. The `status` and `position` fields are not accepted in the request body — they are assigned automatically.

Request:
```json
{
  "items": [
    { "body": "Follow up with Sarah", "color": "blue" },
    { "body": "Send meeting notes", "highlighted": true }
  ]
}
```

Returns HTTP 201 with the created items including their assigned `id` and `position`.

### 5.8 PATCH /api/v1/items/:id

Partial update — only fields present in the request body are modified.

Request example:
```json
{ "status": "completed", "color": "green" }
```

Status transition rules:

| From | To | Allowed |
| :--- | :--- | :--- |
| `active` | Any status | Yes |
| `completed` | `active` | Yes (undo) |
| `wiggled_out` | `active` | Yes (undo) |
| `arrowed_out` | Any status | No — returns HTTP 409 |

### 5.9 POST /api/v1/items/:id/arrow

Arrows an item to a target date. Performs two atomic writes:
1. The original item's status is set to `arrowed_out` and `arrowed_to_date` is set to the target date.
2. A copy of the item is appended to the target date's list with `status: active`.

Only `active` items can be arrowed. Attempting to arrow any other status returns HTTP 409.

The copy inherits: `body`, `color`, `bold`, `italic`, `highlighted`, `prefix`. It does not inherit `position` or `arrowed_to_date`. There is no foreign key or other link between the original and the copy.

Request:
```json
{ "to_date": "tomorrow" }
```

Response includes both the updated original item and the newly created copy.

### 5.10 PATCH /api/v1/lists/:date/reorder

Atomically sets `position` for every item on the specified day. The request must include all item IDs for that date. A partial list is rejected with HTTP 422.

Request:
```json
{ "order": [7, 2, 1, 42, 43] }
```

The first ID receives `position: 1`, the second receives `position: 2`, and so on. Returns the full reordered list.

### 5.11 API Implementation Constraints

1. All timestamps in responses are UTC with a `Z` suffix.
2. The `America/Denver` timezone only affects resolution of relative date terms (`today`, `yesterday`, `tomorrow`).
3. The arrow operation (`POST /api/v1/items/:id/arrow`) must execute inside a database transaction.
4. The reorder operation (`PATCH /api/v1/lists/:date/reorder`) must execute inside a database transaction.
5. The bulk create operation (`POST /api/v1/lists/:date/items`) must be atomic — all items are created or none are.
6. Position values must be unique per date but are not required to be contiguous.

---

## 6. Technical Requirements

### 6.1 Platform and Stack

1. The application is built with Elixir and Phoenix LiveView.
2. The database is SQLite, accessed via Ecto with the `Exqlite` adapter.
3. The application is deployed on Fly.io with a persistent volume for the SQLite file.
4. The application is a Progressive Web App (PWA) to enable installation and access across platforms.

### 6.2 Hosting

1. The application is hosted on Fly.io.
2. The URL is non-obvious and serves as the human authentication credential.
3. Fly.io secrets are used for the secret URL path and the agent Bearer token.

---

## 7. Architectural Guidance

The following are design decisions to be followed during implementation, not open options.

### 7.1 Per-List GenServer Processes

- Each day's list is managed by a dedicated GenServer process. This gives list operations in-memory speed and enables the snappy, photo-flip navigation feel.
- Per-list GenServers are started on demand and supervised by a `DynamicSupervisor`.
- A `Registry` is used to look up GenServer processes by date (via tuple).
- Idle list processes shut themselves down after a configurable inactivity timeout, implemented via `Process.send_after`.

### 7.2 GenServer as Write Buffer

- The GenServer holds the list state in memory. Writes are applied to the GenServer immediately, making the UI feel instant.
- Persistence to SQLite is asynchronous, flushed on a short timer or on process shutdown.
- Dirty state is not lost on clean shutdown; the GenServer flushes before terminating.

### 7.3 PubSub for Multi-Device Sync

- Phoenix PubSub is used to broadcast list changes to all connected LiveView sessions viewing the same date. This keeps multiple devices and browser tabs consistent in real time.

### 7.4 ETS-Backed Search Index

- A dedicated `SearchIndex` GenServer owns an ETS table for full-text search.
- The `SearchIndex` GenServer is started by the application supervisor at boot. The ETS table lives as long as the GenServer (i.e., the lifetime of the application).
- The search index is not persisted between application restarts. It is rebuilt from the database at startup. ETS lookup performance is sufficient for the expected data size.
- The index is updated incrementally — context functions cast to the `SearchIndex` GenServer after every write. No periodic full rebuilds are required.

### 7.5 Agent API Implementation

- The agent API is implemented as a separate `/api` scope using a lightweight Plug endpoint, not a LiveView.
- Token authentication is handled in a plug applied to the `/api` scope.
- API handlers call into the same context functions (or GenServer) as the LiveView, with no duplication of business logic.

### 7.6 AI Agent Use Cases

The agent API is designed to support the following use cases:

1. Adding items to a day's list after a meeting (e.g., "add 'follow up with John' to today").
2. Reading the current list to understand priorities before assisting with planning.
3. Marking items complete or arrowing them forward based on a description of what happened.
4. A morning script pulling yesterday's incomplete items for summarization.
