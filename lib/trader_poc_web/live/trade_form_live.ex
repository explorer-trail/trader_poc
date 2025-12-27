defmodule TraderPocWeb.TradeFormLive do
  use TraderPocWeb, :live_view

  alias TraderPoc.Trading
  import TraderPocWeb.NavBar

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{}, as: "trade"),
       errors: []
     )}
  end

  @impl true
  def handle_event("validate", %{"trade" => trade_params}, socket) do
    {:noreply, assign(socket, form: to_form(trade_params, as: "trade"))}
  end

  @impl true
  def handle_event("save", %{"trade" => trade_params}, socket) do
    user_id = socket.assigns.current_user.id

    case Trading.create_trade(trade_params, user_id) do
      {:ok, _trade} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trade created successfully!")
         |> push_navigate(to: ~p"/trades")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create trade. Please check the errors below.")
         |> assign(errors: changeset.errors)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.nav_bar current_user={@current_user} />

    <div class="max-w-2xl mx-auto px-4 py-8">
      <div class="mb-6">
        <.link navigate={~p"/trades"} class="text-blue-600 hover:text-blue-700 flex items-center">
          <span class="mr-2">←</span> Back to Trades
        </.link>
      </div>

      <div class="bg-white rounded-lg shadow-lg p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Create New Trade</h1>
        <p class="text-gray-600 mb-8">Fill in the details to create a trade proposal</p>

        <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
          <div>
            <label for="title" class="block text-sm font-medium text-gray-700 mb-2">
              Title *
            </label>
            <input
              type="text"
              name="trade[title]"
              id="title"
              value={@form[:title].value}
              placeholder="e.g., iPhone 14 Pro"
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900 bg-white"
            />
          </div>

          <div>
            <label for="description" class="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              name="trade[description]"
              id="description"
              rows="3"
              placeholder="Describe the item or service..."
              class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900 bg-white"
            ><%= @form[:description].value %></textarea>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label for="price" class="block text-sm font-medium text-gray-700 mb-2">
                Price ($) *
              </label>
              <input
                type="number"
                name="trade[price]"
                id="price"
                value={@form[:price].value}
                placeholder="1000"
                step="0.01"
                min="0"
                required
                class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900 bg-white"
              />
            </div>

            <div>
              <label for="quantity" class="block text-sm font-medium text-gray-700 mb-2">
                Quantity *
              </label>
              <input
                type="number"
                name="trade[quantity]"
                id="quantity"
                value={@form[:quantity].value}
                placeholder="1"
                min="1"
                required
                class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900 bg-white"
              />
            </div>
          </div>

          <div>
            <label for="buyer_name" class="block text-sm font-medium text-gray-700 mb-2">
              Buyer Name *
            </label>
            <input
              type="text"
              name="trade[buyer_name]"
              id="buyer_name"
              value={@form[:buyer_name].value}
              placeholder="Enter the buyer's name"
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900 bg-white"
            />
            <p class="mt-1 text-sm text-gray-500">
              Only this person will be able to join the negotiation
            </p>
          </div>

          <%= if @errors != [] do %>
            <div class="bg-red-50 border border-red-200 rounded-md p-4">
              <p class="text-sm text-red-800 font-medium">Please fix the following errors:</p>
              <ul class="mt-2 text-sm text-red-700 list-disc list-inside">
                <%= for {field, {msg, _}} <- @errors do %>
                  <li><%= Phoenix.Naming.humanize(field) %>: <%= msg %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trades"}
              class="px-6 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
            >
              Create Trade
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
