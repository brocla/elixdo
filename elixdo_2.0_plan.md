# Elixdo 2.0 — Development Plan

Design philosophy: compete with paper. Paper is unstructured, expressive, zero-friction. Every feature decision is tested against that standard.

---

## Phase Summary

| Phase | Name | Key Deliverable |
|---|---|---|
| 1 | Remove PFX | Delete prefix field, UI, dead code |
| 2 | Remove Bold/Italic/Highlight | Delete fields, UI, dead code |
| 3 | Priority Handle Decorations | ❶❷❸🔥⭐ replace drag handle, toolbar group |
| 4 | Sort Active-First | Toolbar sort button, stable secondary order |
| 5 | Color Picker Pulldown | Split button: last-used color + ▾ picker |
| 6 | MCP Server | Embedded JSON-RPC tool server for AI access |
| 7 | Voice Input | Web Speech API → list item |

---

## Phase 1 — Remove PFX

**Goal:** Delete the prefix feature entirely. It added a character before the body text, which the user can just type themselves. It doesn't stand out visually and adds toolbar noise.

**What gets removed:**
- `prefix` field from `ListItem` schema and `changeset/2` cast list
- Ecto migration: `ALTER TABLE list_items DROP COLUMN prefix` (SQLite requires recreate — use a data migration or `execute` with the recreate pattern)
- `prefix-form` and `prefix-input` from toolbar in `list_live.html.heex`
- `"prefix"` branch from `set_decoration` handler in `list_live.ex`
- `prefix_badge` span from item rendering in `list_live.html.heex`
- `prefix` key from `ItemJSON.item/1` serialization
- `prefix` from `arrow_item` copy attrs in `db.ex`
- CSS for `.prefix-badge`, `.prefix-form`, `.prefix-input`
- Any API test assertions on `prefix`

**Test plan (write first, verify red, then implement):**
1. `ListItem.changeset/2 does not accept prefix field` — pass `%{prefix: "foo"}`, assert it is ignored (not cast)
2. `ItemJSON does not include prefix key` — assert returned map has no `:prefix` key
3. `API GET /lists/:date does not return prefix` — assert JSON response items have no `prefix` field

**After implementation:**
- Run full suite; no test should reference prefix in an assertion context
- Verify no dead CSS remains (`grep -r "prefix" assets/`)

---

## Phase 2 — Remove Bold, Italic, Highlight

**Goal:** Delete the bold, italic, and highlighted formatting features. They were easy to spec but never used in practice. Removing them shrinks the toolbar, simplifies the schema, and eliminates dead code paths.

**What gets removed:**
- `bold`, `italic`, `highlighted` fields from `ListItem` schema and `changeset/2`
- Ecto migration: drop columns (same SQLite recreate pattern)
- Bold/italic/highlight buttons and their `tb-group` div from toolbar
- `"bold"`, `"italic"`, `"highlighted"` branches from `set_decoration` handler
- Bold/italic/highlight attrs from `remove_formats` handler (`bold: false, italic: false, highlighted: false`)
- `bold`, `italic`, `highlighted` keys from `ItemJSON.item/1`
- `bold`, `italic`, `highlighted` from `arrow_item` copy attrs in `db.ex`
- CSS classes `.bold`, `.italic`, `.highlighted` and associated styles
- `item_classes/1` references to bold/italic/highlighted
- All test assertions on these fields

**Test plan (write first, verify red, then implement):**
1. `ListItem.changeset/2 ignores bold, italic, highlighted` — pass all three, assert they are not cast
2. `ItemJSON does not include bold, italic, highlighted keys`
3. `remove_formats does not reference bold/italic/highlighted attrs` — meta-test: read `list_live.ex` source and assert the string `"bold: false"` is absent (same pattern as the IPv6 config test)

**After implementation:**
- Full suite passes
- Search codebase for `bold`, `italic`, `highlighted` — only legitimate remaining uses should be in migration files and comments

---

## Phase 3 — Priority Handle Decorations

**Goal:** Replace the `⠿` drag handle with one of five priority characters: ❶ ❷ ❸ 🔥 ⭐. A new toolbar group lets the user assign or clear the decoration. The character serves as both decoration and drag handle. Drag behavior is unchanged. "Remove all formats" clears the decoration.

**Schema change:**
- Add `priority` field to `list_items` as a nullable string (single character)
- Migration: `ALTER TABLE list_items ADD COLUMN priority TEXT`
- Add `:priority` to `ListItem.changeset/2` cast list
- Validate: if set, must be one of `["❶", "❷", "❸", "🔥", "⭐"]`

**Handle rendering:**
- Change `<span class="drag-handle">⠿</span>` to:
  ```heex
  <span class="drag-handle"><%= item.priority || "⠿" %></span>
  ```
- CSS: `.drag-handle` already has `cursor: grab`. No changes needed — the class stays on the span regardless of content.

