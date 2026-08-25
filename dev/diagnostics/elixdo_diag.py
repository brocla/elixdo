"""On-device diagnostics for the Elixdo PWA, over the Chrome DevTools Protocol.

Built while chasing phoenixframework/phoenix#6804 (LiveView socket never
reconnecting after an Android PWA was backgrounded). See README.md for the
workflow and, importantly, why you must DETACH before reproducing.

    python elixdo_diag.py probe        # snapshot socket / LiveView / server state
    python elixdo_diag.py instrument   # install the localStorage event recorder
    python elixdo_diag.py readlog      # dump the recorded trace
    python elixdo_diag.py clearlog     # reset the trace
    python elixdo_diag.py bundle       # what JS is actually deployed and running
"""

import json
import sys
import urllib.request

from cdp import evaluate

CDP_LIST = "http://localhost:9222/json/list"
LOG_KEY = "elixdoDiag"


def find_page(match="elixdo"):
    """WebSocket debugger URL of the open Elixdo page.

    Targets only appear while the page is actually open, so the PWA must be
    running on the phone.
    """
    with urllib.request.urlopen(CDP_LIST, timeout=10) as resp:
        targets = json.load(resp)
    pages = [t for t in targets
             if t.get("type") == "page" and match in (t.get("url") or "")]
    if not pages:
        seen = [f"{t.get('type')}:{(t.get('url') or '(blank)')[:60]}" for t in targets]
        raise SystemExit(
            "No Elixdo page target attached. Open the PWA on the phone.\n"
            "Targets seen: " + ", ".join(seen)
        )
    return pages[0]["webSocketDebuggerUrl"]


PROBE = r"""
(() => {
  const s = liveSocket.socket;
  const out = {
    visibility: document.visibilityState,
    connectionState: s.connectionState(),
    isConnected: s.isConnected(),
    pageHidden: s.pageHidden,
    closeWasClean: s.closeWasClean,
    disconnecting: s.disconnecting,
    connIsNull: s.conn === null,
    establishedConnections: s.establishedConnections,
    connectClock: s.connectClock,
    channels: s.channels.map(c => ({topic: c.topic, state: c.state})),
    reconnectTries: s.reconnectTimer ? s.reconnectTimer.tries : null,
    recorderInstalled: !!window.__elixdoRec
  };
  const t0 = performance.now();
  return fetch("/health", {cache: "no-store"})
    .then(r => ({...out, healthStatus: r.status, healthMs: Math.round(performance.now() - t0)}))
    .catch(e => ({...out, healthError: String(e)}))
    .then(o => JSON.stringify(o));
})()
"""

BUNDLE = r"""
(() => {
  const el = document.querySelector('script[src*="/assets/js/app-"]');
  return fetch(el.src, {cache: "no-store"}).then(r => r.text()).then(t => JSON.stringify({
    running: el.src.split("/").pop(),
    bytes: t.length,
    visibilitychangeHandlers: (t.match(/visibilitychange/g) || []).length,
    resumeListener: t.includes('addEventListener("resume"'),
    ourRetryLoop: /\[1e3,2e3,5e3,1e4\]/.test(t),
    writesPageHidden: /pageHidden=!1/.test(t)
  }));
})()
"""

# Records to localStorage so the trace survives Chrome freezing the page while
# nothing is attached. Wraps connect() and pageHidden so each recovery can be
# attributed to the code that caused it.
INSTRUMENT = r"""
(() => {
  const KEY = "elixdoDiag";
  const s = liveSocket.socket;
  const push = (ev) => {
    try {
      const log = JSON.parse(localStorage.getItem(KEY) || "[]");
      log.push({t: new Date().toISOString(), ...ev});
      localStorage.setItem(KEY, JSON.stringify(log.slice(-400)));
    } catch (e) {}
  };
  if (window.__elixdoRec) return "already installed";
  window.__elixdoRec = true;

  let hiddenAt = document.hidden ? Date.now() : null;
  const sinceHidden = () => hiddenAt ? Math.round((Date.now() - hiddenAt) / 1000) : null;
  const frames = () => (new Error().stack || "").split("\n").slice(2, 5)
      .map(f => f.trim().replace(/https:\/\/[^ )]+\//g, "").replace(/^at /, "")).join(" <- ");

  const origConnect = s.connect.bind(s);
  s.connect = function (...a) {
    push({e: "connect()", vis: document.visibilityState, pageHidden: s.pageHidden,
          conn: s.connectionState(), hiddenFor: sinceHidden(), by: frames()});
    return origConnect(...a);
  };

  // phoenix >= 1.8.13 makes pageHidden a getter; only wrap it if it is a
  // plain writable property, otherwise defineProperty would fight the getter.
  const desc = Object.getOwnPropertyDescriptor(s, "pageHidden");
  if (desc && "value" in desc) {
    let value = s.pageHidden;
    Object.defineProperty(s, "pageHidden", {
      configurable: true,
      get() { return value; },
      set(v) {
        if (v !== value) push({e: "pageHidden=" + v, vis: document.visibilityState, by: frames()});
        value = v;
      }
    });
  }

  const log = (name, target) => target.addEventListener(name, () => {
    if (name === "visibilitychange" && document.hidden) hiddenAt = Date.now();
    push({e: name, vis: document.visibilityState, pageHidden: s.pageHidden,
          conn: s.connectionState(), hiddenFor: sinceHidden()});
  });
  ["visibilitychange", "freeze", "resume"].forEach(n => log(n, document));
  ["focus", "blur", "pageshow", "pagehide"].forEach(n => log(n, window));

  s.onOpen(() => push({e: "sock:open", clock: s.connectClock, hiddenFor: sinceHidden()}));
  s.onClose((ev) => push({e: "sock:close", code: ev && ev.code}));

  push({e: "=== recorder installed ===", vis: document.visibilityState,
        conn: s.connectionState()});
  return "installed";
})()
"""

COMMANDS = {
    "probe": PROBE,
    "bundle": BUNDLE,
    "instrument": INSTRUMENT,
    "readlog": f'localStorage.getItem("{LOG_KEY}") || "[]"',
    "clearlog": f'(localStorage.removeItem("{LOG_KEY}"), "cleared")',
}


def render_log(entries):
    for entry in entries:
        stamp = entry.pop("t", "")[11:23]
        kind = entry.pop("e", "")
        extra = " ".join(f"{k}={v}" for k, v in entry.items() if v is not None)
        print(f"{stamp}  {kind:<18} {extra}")
    print(f"\n({len(entries)} entries)")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "probe"
    if cmd not in COMMANDS:
        raise SystemExit(f"unknown command {cmd!r}; pick one of {', '.join(COMMANDS)}")

    msg = evaluate(find_page(), COMMANDS[cmd], timeout=40)
    result = msg.get("result", {})
    if result.get("exceptionDetails"):
        print("EXCEPTION:", json.dumps(result["exceptionDetails"])[:1500])
        return

    value = result.get("result", {}).get("value")
    try:
        parsed = json.loads(value)
    except (TypeError, ValueError):
        print(value)
        return

    render_log(parsed) if cmd == "readlog" else print(json.dumps(parsed, indent=2))


if __name__ == "__main__":
    main()
