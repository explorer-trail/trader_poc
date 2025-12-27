defmodule TraderPocWeb.NavBar do
  @moduledoc """
  Navigation bar component showing logged-in user and logout option.
  """
  use Phoenix.Component
  use TraderPocWeb, :verified_routes

  @doc """
  Renders a navigation bar with user info and logout button.

  ## Examples

      <.nav_bar current_user={@current_user} />
  """
  attr :current_user, :map, required: true

  def nav_bar(assigns) do
    ~H"""
    <nav class="bg-white shadow-sm border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo/Brand & Navigation -->
          <div class="flex items-center space-x-6">
            <.link navigate={~p"/trades"} class="text-xl font-bold text-gray-900 hover:text-blue-600">
              Trading POC
            </.link>

            <!-- Navigation Links -->
            <div class="hidden md:flex items-center space-x-4">
              <.link
                navigate={~p"/trades"}
                class="text-sm text-white px-3 py-2 rounded-md hover:bg-gray-100"
              >
                My Trades
              </.link>
              <.link
                navigate={~p"/activity"}
                class="text-sm text-gray-700 hover:text-gray-900 px-3 py-2 rounded-md hover:bg-gray-100"
              >
                Activity Dashboard
              </.link>
            </div>
          </div>

          <!-- User Info & Logout -->
          <div class="flex items-center space-x-4">
            <div class="flex items-center space-x-2">
              <div class="h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center">
                <span class="text-white font-semibold text-sm">
                  <%= String.first(@current_user.name) |> String.upcase() %>
                </span>
              </div>
              <span class="text-sm font-medium text-gray-900"><%= @current_user.name %></span>
            </div>

            <.link
              href={~p"/logout"}
              method="delete"
              class="text-sm text-gray-600 hover:text-gray-900 px-3 py-2 rounded-md hover:bg-gray-100 transition-colors"
            >
              Logout
            </.link>
          </div>
        </div>
      </div>
    </nav>
    """
  end
end
