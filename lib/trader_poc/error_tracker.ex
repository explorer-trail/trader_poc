defmodule TraderPoc.ErrorTracker do
  @moduledoc """
  Tracks and logs application errors with context for debugging.

  In production, this would integrate with services like Sentry, AppSignal, or Rollbar.
  For this POC, we log to console and could optionally store in database.
  """

  require Logger

  @doc """
  Tracks an error with context information.

  ## Examples

      ErrorTracker.track_error(
        error,
        __STACKTRACE__,
        %{user_id: 123, trade_id: 456, action: "send_message"}
      )
  """
  def track_error(error, stacktrace, context \\ %{}) do
    error_info = %{
      type: error.__struct__,
      message: Exception.message(error),
      stacktrace: Exception.format_stacktrace(stacktrace),
      context: context,
      timestamp: DateTime.utc_now(),
      node: Node.self()
    }

    # Log to console
    Logger.error("""
    ┌─────────────────────────────────────────────────────────────────
    │ APPLICATION ERROR
    ├─────────────────────────────────────────────────────────────────
    │ Type:      #{inspect(error_info.type)}
    │ Message:   #{error_info.message}
    │ Time:      #{error_info.timestamp}
    │ Node:      #{error_info.node}
    │ Context:   #{inspect(context, pretty: true)}
    ├─────────────────────────────────────────────────────────────────
    │ STACKTRACE:
    │ #{error_info.stacktrace}
    └─────────────────────────────────────────────────────────────────
    """)

    # In production, send to error tracking service:
    # Sentry.capture_exception(error, extra: context)
    # or
    # AppSignal.send_error(error, stacktrace, context)

    # Could also store in database for admin dashboard
    # store_in_database(error_info)

    :ok
  end

  @doc """
  Tracks a LiveView crash with user and socket context.
  """
  def track_liveview_error(error, stacktrace, socket) do
    context = %{
      user_id: get_in(socket.assigns, [:current_user, :id]),
      user_name: get_in(socket.assigns, [:current_user, :name]),
      trade_id: get_in(socket.assigns, [:trade, :id]),
      trade_code: get_in(socket.assigns, [:trade, :invitation_code]),
      role: socket.assigns[:role],
      connected?: Phoenix.LiveView.connected?(socket)
    }

    track_error(error, stacktrace, context)
  end

  @doc """
  Logs a crash event for monitoring/alerting.

  This can be used to trigger alerts if crash rate exceeds threshold.
  """
  def log_crash_event(module, function, reason) do
    Logger.warning("Process crash detected",
      module: module,
      function: function,
      reason: inspect(reason),
      timestamp: DateTime.utc_now()
    )

    # In production, increment metrics:
    # :telemetry.execute([:trader_poc, :crash], %{count: 1}, %{
    #   module: module,
    #   function: function
    # })
  end

  @doc """
  Gets a user-friendly error message for common errors.
  """
  def user_friendly_message(error) do
    case error do
      %Ecto.NoResultsError{} ->
        "The requested item could not be found."

      %DBConnection.ConnectionError{} ->
        "We're experiencing connectivity issues. Please try again in a moment."

      %Postgrex.Error{postgres: %{code: :serialization_failure}} ->
        "This action conflicted with another change. Please refresh and try again."

      %ArgumentError{message: msg} when is_binary(msg) ->
        if String.contains?(msg, "nil") do
          "Some required information is missing. Please refresh the page."
        else
          "Something unexpected happened. We've been notified and are looking into it."
        end

      _ ->
        "Something unexpected happened. We've been notified and are looking into it."
    end
  end

  # Private helper to store errors in database (optional)
  # defp store_in_database(error_info) do
  #   %ErrorLog{}
  #   |> ErrorLog.changeset(%{
  #     error_type: to_string(error_info.type),
  #     message: error_info.message,
  #     stacktrace: error_info.stacktrace,
  #     context: error_info.context,
  #     occurred_at: error_info.timestamp
  #   })
  #   |> Repo.insert()
  # end
end
