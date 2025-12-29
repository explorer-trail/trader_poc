# TraderPoc

A real-time trade negotiation platform built with Phoenix LiveView, demonstrating real-time communication, presence tracking, and scheduled job processing with Oban.

## Features

### Real-time Trade Negotiation
- **Live Messaging**: Real-time chat between buyers and sellers with typing indicators
- **Trade Amendments**: Sellers can propose changes to price, quantity, and description
- **Version History**: Complete audit trail of all trade modifications
- **Presence Tracking**: See who's currently online in each trade room
- **Activity Timeline**: Visual timeline of all trade actions

### Auto-Expiring Trade Offers (Oban Scheduling Demo)
- **Automatic Expiration**: Trades automatically expire after a configurable time period (default: 30 minutes)
- **Real-time Countdown**: Live countdown timer shows time remaining before expiration
- **Smart Cancellation**: Scheduled expiry jobs are automatically cancelled when trades are accepted or rejected
- **Visual Feedback**: Timer changes color when less than 5 minutes remain
- **PubSub Notifications**: All participants are notified when a trade expires

### Global Activity Dashboard
- **Real-time Overview**: See all active trades across the platform
- **Live Presence**: Track which trades have active participants
- **Online Counts**: Monitor total users currently in negotiations

## Technology Stack

- **Phoenix LiveView**: Real-time, server-rendered UI without JavaScript frameworks
- **Oban**: Reliable job processing for scheduled trade expiration
- **Phoenix PubSub**: Real-time event broadcasting
- **Phoenix Presence**: Distributed presence tracking
- **PostgreSQL**: Persistent data storage
- **Tailwind CSS**: Utility-first styling

## Getting Started

### Prerequisites
- Elixir 1.15 or later
- PostgreSQL database
- Node.js (for asset compilation)

### Setup

1. Install dependencies:
   ```bash
   mix setup
   ```

2. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

   Or start it inside IEx:
   ```bash
   iex -S mix phx.server
   ```

3. Visit [`localhost:4000`](http://localhost:4000) from your browser

### Creating a Trade with Custom Expiry

For testing the auto-expiry feature, you can create trades with shorter expiration times:

```elixir
# In iex -S mix phx.server
TraderPoc.Trading.create_trade(%{
  "title" => "Test Trade",
  "description" => "Quick expiry test",
  "price" => 100,
  "quantity" => 5,
  "buyer_name" => "Test Buyer",
  "expiry_minutes" => 2  # Expires in 2 minutes instead of default 30
}, seller_id)
```

## How It Works

1. **Create a Trade**: Seller creates a trade offer with title, description, price, and quantity
2. **Share Invitation**: Seller shares the generated invitation code with the buyer
3. **Negotiate**: Both parties can chat, amend terms, and track changes in real-time
4. **Accept/Reject**: Buyer can accept or reject the final offer
5. **Auto-Expire**: If no action is taken, the trade automatically expires after 30 minutes

### Oban Job Scheduling

When a trade is created:
1. An expiration timestamp is calculated (30 minutes from creation)
2. An Oban job is scheduled to run at that timestamp
3. The job ID is stored with the trade for potential cancellation
4. If the trade is accepted or rejected, the scheduled job is cancelled
5. If the job runs, it updates the trade status to "expired" and notifies all participants

## Database Schema

Key tables:
- `trades`: Main trade records with expiration tracking
- `trade_versions`: Version history of trade modifications
- `trade_actions`: Audit log of all actions
- `messages`: Chat messages between parties
- `oban_jobs`: Scheduled jobs for trade expiration

## Production Deployment

Ready to run in production? Please [check the Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn More

* Official Phoenix website: https://www.phoenixframework.org/
* Phoenix Guides: https://hexdocs.pm/phoenix/overview.html
* Phoenix Docs: https://hexdocs.pm/phoenix
* Oban Documentation: https://hexdocs.pm/oban
* Forum: https://elixirforum.com/c/phoenix-forum
