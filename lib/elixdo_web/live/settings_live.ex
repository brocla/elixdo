defmodule ElixdoWeb.SettingsLive do
  @moduledoc false
  use ElixdoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="push-settings" phx-hook="PushSettings">
      <h1>Notification Settings</h1>

      <div class="setting-row">
        <label>
          <input type="checkbox" id="receive-notifications" />
          Notify me on this device
        </label>
        <p class="setting-description">
          Receive a push notification when someone adds a new item.
        </p>
      </div>

      <div class="setting-row">
        <label>
          <input type="checkbox" id="suppress-notifications" />
          Don't send from this device
        </label>
        <p class="setting-description">
          Suppress notifications triggered by your own additions.
        </p>
      </div>

      <p class="ios-note">
        Note: iOS requires the app to be added to your home screen first (iOS 16.4+).
      </p>
    </div>
    """
  end
end
