defmodule TraderPocWeb.ActivityDashboardLive do
  use TraderPocWeb, :live_view

  alias TraderPoc.Trading
  alias TraderPocWeb.Presence
  import TraderPocWeb.NavBar

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to all trade topics to get presence updates
    if connected?(socket) do
      subscribe_to_all_trades()
    end

    # Load all trades
    all_trades = Trading.list_all_trades()

    # Get presence info for each trade
    trades_with_presence = Enum.map(all_trades, fn trade ->
      topic = "trade:#{trade.id}"
      presences = Presence.list(topic)

      %{
        trade: trade,
        presences: presences,
        online_count: map_size(presences)
      }
    end)

    {:ok,
     assign(socket,
       trades_with_presence: trades_with_presence,
       total_users_online: count_total_users_online(trades_with_presence)
     )}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Reload presence data when someone joins/leaves any room
    all_trades = Trading.list_all_trades()

    trades_with_presence = Enum.map(all_trades, fn trade ->
      topic = "trade:#{trade.id}"
      presences = Presence.list(topic)

      %{
        trade: trade,
        presences: presences,
        online_count: map_size(presences)
      }
    end)

    {:noreply,
     assign(socket,
       trades_with_presence: trades_with_presence,
       total_users_online: count_total_users_online(trades_with_presence)
     )}
  end

  @impl true
  def handle_info({:typing, _user_id}, socket) do
    # Ignore typing events - dashboard doesn't need them
    {:noreply, socket}
  end

  @impl true
  def handle_info(:stop_typing, socket) do
    # Ignore stop typing events - dashboard doesn't need them
    {:noreply, socket}
  end

  @impl true
  def handle_info({:trade_updated, _update_type}, socket) do
    # Ignore trade update events - we only care about presence
    # (Could optionally refresh trade data here if needed)
    {:noreply, socket}
  end

  defp subscribe_to_all_trades do
    # Get all trades and subscribe to their presence topics
    all_trades = Trading.list_all_trades()

    Enum.each(all_trades, fn trade ->
      topic = "trade:#{trade.id}"
      Phoenix.PubSub.subscribe(TraderPoc.PubSub, topic)
    end)
  end

  defp count_total_users_online(trades_with_presence) do
    trades_with_presence
    |> Enum.map(& &1.online_count)
    |> Enum.sum()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.nav_bar current_user={@current_user} />

    <div class="max-w-7xl mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-100 mb-2">Activity Dashboard</h1>
        <p class="text-gray-300">Real-time view of all active trade rooms and participants</p>
      </div>

      <!-- Summary Stats -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-blue-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Trades</dt>
                <dd class="text-2xl font-semibold text-gray-900"><%= length(@trades_with_presence) %></dd>
              </dl>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-green-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Users Online</dt>
                <dd class="text-2xl font-semibold text-gray-900"><%= @total_users_online %></dd>
              </dl>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-purple-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Active Rooms</dt>
                <dd class="text-2xl font-semibold text-gray-900">
                  <%= Enum.count(@trades_with_presence, fn t -> t.online_count > 0 end) %>
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Trade Rooms List -->
      <div class="bg-white rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h2 class="text-lg font-semibold text-gray-900">Trade Rooms</h2>
        </div>

        <div class="divide-y divide-gray-200">
          <%= if @trades_with_presence == [] do %>
            <div class="px-6 py-12 text-center">
              <p class="text-gray-500">No trades created yet</p>
            </div>
          <% else %>
            <%= for item <- @trades_with_presence do %>
              <div class="px-6 py-4 hover:bg-gray-50 transition-colors">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center space-x-3 mb-2">
                      <h3 class="text-lg font-semibold text-gray-900"><%= item.trade.title %></h3>
                      <span class="text-sm text-gray-500">(<%= item.trade.invitation_code %>)</span>
                      <span class={[
                        "px-2 py-1 rounded-full text-xs font-medium",
                        status_class(item.trade.status)
                      ]}>
                        <%= format_status(item.trade.status) %>
                      </span>
                    </div>

                    <div class="flex items-center space-x-6 text-sm text-gray-600 mb-3">
                      <span>💰 $<%= item.trade.current_price %></span>
                      <span>📦 Qty: <%= item.trade.quantity %></span>
                    </div>

                    <!-- Participants -->
                    <div class="space-y-1">
                      <div class="text-sm font-medium text-gray-700">Participants:</div>

                      <%= if item.online_count == 0 do %>
                        <div class="text-sm text-gray-500 italic">No one currently online</div>
                      <% else %>
                        <div class="flex flex-wrap gap-3">
                          <%= for {_user_id, %{metas: [meta | _]}} <- item.presences do %>
                            <div class="flex items-center space-x-2 bg-green-50 px-3 py-1 rounded-full">
                              <span class="text-green-500 text-xs">●</span>
                              <span class="text-sm font-medium text-gray-900"><%= meta.name %></span>
                              <span class="text-xs text-gray-500">(<%= meta.role %>)</span>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div class="ml-4">
                    <.link
                      navigate={~p"/room/#{item.trade.invitation_code}"}
                      class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                    >
                      View Room
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Live Updates Indicator -->
      <div class="mt-4 text-center">
        <div class="inline-flex items-center space-x-2 text-sm text-gray-500">
          <span class="relative flex h-3 w-3">
            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75">
            </span>
            <span class="relative inline-flex rounded-full h-3 w-3 bg-green-500"></span>
          </span>
          <span>Live updates enabled</span>
        </div>
      </div>
    </div>
    """
  end

  defp status_class("draft"), do: "bg-gray-100 text-gray-800"
  defp status_class("in_negotiation"), do: "bg-blue-100 text-blue-800"
  defp status_class("accepted"), do: "bg-green-100 text-green-800"
  defp status_class("rejected"), do: "bg-red-100 text-red-800"

  defp format_status("draft"), do: "Draft"
  defp format_status("in_negotiation"), do: "In Negotiation"
  defp format_status("accepted"), do: "Accepted"
  defp format_status("rejected"), do: "Rejected"
end