**Toolbar:**
- New `tb-group` with five buttons, one per character
- Each button fires `"set_priority"` with `phx-value-priority="❶"` (etc.)
- The `⠿` (clear) is not in the toolbar — clearing is done by "Remove all formats"

**LiveView events:**
- `handle_event("set_priority", %{"priority" => p}, socket)` — validates p is in the allowed set, calls `Lists.update_item(item, %{priority: p})` for each selected item
- `remove_formats` — add `priority: nil` to attrs map

**Arrow copy:**
- `arrow_item` copy in `db.ex` should NOT copy the priority — the copied item starts fresh on the target date

**API:**
- `ItemJSON.item/1` — add `priority: item.priority`
- `PATCH /api/v1/items/:id` — priority settable via API (already flows through `update_item`)

**Test plan (write first, verify red, then implement):**
1. `ListItem.changeset/2 accepts valid priority characters` — test each of the five
2. `ListItem.changeset/2 rejects invalid priority` — assert error on `%{priority: "X"}`
3. `set_priority event sets priority on selected items` — LiveView test: create item, select it, send `"set_priority"` event, assert DB and rendered HTML
4. `priority character appears in drag handle span` — render assertion on HTML
5. `remove_formats clears priority` — set priority, then remove_formats, assert `priority: nil`
6. `arrow_item copy does not inherit priority` — arrow an item with priority set, assert copy has nil priority
7. `ItemJSON includes priority field`

**After implementation:**
- Verify drag still works on desktop and mobile
- Deploy

---

## Phase 4 — Sort Active-First

**Goal:** A toolbar button reorders the current list so all active items come first, followed by completed/wiggled_out/arrowed_out items. Within each group, the existing relative order is preserved (stable sort). The new order is persisted via `reorder_items`.

**Icon:** A vertical double-headed arrow (↕) or a sort icon. SVG:
```
↑ line with bar at top, ↓ line with bar at bottom — standard "sort" affordance
```

**LiveView event:**
- `handle_event("sort_active_first", _, socket)`
- Partition `socket.assigns.items` into active and non-active, preserving within-group order
- Compute new id order
- Call `Lists.reorder_items(socket.assigns.date, new_ids)` — this broadcasts via PubSub, updating all open tabs

**No schema change needed** — position is already the sort field; `reorder_items` updates it.

**Test plan (write first, verify red, then implement):**
1. `sort_active_first moves active items before completed` — create mixed list, trigger event, assert order
2. `sort_active_first preserves within-group order` — multiple active items should stay in their relative order; same for non-active
3. `sort_active_first on already-sorted list is a no-op` — idempotent
4. `sort_active_first on all-active list preserves order`
5. `sort_active_first on all-non-active list preserves order`
6. `sort_active_first persists to DB` — after event, `Lists.get_items_for_date` returns items in new order

**After implementation:**
- Deploy

---

## Phase 5 — Color Picker (responsive)

**Goal:** On desktop, keep the five color swatches exactly as they are — there is plenty of room. On mobile, replace them with a single color button that opens a bottom sheet with five large tap targets. This solves the mobile toolbar space problem without touching the desktop experience.

**Behavior by screen size:**
- **Desktop (≥ 640px):** five color swatches visible in toolbar, as today. No change.
- **Mobile (< 640px):** swatches hidden. A single colored circle button appears instead. Tapping it opens a bottom sheet that slides up from the bottom of the screen showing five large color circles. Tapping a color applies it and closes the sheet. Tapping the overlay closes the sheet without applying.

**Implementation — CSS:**
- `.swatches-row` gets `display: none` at mobile breakpoint
- `.color-mobile-btn` gets `display: none` at desktop, `display: block` at mobile
- Bottom sheet: `position: fixed; bottom: 0; left: 0; right: 0` with a slide-up CSS transition; sits above the toolbar z-index

**LiveView assigns:**
- Add `color_sheet_open: false` to `mount` assigns
- Add `last_color: :blue` to `mount` assigns — the mobile button shows the last-used color so the user has a visual reminder of what's active
- `handle_event("open_color_sheet", _, socket)` — sets `color_sheet_open: true`
- `handle_event("close_color_sheet", _, socket)` — sets `color_sheet_open: false`
- `handle_event("set_color", %{"color" => color}, socket)` — applies color to selected items, updates `last_color`, closes sheet; shared with desktop swatch `set_decoration` event (or reuse existing `set_decoration` and add sheet-close side effect)

**Toolbar HTML (mobile button, hidden on desktop via CSS):**
```heex
<button type="button" phx-click="open_color_sheet"
        class={"color-mobile-btn swatch-#{@last_color}"} title="Color"></button>
```

