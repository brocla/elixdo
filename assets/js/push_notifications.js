// Web Push flow:
// 1. Each browser gets a stable device_id (UUID in localStorage).
// 2. When the user opts in, the browser subscribes via PushManager and POSTs
//    the resulting endpoint + keys to the server (stored in push_subscriptions).
// 3. When an item is added, the server sends a push to all subscriptions except
//    the originating device_id, so you are not notified by your own additions.

const DEVICE_ID_KEY = "elixdo_device_id";
const RECEIVE_KEY = "elixdo_receive_notifications";
const SUPPRESS_KEY = "elixdo_suppress_notifications";

export function getDeviceId() {
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
