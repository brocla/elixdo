import {setupPush} from "./push_notifications";

const RECEIVE_KEY = "elixdo_receive_notifications";
const SUPPRESS_KEY = "elixdo_suppress_notifications";

const PushSettings = {
  mounted() {
    const receiveEl = this.el.querySelector("#receive-notifications");
    const suppressEl = this.el.querySelector("#suppress-notifications");

    if (receiveEl) {
      receiveEl.checked = localStorage.getItem(RECEIVE_KEY) === "true";
      receiveEl.addEventListener("change", async () => {
        localStorage.setItem(RECEIVE_KEY, receiveEl.checked ? "true" : "false");
        const secretPath = window.location.pathname.split("/")[1];
        if (receiveEl.checked) {
          await setupPush(secretPath);
        } else {
          // Unsubscribe — setupPush handles the OFF case (cleans up existing subscription)
          await setupPush(secretPath);
        }
      });
    }

    if (suppressEl) {
      suppressEl.checked = localStorage.getItem(SUPPRESS_KEY) === "true";
      suppressEl.addEventListener("change", () => {
        localStorage.setItem(SUPPRESS_KEY, suppressEl.checked ? "true" : "false");
      });
    }
  }
};

export default PushSettings;
