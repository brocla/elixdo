# On-device diagnostics

Drives Chrome DevTools Protocol against the Elixdo PWA on an Android phone over
`adb`, so socket and page-lifecycle state can be measured on the real device
instead of guessed at.

Built while diagnosing [phoenixframework/phoenix#6804][issue] — the LiveView
socket never reconnecting after the app had been backgrounded for a few minutes.
That turned out to be Chrome not firing `visibilitychange` when it unfreezes a
PWA, leaving phoenix's `pageHidden` flag stuck `true` and every reconnect path
gated behind it. Fixed upstream in phoenix v1.8.13.

[issue]: https://github.com/phoenixframework/phoenix/issues/6804

## The one thing that matters

**Attaching a debugger stops Chrome from freezing the page, and freezing is a
precondition for the bug.** With DevTools (or CDP) attached the whole time, it
never reproduces. This is why the tooling records to `localStorage` rather than
streaming: install the recorder, *detach*, reproduce, reattach, read the log.

## Setup

On the phone, once: enable Developer options (tap Build number seven times),
then USB debugging. Connect with a data cable, set USB mode to File transfer,
and accept the "Allow USB debugging?" prompt.

```bash
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb"

"$ADB" devices -l                                          # want "device", not "unauthorized"
"$ADB" forward tcp:9222 localabstract:chrome_devtools_remote   # attach
"$ADB" forward --remove-all                                     # detach
```

Targets only exist while the page is open, so the PWA must be running. If it is
backgrounded, network calls from the page (`probe`, `bundle`) will time out —
Chrome throttles background pages hard. Foreground the app first.

## Commands

Run from this directory (`elixdo_diag.py` imports `cdp.py`).

| command | what it does |
|---|---|
| `probe` | socket state, channels, `connectClock`, plus a timed `/health` call |
| `bundle` | which JS is deployed vs running, and which handlers are in it |
| `instrument` | install the recorder |
| `readlog` | dump the trace |
| `clearlog` | reset the trace |

## Typical session

```bash
"$ADB" forward tcp:9222 localabstract:chrome_devtools_remote
python elixdo_diag.py probe            # healthy baseline
python elixdo_diag.py clearlog
python elixdo_diag.py instrument
"$ADB" forward --remove-all            # DETACH before reproducing

# background the app for several minutes, then foreground it

"$ADB" forward tcp:9222 localabstract:chrome_devtools_remote
python elixdo_diag.py readlog
```

## Reading a trace

The recorder wraps `socket.connect()` and captures a stack for each call, so a
recovery can be attributed to whichever code caused it — our retry loop,
phoenix's own reconnect timer, or a lifecycle handler. Minified frames appear as
`app-<digest>.js:LINE:COL`; resolve them by fetching that bundle and slicing at
the offset.

A failing cycle looked like this — note `resume` arriving with no
`visibilitychange` anywhere, which is the whole bug:

```
visibilitychange  vis=hidden   conn=open          -> pageHidden = true
sock:close        code=1006
freeze            hiddenFor=60
resume            vis=visible  conn=closed        pageHidden STILL true
connect()         by=<whichever handler recovered it>
sock:open
```

## Reproducing the failure on demand

Rather than waiting minutes for a natural cycle, force the stuck-flag state
while the app is visible. Only works on phoenix < 1.8.13, where `pageHidden` is
a writable property:

```js
liveSocket.socket.pageHidden = true
liveSocket.socket.conn.close()
```

Phoenix's reconnect timer then fires, sees the flag, tears down without
rescheduling, and whatever recovery layer you are testing has to do the rest.
Note that repeatedly closing the socket in quick succession creates enough churn
to trigger the reload fallback; leave several seconds between trials.
