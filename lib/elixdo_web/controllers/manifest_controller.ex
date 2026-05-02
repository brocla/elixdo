defmodule ElixdoWeb.ManifestController do
  use ElixdoWeb, :controller

  def show(conn, _params) do
    secret = System.get_env("SECRET_PATH", "dev-secret")

    manifest = %{
      name: "Elixdo",
      short_name: "Elixdo",
      start_url: "/#{secret}/list/today",
      display: "standalone",
      background_color: "#1b1928",
      theme_color: "#1b1928",
      icons: [
        %{
          src: "/images/web-app-manifest-192x192.png",
          sizes: "192x192",
          type: "image/png",
          purpose: "maskable"
        },
        %{
          src: "/images/web-app-manifest-512x512.png",
          sizes: "512x512",
          type: "image/png",
          purpose: "maskable"
        }
      ]
    }

    conn
    |> put_resp_content_type("application/manifest+json")
    |> json(manifest)
  end
end
