defmodule TraderPocWeb.HomeLive do
  use TraderPocWeb, :live_view

  alias TraderPoc.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Check if user is already logged in
    if session["user_id"] do
      {:ok, socket, layout: false}
    else
      {:ok, assign(socket, name: "", errors: []), layout: false}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-100">
      <div class="max-w-md w-full bg-white rounded-lg shadow-lg p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Trading POC</h1>
        <p class="text-gray-600 mb-8">Real-time trade negotiation platform</p>

        <form action="/session" method="post" class="space-y-4">
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
          <div>
            <label for="name" class="block text-sm font-medium text-gray-700 mb-2">
              Enter your name to continue
            </label>
            <input
              type="text"
              name="name"
              id="name"
              value={@name}
              placeholder="Your name"
              required
              autofocus
              class="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <button
            type="submit"
            class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            Get Started
          </button>
        </form>

        <div class="mt-6 text-center text-sm text-gray-500">
          <p>A proof of concept for real-time trading negotiations</p>
        </div>
      </div>
    </div>
    """
  end
end
