// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/elixdo"
import topbar from "../vendor/topbar"
import Swipe from "./swipe"
import AddItem from "./add_item"
import EditItem from "./edit_item"
import DragSort from "./drag_sort"
import VoiceInput from "./voice_input"
import {setupPush, shouldSuppress, getDeviceId} from "./push_notifications"
import PushSettings from "./push_settings"

const SearchFocus = {
  mounted() { this.el.focus() }
}

const ArrowPicker = {
  mounted() {
    this.handleEvent("open-arrow-picker", ({default_date}) => {
      this.el.value = default_date || ""
      this.el.showPicker()
    })

    this.el.addEventListener("change", () => {
      if (this.el.value) {
        this.pushEvent("confirm_arrow", {to_date: this.el.value})
        this.el.value = ""
      }
    })
  }
}

const PushContext = {
  mounted() {
    this.pushEvent("set_push_context", {device_id: getDeviceId(), suppress: shouldSuppress()})
  }
}

let Hooks = {...colocatedHooks}
Hooks.Swipe = Swipe
Hooks.AddItem = AddItem
Hooks.EditItem = EditItem
Hooks.DragSort = DragSort
Hooks.SearchFocus = SearchFocus
Hooks.VoiceInput = VoiceInput
Hooks.PushSettings = PushSettings
Hooks.PushContext = PushContext
Hooks.ArrowPicker = ArrowPicker

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// No longPollFallbackMs. The downgrade it performs is one-way: Socket#connect
// skips the fallback path once transport is already LongPoll, and nothing ever
// calls replaceTransport back to WebSocket, so one flaky moment costs the page
// its WebSocket for as long as it lives. This app runs on networks where
// WebSockets work, so that trade is not worth making. Set it if Elixdo ever
// needs to work somewhere WebSockets are blocked outright -- without it, it
// simply will not connect there.
const liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken,
    device_id: getDeviceId(),
    suppress: shouldSuppress()
  },
  hooks: Hooks,
})

// Extract secret path from URL (first segment after /)
const secretPath = window.location.pathname.split("/").filter(Boolean)[0] || ""

// Set up push notifications on page load
setupPush(secretPath).catch(() => {})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// ── Foreground recovery backstop ──────────────────────────────────
// Phoenix's reconnect timer calls teardown() with no callback and no
// reschedule when it fires while the page is hidden, so recovery rests
// entirely on a later visibilitychange or resume. If a foreground delivers
// neither, phoenix has nothing scheduled and this does. Armed by the socket
// close and idle while connected.
//
// Chrome not firing visibilitychange on resume is what made that gap bite:
// phoenixframework/phoenix#6804, fixed in 1.8.13. See dev/diagnostics for the
// harness that found it.
//
// The first delay is 3s deliberately. Phoenix recovers a frozen-page resume in
// well under a second, so anything shorter races it for no benefit. At 3s this
// can only fire when phoenix has genuinely failed to act.
const RETRY_BACKOFF_MS = [3000, 5000, 10000]
const RELOAD_AFTER_MS = 30000

let downSince = null
let retryTimer = null
let retryTries = 0

// Reconnect if the page is visible and the socket is down. document.hidden is
// read directly on every call, never cached -- that staleness was the bug.
function attemptRecovery() {
  const socket = liveSocket.socket

  if (document.hidden || socket.isConnected()) {
    downSince = null
    return
  }
  if (socket.connectionState() === "connecting") return

  downSince = downSince || Date.now()

  socket.connect()

  // Last resort if reconnecting never takes -- what killing the app achieves.
  if (Date.now() - downSince > RELOAD_AFTER_MS) window.location.reload()
}

// Retry armed on close, cancelled on open.
//
// The close is the reliable signal: every failing cycle recorded on the device
// had a sock:close (code 1006). The lifecycle events are the unreliable part,
// so this loop deliberately depends on none of them -- it keeps ticking while
// hidden (doing nothing) and recovers on its own once the page is visible
// again, whether or not any event announces that.
function scheduleRetry() {
  clearTimeout(retryTimer)
  const delay = RETRY_BACKOFF_MS[retryTries] || RETRY_BACKOFF_MS[RETRY_BACKOFF_MS.length - 1]
  retryTries = Math.min(retryTries + 1, RETRY_BACKOFF_MS.length)

  retryTimer = setTimeout(() => {
    if (liveSocket.socket.isConnected()) return cancelRetry()
    attemptRecovery()
    scheduleRetry()
  }, delay)
}

function cancelRetry() {
  clearTimeout(retryTimer)
  retryTimer = null
  retryTries = 0
}

liveSocket.socket.onClose(() => scheduleRetry())
liveSocket.socket.onOpen(() => cancelRetry())

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/sw.js");
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

