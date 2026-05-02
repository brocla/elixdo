# Elixdo UI Redesign — Drop-in Files

## Files in this folder

| File | Copy to |
|---|---|
| `app.css` | `assets/css/app.css` |
| `list_live.html.heex` | `lib/elixdo_web/live/list_live.html.heex` |

---

## Step 1 — Add the font

Add these lines to `lib/elixdo_web/components/layouts/root.html.heex` inside `<head>`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,400&display=swap" rel="stylesheet" />
```

---

## Step 2 — Add one helper to list_live.ex

The new template uses `color_item_class/1` to put a `color-*` class on each `<li>`
for the accent bar and tinted background. Add this private helper near the existing
`item_class/1` and `item_classes/1` functions at the bottom of `list_live.ex`:

```elixir
defp color_item_class(%{color: nil}), do: ""
defp color_item_class(%{color: color}), do: "color-#{color}"
```

---

## Step 3 — Drop in the files

Replace both files, run `mix assets.build` (or let your dev server pick it up),
and reload the browser.

---

## What changed visually

### Toolbar
- **All groups are a uniform 40px tall** — status, style, swatches, prefix input
- **Select-all** is a CSS ring circle (no text), identical to per-item circles
- **Search** is a clean SVG magnifier — no emoji
- **✓ ≈ → B I H ✕** are SVG icons or large bold text, near-white for visibility
- **Color swatches** are filled circles, scale on hover
- **Prefix input** matches toolbar height

### Date header
- Weekday label in brand purple, date bold and large
- **Date picker** is a custom styled button (SVG calendar icon + ISO date text);
  the native `<input type="date">` is hidden but functional underneath —
  clicking anywhere on the button opens the OS date picker

### Item cards
- Each item is a **rounded card** with shadow and hover lift
- **4px left accent bar** + subtle tinted gradient for colored items
- **Prefix badge** in its own pill — clearly separated from body text
- **Select circle** fills purple when selected, white dot inside

### Add form
- **Add button** stretches to match textarea height

### Design tokens
- Brand color: `oklch(63% 0.27 293)` — purple from the Elixdo logo gem
- Full light/dark token sets — switches via `data-theme` attribute
- Font: **DM Sans** from Google Fonts
