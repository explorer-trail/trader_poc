defmodule TraderPocWeb.TradeListLive do
  use TraderPocWeb, :live_view

  alias TraderPoc.Trading
  import TraderPocWeb.NavBar

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    trades = Trading.list_trades(user_id)

    # Add role information to each trade
    trades_with_role =
      Enum.map(trades, fn trade ->
        role = if trade.seller_id == user_id, do: :seller, else: :buyer
        {trade, role}
      end)

    {:ok, assign(socket, trades_with_role: trades_with_role)}
  end

  @impl true
  def handle_event("copy_link", %{"code" => _code}, socket) do
    {:noreply, put_flash(socket, :info, "Invitation link copied to clipboard!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.nav_bar current_user={@current_user} />

    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-3xl font-bold text-gray-100">My Trades</h1>
          <p class="text-gray-300 mt-1">Manage your trade negotiations</p>
        </div>
        <.link
          navigate={~p"/trades/new"}
          class="bg-blue-600 text-white px-6 py-2 rounded-md hover:bg-blue-700 transition-colors"
        >
          Create New Trade
        </.link>
      </div>

      <%= if @trades_with_role == [] do %>
        <div class="bg-white rounded-lg shadow p-12 text-center">
          <p class="text-gray-500 text-lg mb-4">You don't have any trades yet.</p>
          <.link
            navigate={~p"/trades/new"}
            class="inline-block bg-blue-600 text-white px-6 py-2 rounded-md hover:bg-blue-700 transition-colors"
          >
            Create Your First Trade
          </.link>
        </div>
      <% else %>
        <div class="grid gap-4">
          <%= for {trade, role} <- @trades_with_role do %>
            <div class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center space-x-3 mb-2">
                    <h3 class="text-xl font-semibold text-gray-900"><%= trade.title %></h3>
                    <span class={[
                      "px-2 py-1 rounded text-xs font-semibold",
                      if(role == :seller, do: "bg-purple-100 text-purple-800", else: "bg-green-100 text-green-800")
                    ]}>
                      <%= if role == :seller, do: "SELLER", else: "BUYER" %>
                    </span>
                  </div>
                  <p class="text-gray-600 mb-4"><%= trade.description %></p>

                  <div class="grid grid-cols-3 gap-4 mb-4">
                    <div>
                      <span class="text-sm text-gray-500">Price</span>
                      <p class="text-lg font-semibold text-gray-900">$<%= trade.current_price %></p>
                    </div>
                    <div>
                      <span class="text-sm text-gray-500">Quantity</span>
                      <p class="text-lg font-semibold text-gray-900"><%= trade.quantity %></p>
                    </div>
                    <div>
                      <span class="text-sm text-gray-500">
                        <%= if role == :seller, do: "Buyer", else: "Seller" %>
                      </span>
                      <p class="text-lg font-semibold text-gray-900">
                        <%= if role == :seller, do: trade.buyer_name, else: trade.seller.name %>
                      </p>
                    </div>
                  </div>

                  <div class="flex items-center space-x-4">
                    <span class={[
                      "px-3 py-1 rounded-full text-sm font-medium",
                      status_class(trade.status)
                    ]}>
                      <%= format_status(trade.status) %>
                    </span>

                    <%= if role == :seller do %>
                      <div class="flex items-center space-x-2">
                        <code class="bg-gray-100 px-3 py-1 rounded text-sm font-mono text-gray-900">
                          <%= trade.invitation_code %>
                        </code>
                        <button
                          phx-click="copy_link"
                          phx-value-code={trade.invitation_code}
                          onclick={"navigator.clipboard.writeText('#{url(~p"/room/#{trade.invitation_code}")}')"}
                          class="text-blue-600 hover:text-blue-700 text-sm font-medium"
                        >
                          Copy Link
                        </button>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="ml-4">
                  <.link
                    navigate={~p"/room/#{trade.invitation_code}"}
                    class="bg-gray-900 text-white px-4 py-2 rounded-md hover:bg-gray-800 transition-colors"
                  >
                    Enter Room
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
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
