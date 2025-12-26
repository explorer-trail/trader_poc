defmodule TraderPocWeb.TradeRoomLive do
  use TraderPocWeb, :live_view

  alias TraderPoc.Trading
  alias Phoenix.PubSub
  alias TraderPocWeb.Presence

  @impl true
  def mount(%{"invitation_code" => code}, _session, socket) do
    case Trading.get_trade_by_code(code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Trade not found")
         |> push_navigate(to: ~p"/trades")}

      trade ->
        user = socket.assigns.current_user

        # Check access control
        cond do
          trade.seller_id == user.id ->
            # Seller access granted
            init_trade_room(socket, trade, user, :seller)

          trade.buyer_id == user.id ->
            # Buyer access granted - mark as joined if first time
            if trade.status == "draft" do
              {:ok, updated_trade} = Trading.mark_buyer_joined(trade, user.id)
              init_trade_room(socket, updated_trade, user, :buyer)
            else
              init_trade_room(socket, trade, user, :buyer)
            end

          true ->
            # Access denied
            {:ok,
             socket
             |> put_flash(:error, "You don't have permission to access this trade")
             |> push_navigate(to: ~p"/trades")}
        end
    end
  end

  defp init_trade_room(socket, trade, user, role) do
    # Subscribe to PubSub for real-time updates
    topic = "trade:#{trade.id}"
    PubSub.subscribe(TraderPoc.PubSub, topic)

    # Track user presence
    {:ok, _} =
      Presence.track(self(), topic, user.id, %{
        name: user.name,
        role: role,
        online_at: System.system_time(:second)
      })

    # Load all related data
    messages = Trading.list_messages(trade.id)
    versions = Trading.list_versions(trade.id)
    actions = Trading.list_actions(trade.id)

    # Get current presences
    presences = Presence.list(topic)

    {:ok,
     assign(socket,
       trade: trade,
       role: role,
       messages: messages,
       versions: versions,
       actions: actions,
       presences: presences,
       typing_user: nil,
       message_input: "",
       show_amend_modal: false,
       show_accept_modal: false,
       show_amendment_request_modal: false,
       amend_form: %{},
       amendment_request_reason: ""
     )}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    if String.trim(content) != "" do
      trade = socket.assigns.trade
      user = socket.assigns.current_user

      case Trading.create_message(trade, user.id, content) do
        {:ok, _message} ->
          # Broadcast update and stop typing indicator
          broadcast_update(trade.id, :message_sent)
          broadcast_typing_stopped(trade.id)

          {:noreply, assign(socket, message_input: "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("typing", _params, socket) do
    # User is typing - broadcast to other party
    user_id = socket.assigns.current_user.id
    trade_id = socket.assigns.trade.id

    PubSub.broadcast(TraderPoc.PubSub, "trade:#{trade_id}", {:typing, user_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_typing", _params, socket) do
    # User stopped typing
    broadcast_typing_stopped(socket.assigns.trade.id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_amend_modal", _params, socket) do
    trade = socket.assigns.trade

    amend_form = %{
      "price" => to_string(trade.current_price),
      "quantity" => to_string(trade.quantity),
      "description" => trade.description || "",
      "change_reason" => ""
    }

    {:noreply, assign(socket, show_amend_modal: true, amend_form: amend_form)}
  end

  @impl true
  def handle_event("hide_amend_modal", _params, socket) do
    {:noreply, assign(socket, show_amend_modal: false)}
  end

  @impl true
  def handle_event("amend_trade", %{"amend" => params}, socket) do
    trade = socket.assigns.trade
    user = socket.assigns.current_user

    case Trading.amend_trade(trade, params, user.id) do
      {:ok, _updated_trade} ->
        broadcast_update(trade.id, :trade_amended)

        {:noreply,
         socket
         |> put_flash(:info, "Trade amended successfully")
         |> assign(show_amend_modal: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to amend trade")}
    end
  end

  @impl true
  def handle_event("show_accept_modal", _params, socket) do
    {:noreply, assign(socket, show_accept_modal: true)}
  end

  @impl true
  def handle_event("hide_accept_modal", _params, socket) do
    {:noreply, assign(socket, show_accept_modal: false)}
  end

  @impl true
  def handle_event("accept_trade", _params, socket) do
    trade = socket.assigns.trade
    user = socket.assigns.current_user

    case Trading.accept_trade(trade, user.id) do
      {:ok, _updated_trade} ->
        broadcast_update(trade.id, :trade_accepted)

        {:noreply,
         socket
         |> assign(show_accept_modal: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to accept trade")}
    end
  end

  @impl true
  def handle_event("reject_trade", _params, socket) do
    trade = socket.assigns.trade
    user = socket.assigns.current_user

    case Trading.reject_trade(trade, user.id) do
      {:ok, _updated_trade} ->
        broadcast_update(trade.id, :trade_rejected)

        {:noreply, put_flash(socket, :info, "Trade rejected")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject trade")}
    end
  end

  @impl true
  def handle_event("show_amendment_request_modal", _params, socket) do
    {:noreply, assign(socket, show_amendment_request_modal: true)}
  end

  @impl true
  def handle_event("hide_amendment_request_modal", _params, socket) do
    {:noreply, assign(socket, show_amendment_request_modal: false)}
  end

  @impl true
  def handle_event("request_amendment", %{"reason" => reason}, socket) do
    trade = socket.assigns.trade
    user = socket.assigns.current_user

    case Trading.request_amendment(trade, user.id, reason) do
      {:ok, _action} ->
        broadcast_update(trade.id, :amendment_requested)

        {:noreply,
         socket
         |> put_flash(:info, "Amendment request sent")
         |> assign(show_amendment_request_modal: false, amendment_request_reason: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to request amendment")}
    end
  end

  @impl true
  def handle_info({:trade_updated, update_type}, socket) do
    trade_id = socket.assigns.trade.id

    case update_type do
      :message_sent ->
        # Only reload messages and actions
        messages = Trading.list_messages(trade_id)
        actions = Trading.list_actions(trade_id)
        {:noreply, assign(socket, messages: messages, actions: actions)}

      :trade_amended ->
        # Reload trade, versions, and actions (not messages)
        trade = Trading.get_trade(trade_id)
        versions = Trading.list_versions(trade_id)
        actions = Trading.list_actions(trade_id)

        socket =
          socket
          |> assign(trade: trade, versions: versions, actions: actions)
          |> put_flash(:info, "The seller has amended the deal")

        {:noreply, socket}

      :amendment_requested ->
        # Reload actions to show the request
        actions = Trading.list_actions(trade_id)

        socket =
          socket
          |> assign(actions: actions)
          |> put_flash(:info, "The buyer has requested an amendment")

        {:noreply, socket}

      :trade_accepted ->
        # Reload trade and actions
        trade = Trading.get_trade(trade_id)
        actions = Trading.list_actions(trade_id)

        socket =
          socket
          |> assign(trade: trade, actions: actions)
          |> put_flash(:success, "The deal has been accepted!")

        {:noreply, socket}

      :trade_rejected ->
        # Reload trade and actions
        trade = Trading.get_trade(trade_id)
        actions = Trading.list_actions(trade_id)

        socket =
          socket
          |> assign(trade: trade, actions: actions)
          |> put_flash(:error, "The deal has been rejected")

        {:noreply, socket}

      _ ->
        # Fallback: reload everything
        trade = Trading.get_trade(trade_id)
        messages = Trading.list_messages(trade_id)
        versions = Trading.list_versions(trade_id)
        actions = Trading.list_actions(trade_id)

        {:noreply, assign(socket, trade: trade, messages: messages, versions: versions, actions: actions)}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: _diff}, socket) do
    # Update presences when users join or leave
    topic = "trade:#{socket.assigns.trade.id}"
    presences = Presence.list(topic)

    # Check if typing user left
    typing_user =
      if socket.assigns.typing_user && !Map.has_key?(presences, socket.assigns.typing_user) do
        nil
      else
        socket.assigns.typing_user
      end

    {:noreply, assign(socket, presences: presences, typing_user: typing_user)}
  end

  @impl true
  def handle_info({:typing, user_id}, socket) do
    # Someone started typing
    {:noreply, assign(socket, typing_user: user_id)}
  end

  @impl true
  def handle_info(:stop_typing, socket) do
    # Typing indicator timeout
    {:noreply, assign(socket, typing_user: nil)}
  end

  defp broadcast_update(trade_id, update_type) do
    PubSub.broadcast(TraderPoc.PubSub, "trade:#{trade_id}", {:trade_updated, update_type})
  end

  defp broadcast_typing_stopped(trade_id) do
    PubSub.broadcast(TraderPoc.PubSub, "trade:#{trade_id}", :stop_typing)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8">
      <%= if @trade.status == "accepted" do %>
        <div class="bg-green-50 border-2 border-green-500 rounded-lg p-8 mb-6 text-center">
          <div class="text-6xl mb-4">🎉</div>
          <h2 class="text-3xl font-bold text-green-900 mb-2">Congratulations!</h2>
          <p class="text-lg text-green-700">The deal has been accepted!</p>
          <p class="text-green-600 mt-2">
            Final Price: $<%= @trade.current_price %> | Quantity: <%= @trade.quantity %>
          </p>
        </div>
      <% end %>

      <div class="mb-6">
        <.link navigate={~p"/trades"} class="text-blue-600 hover:text-blue-700 flex items-center">
          <span class="mr-2">←</span> Back to Trades
        </.link>
      </div>

      <div class="bg-white rounded-lg shadow-lg mb-6 p-6">
        <div class="flex justify-between items-start mb-4">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 mb-2"><%= @trade.title %></h1>
            <span class={[
              "px-3 py-1 rounded-full text-sm font-medium",
              status_class(@trade.status)
            ]}>
              <%= format_status(@trade.status) %>
            </span>
          </div>
          <div class="text-right">
            <p class="text-sm text-gray-500 mb-2">
              You are the <span class="font-semibold"><%= @role %></span>
            </p>
            <div class="text-sm">
              <div class="font-semibold text-gray-700 mb-1">Participants:</div>
              <%= for {user_id, %{metas: [meta | _]}} <- @presences do %>
                <div class="flex items-center justify-end space-x-2">
                  <span class="text-green-500">●</span>
                  <span class="text-gray-900"><%= meta.name %></span>
                  <span class="text-gray-500">(<%= meta.role %>)</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="border-t pt-4">
          <h2 class="text-xl font-semibold mb-4">Current Deal</h2>
          <div class="grid grid-cols-3 gap-4">
            <div>
              <span class="text-sm text-gray-500">Price</span>
              <p class="text-2xl font-bold text-gray-900">$<%= @trade.current_price %></p>
            </div>
            <div>
              <span class="text-sm text-gray-500">Quantity</span>
              <p class="text-2xl font-bold text-gray-900"><%= @trade.quantity %></p>
            </div>
            <div>
              <span class="text-sm text-gray-500">Description</span>
              <p class="text-gray-900"><%= @trade.description %></p>
            </div>
          </div>
        </div>

        <%= if @trade.status != "accepted" and @trade.status != "rejected" do %>
          <div class="border-t pt-4 mt-4">
            <h2 class="text-xl font-semibold mb-4">Actions</h2>
            <div class="flex space-x-3">
              <%= if @role == :seller do %>
                <button
                  phx-click="show_amend_modal"
                  class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
                >
                  Amend Deal
                </button>
              <% end %>

              <%= if @role == :buyer do %>
                <button
                  phx-click="show_accept_modal"
                  class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700"
                >
                  Accept Deal
                </button>
                <button
                  phx-click="show_amendment_request_modal"
                  class="bg-yellow-600 text-white px-4 py-2 rounded-md hover:bg-yellow-700"
                >
                  Request Amendment
                </button>
                <button
                  phx-click="reject_trade"
                  class="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700"
                  data-confirm="Are you sure you want to reject this trade?"
                >
                  Reject Deal
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Action Timeline -->
      <%= if length(@actions) > 0 do %>
        <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
          <h2 class="text-xl font-semibold mb-4">Activity Timeline</h2>
          <div class="space-y-3 max-h-64 overflow-y-auto">
            <%= for action <- Enum.take(@actions, 10) do %>
              <div class={[
                "border-l-4 pl-4 py-2",
                action_border_color(action.action_type)
              ]}>
                <div class="flex justify-between items-start">
                  <div>
                    <p class="font-semibold text-gray-900">
                      <%= action.user.name %> <%= action_description(action.action_type) %>
                    </p>
                    <%= if action.action_type == "amendment_requested" && action.details["reason"] do %>
                      <p class="text-sm text-gray-700 mt-1 bg-yellow-50 p-2 rounded">
                        📝 <strong>Requested changes:</strong> <%= action.details["reason"] %>
                      </p>
                    <% end %>
                    <%= if action.action_type == "amended" && action.details["version"] do %>
                      <p class="text-sm text-gray-600 mt-1">
                        Updated to version <%= action.details["version"] %>
                      </p>
                    <% end %>
                  </div>
                  <span class="text-xs text-gray-500">
                    <%= Calendar.strftime(action.inserted_at, "%I:%M %p") %>
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <div class="grid grid-cols-2 gap-6">
        <!-- Messages -->
        <div class="bg-white rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-semibold mb-4">Messages</h2>
          <div class="space-y-3 mb-4 max-h-96 overflow-y-auto">
            <%= for message <- @messages do %>
              <div class={[
                "p-3 rounded-lg",
                if(message.user_id == @current_user.id, do: "bg-blue-50 ml-8", else: "bg-gray-50 mr-8")
              ]}>
                <p class="text-sm font-semibold text-gray-700"><%= message.user.name %></p>
                <p class="text-gray-900"><%= message.content %></p>
                <p class="text-xs text-gray-500 mt-1">
                  <%= Calendar.strftime(message.inserted_at, "%I:%M %p") %>
                </p>
              </div>
            <% end %>

            <%= if @typing_user && @typing_user != @current_user.id do %>
              <div class="p-2 bg-yellow-50 rounded text-sm text-gray-700 italic">
                <%= get_typing_user_name(@presences, @typing_user) %> is typing...
              </div>
            <% end %>
          </div>

          <.form for={%{}} phx-submit="send_message" class="flex space-x-2">
            <input
              type="text"
              name="content"
              value={@message_input}
              placeholder="Type a message..."
              phx-keyup="typing"
              phx-debounce="500"
              phx-blur="stop_typing"
              class="flex-1 px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 text-gray-900 bg-white"
            />
            <button
              type="submit"
              class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
            >
              Send
            </button>
          </.form>
        </div>

        <!-- Version History -->
        <div class="bg-white rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-semibold mb-4">Version History</h2>
          <div class="space-y-3 max-h-96 overflow-y-auto">
            <%= for version <- @versions do %>
              <div class="border-l-4 border-blue-500 pl-4 py-2">
                <p class="font-semibold text-gray-900">
                  v<%= version.version_number %>: $<%= version.price %>, Qty <%= version.quantity %>
                </p>
                <p class="text-sm text-gray-600"><%= version.description %></p>
                <%= if version.change_reason do %>
                  <p class="text-sm text-gray-500 italic">"<%= version.change_reason %>"</p>
                <% end %>
                <p class="text-xs text-gray-500">
                  by <%= version.changed_by.name %> at <%= Calendar.strftime(version.inserted_at, "%I:%M %p") %>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @show_amend_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg shadow-xl p-8 max-w-md w-full">
            <h2 class="text-2xl font-bold mb-4">Amend Deal</h2>
            <.form for={%{}} phx-submit="amend_trade" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Price ($)</label>
                <input
                  type="number"
                  name="amend[price]"
                  value={@amend_form["price"]}
                  step="0.01"
                  required
                  class="w-full px-4 py-2 border border-gray-300 rounded-md text-gray-900 bg-white"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Quantity</label>
                <input
                  type="number"
                  name="amend[quantity]"
                  value={@amend_form["quantity"]}
                  required
                  class="w-full px-4 py-2 border border-gray-300 rounded-md text-gray-900 bg-white"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
                <textarea
                  name="amend[description]"
                  rows="3"
                  class="w-full px-4 py-2 border border-gray-300 rounded-md text-gray-900 bg-white"
                ><%= @amend_form["description"] %></textarea>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Reason for change</label>
                <input
                  type="text"
                  name="amend[change_reason]"
                  placeholder="Optional"
                  class="w-full px-4 py-2 border border-gray-300 rounded-md text-gray-900 bg-white"
                />
              </div>
              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="hide_amend_modal"
                  class="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  Save Changes
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%= if @show_accept_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg shadow-xl p-8 max-w-md w-full">
            <h2 class="text-2xl font-bold mb-4">Accept Deal</h2>
            <p class="text-gray-700 mb-6">
              Are you sure you want to accept this deal?
            </p>
            <div class="bg-gray-50 p-4 rounded-md mb-6">
              <p class="font-semibold">Final Terms:</p>
              <p>Price: $<%= @trade.current_price %></p>
              <p>Quantity: <%= @trade.quantity %></p>
            </div>
            <div class="flex justify-end space-x-3">
              <button
                phx-click="hide_accept_modal"
                class="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                phx-click="accept_trade"
                class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
              >
                Accept Deal
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_amendment_request_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg shadow-xl p-8 max-w-md w-full">
            <h2 class="text-2xl font-bold mb-4">Request Amendment</h2>
            <.form for={%{}} phx-submit="request_amendment" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  What would you like changed?
                </label>
                <textarea
                  name="reason"
                  rows="4"
                  required
                  placeholder="Describe the changes you'd like..."
                  class="w-full px-4 py-2 border border-gray-300 rounded-md text-gray-900 bg-white"
                ><%= @amendment_request_reason %></textarea>
              </div>
              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="hide_amendment_request_modal"
                  class="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 bg-yellow-600 text-white rounded-md hover:bg-yellow-700"
                >
                  Send Request
                </button>
              </div>
            </.form>
          </div>
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

  defp action_border_color("created"), do: "border-gray-400"
  defp action_border_color("joined"), do: "border-blue-400"
  defp action_border_color("amended"), do: "border-purple-400"
  defp action_border_color("accepted"), do: "border-green-400"
  defp action_border_color("rejected"), do: "border-red-400"
  defp action_border_color("amendment_requested"), do: "border-yellow-400"
  defp action_border_color("message_sent"), do: "border-gray-300"
  defp action_border_color(_), do: "border-gray-400"

  defp action_description("created"), do: "created the trade"
  defp action_description("joined"), do: "joined the negotiation"
  defp action_description("amended"), do: "amended the deal"
  defp action_description("accepted"), do: "accepted the deal ✓"
  defp action_description("rejected"), do: "rejected the deal"
  defp action_description("amendment_requested"), do: "requested an amendment"
  defp action_description("message_sent"), do: "sent a message"
  defp action_description(_), do: "performed an action"

  defp get_typing_user_name(presences, user_id) do
    case Map.get(presences, user_id) do
      %{metas: [meta | _]} -> meta.name
      _ -> "Someone"
    end
  end
end
