defmodule FaroWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FaroWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :inner_content, :any, default: nil
  attr :current_scope, :map, default: nil

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-stone-900 text-stone-100">
      <header class="bg-stone-950 border-b border-amber-800/50 shadow-lg">
        <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-14">
            <.link
              navigate={~p"/"}
              class="text-amber-400 font-serif text-xl font-bold tracking-widest uppercase hover:text-amber-300 transition-colors"
            >
              Faro
            </.link>
            <ul class="hidden sm:flex items-center gap-6">
              <li>
                <.link
                  navigate={~p"/"}
                  class="text-stone-300 hover:text-amber-400 text-sm tracking-wide uppercase transition-colors"
                >
                  Home
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/play"}
                  class="text-stone-300 hover:text-amber-400 text-sm tracking-wide uppercase transition-colors"
                >
                  Play
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/rules"}
                  class="text-stone-300 hover:text-amber-400 text-sm tracking-wide uppercase transition-colors"
                >
                  Rules
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/fairness"}
                  class="text-stone-300 hover:text-amber-400 text-sm tracking-wide uppercase transition-colors"
                >
                  Fairness
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/philosophy"}
                  class="text-stone-300 hover:text-amber-400 text-sm tracking-wide uppercase transition-colors"
                >
                  Philosophy
                </.link>
              </li>
            </ul>
            <div class="flex items-center gap-3">
              <span class="text-amber-400 text-sm font-mono">⚡ 1,000,000 sats</span>
            </div>
          </div>
        </nav>
      </header>

      <main class="flex-1">
        {@inner_content}
      </main>

      <footer class="bg-stone-950 border-t border-amber-800/30 py-4 text-center text-stone-500 text-xs tracking-wide">
        Provably fair · HMAC-SHA256 shuffle · All games verifiable on-chain
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