**Bottom sheet HTML:**
```heex
<%= if @color_sheet_open do %>
  <div class="bottom-sheet-overlay" phx-click="close_color_sheet">
    <div class="bottom-sheet" phx-click-away="close_color_sheet">
      <%= for color <- [:red, :blue, :green, :purple, :orange] do %>
        <button type="button" phx-click="set_color" phx-value-color={color}
                class={"color-sheet-swatch swatch-#{color}"}></button>
      <% end %>
    </div>
  </div>
<% end %>
```

**Careful interactions:**
- Desktop swatches continue to use the existing `set_decoration` event — no change to that path
- `set_color` on mobile closes the sheet and updates `last_color`
- The bottom sheet uses the same overlay + `phx-click-away` pattern as the arrow modal and search modal, which already work correctly on mobile

**Test plan (write first, verify red, then implement):**
1. `open_color_sheet sets color_sheet_open: true`
2. `close_color_sheet sets color_sheet_open: false`
3. `set_color applies color to selected items`
4. `set_color closes the sheet`
5. `set_color updates last_color assign`
6. `last_color defaults to blue at mount`

**After implementation:**
- Test on Android: verify bottom sheet appears, tap targets are large, dismiss works
- Test on desktop: verify swatches are unchanged
- Deploy

---

## Phase 6 — MCP Server

**Goal:** An embedded JSON-RPC 2.0 endpoint at `POST /api/v1/mcp` that exposes Elixdo's lists to AI assistants (Claude Code, Claude.ai). Reuses existing `ApiAuthPlug` (`AGENT_TOKEN`). No new infrastructure.

See `MCP_SERVER_PLAN.md` for the full specification. Summary:

**Tools exposed:**
| Tool | Maps to |
|---|---|
| `get_today` | `Clock.today()` |
| `list_items` | `Lists.get_items_for_date(date)` |
| `list_items_range` | `Lists.get_items_for_range(from, to, statuses)` |
| `add_item` | `Lists.create_items(date, [%{body: body}])` |
| `update_item` | `Repo.get` + `Lists.update_item` |
| `arrow_item` | `Repo.get` + `Lists.arrow_item` |
| `search_items` | `SearchIndex.search(query)` |

**Files:**
- `lib/elixdo_web/router.ex` — add `post "/mcp", McpController, :handle` to `api_auth` scope
- `lib/elixdo_web/controllers/api/mcp_controller.ex` — create (~150 lines)

**Test plan:**
1. `initialize returns correct protocol version and capabilities`
2. `tools/list returns all seven tool definitions with required fields`
3. `get_today returns today's date`
4. `list_items returns items for a date`
5. `add_item creates item and it appears in list_items`
6. `update_item changes item body`
7. `arrow_item marks original arrowed_out and creates copy`
8. `search_items returns matching results`
9. `unknown method returns -32601 error`
10. `missing auth returns 401`

**After implementation:**
- Add MCP config to `.claude/settings.json` (local)
- Add `fly secrets set AGENT_TOKEN=...` to DEPLOYMENT_README.md
- Deploy

---

## Phase 7 — Voice Input

**Goal:** On Android Chrome, a microphone button lets the user dictate a list item. Each utterance becomes one item on the current date. The button is silently absent on browsers without the Web Speech API.

**What gets built:**
- Mic button in the add-item area (next to the Add button)
- `voice.js` Phoenix hook:
  - Checks for `window.SpeechRecognition || window.webkitSpeechRecognition`
  - On click: starts recognition (single utterance, `interimResults: false`)
  - On result: `this.pushEvent("voice_input", {text: transcript})`
  - Visual feedback: CSS class on button while recording (pulsing animation)
  - Conditionally mounted: button element only rendered when hook detects API support via a JS-driven assign or CSS `@supports`-style check
- `handle_event("voice_input", %{"text" => text}, socket)` in `list_live.ex` — same path as `add_item`

**Simplest approach for conditional rendering:** render the button always, let the JS hook hide it on `mounted()` if the API is unavailable. This avoids needing a LiveView assign for browser capability detection.

**Test plan:**
1. `voice_input event creates item with transcribed text` — LiveView integration test sends the event directly (no browser API needed)
2. `voice_input with empty text does nothing`
3. `voice_input trims and emoji-converts text` — same path as add_item

**After implementation:**
- Test on Android Chrome
- Deploy

---

## Cross-cutting concerns for all phases

**Migration strategy:** SQLite doesn't support `DROP COLUMN` before version 3.35. `Exqlite` on Fly uses a recent enough SQLite, but verify. If not, use the table-recreate pattern.

**Dead code sweep after each phase:** `grep -r "bold\|italic\|highlighted\|prefix" lib/ assets/` to catch stragglers.

**Test discipline:** For each phase — write failing tests first, verify they fail, implement, verify they pass, run full suite.

**Deploy cadence:** Deploy after phases 3, 4, 5, 6, 7 so new features can be tested in production while the next phase is in progress.
