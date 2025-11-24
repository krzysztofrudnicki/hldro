# Auction Context - Domain Events

## Overview

Auction Context publikuje kluczowe events dotyczące lifecycle aukcji i bid acceptance. Te events są fundamentalne dla real-time updates w UI i koordynacji z innymi bounded contexts.

---

## Auction Lifecycle Events

### AuctionCreated

**When**: Nowa aukcja została utworzona w stanie Draft

```csharp
public sealed record AuctionCreated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public string Title { get; init; }
    public string Description { get; init; }
    public decimal StartPrice { get; init; }
    public decimal EndPrice { get; init; }
    public string Currency { get; init; }
    public DateTime EndAt { get; init; }
    public DateTime? PublishAt { get; init; }
}
```

**Subscribers**:
- Read Models: Przygotowują draft view dla sprzedawcy
- Analytics: Track auction creation rate

---

### AuctionItemAdded

**When**: InventoryItem został dodany do aukcji

```csharp
public sealed record AuctionItemAdded : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public InventoryItemId ItemId { get; init; }
    public int DisplayOrder { get; init; }
}
```

**Subscribers**:
- Read Models: Aktualizują item count

---

### AuctionItemRemoved

**When**: InventoryItem został usunięty z aukcji (przed publikacją)

```csharp
public sealed record AuctionItemRemoved : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public InventoryItemId ItemId { get; init; }
}
```

---

### AuctionScheduled

**When**: Aukcja została zaplanowana na przyszły czas

```csharp
public sealed record AuctionScheduled : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public DateTime PublishAt { get; init; }
}
```

**Subscribers**:
- Scheduler Service: Ustawi timer do publikacji aukcji
- Read Models: Pokazują "upcoming auctions"

---

### AuctionPublished

**When**: Aukcja została opublikowana i jest teraz visible/active

```csharp
public sealed record AuctionPublished : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public DateTime PublishedOn { get; init; }
    public DateTime EndAt { get; init; }
    public decimal StartPrice { get; init; }
    public decimal EndPrice { get; init; }
    public string Currency { get; init; }
    public int TotalItemsCount { get; init; }
    public List<Guid> ItemIds { get; init; }
}
```

**Subscribers**:
- **Inventory Context**: Rezerwuje wszystkie items w aukcji (ItemReserved events)
- Bidding Context: Rozpoczyna listening dla bids
- Read Models: Aktualizują "live auctions" view
- Notification Service: Może notyfikować subscribed users
- SignalR Hub: Rozpoczyna broadcasting price updates

**Critical**: To jest moment gdy items muszą być reserved w Inventory!

---

### PriceDropped

**When**: Periodic event informujący o spadku ceny (dla real-time updates)

```csharp
public sealed record PriceDropped : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public decimal CurrentPrice { get; init; }
    public string Currency { get; init; }
    public int DropsRemaining { get; init; }
}
```

**Subscribers**:
- SignalR Hub: Pushuje current price do wszystkich connected clients
- Read Models: Cache current price (short TTL)

**Publishing Strategy**:
- Background job publishuje co N sekund (np. 5-10 seconds)
- Alternative: Publish on-demand gdy frontend queries price
- For MVP: Background job z Azure Function Time Trigger

**Note**: Ten event jest **informational only** - nie zmienia stanu, tylko notyfikuje o calculated price

---

## Bid Events

### BidPlaced

**When**: Użytkownik złożył bid (before validation)

```csharp
public sealed record BidPlaced : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public BidId BidId { get; init; }
    public UserId UserId { get; init; }
    public decimal BidPrice { get; init; }
    public string Currency { get; init; }
    public DateTime PlacedAt { get; init; }
}
```

**Subscribers**:
- Bidding Context: Records bid attempt
- Analytics: Track bid patterns
- Audit Log: Compliance

**Note**: To NIE znaczy że bid był accepted - to tylko informacja że został placed

---

### BidAccepted

**When**: Bid został zaakceptowany i item sprzedany

```csharp
public sealed record BidAccepted : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public BidId BidId { get; init; }
    public InventoryItemId ItemId { get; init; }
    public UserId WinnerId { get; init; }
    public decimal WinningPrice { get; init; }
    public string Currency { get; init; }
    public DateTime AcceptedAt { get; init; }
    public ReservationId ReservationId { get; init; } // For checkout
}
```

**Subscribers**:
- **Inventory Context**: Marks item as reserved for checkout (ItemReserved)
- **Reservation Context**: Creates Reservation aggregate, starts checkout flow
- Bidding Context: Records successful bid
- SignalR Hub: Notyfikuje innych viewers że item został kupiony
- Analytics: Sales tracking

**Critical Path**: Musi być processed szybko dla smooth checkout experience

---

### BidRejected

**When**: Bid został odrzucony (invalid price, no availability, etc.)

```csharp
public sealed record BidRejected : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public BidId BidId { get; init; }
    public UserId UserId { get; init; }
    public decimal BidPrice { get; init; }
    public string Currency { get; init; }
    public string RejectionReason { get; init; }
    public DateTime RejectedAt { get; init; }
}
```

**Subscribers**:
- Bidding Context: Records rejection (may retry?)
- SignalR Hub: Notyfikuje user o rejection
- Analytics: Track rejection patterns (może wskazywać na problems)

**Common Rejection Reasons**:
- "Price outside valid range"
- "Item no longer available"
- "Auction has ended"
- "Concurrent bid conflict"

---

### ItemSoldInAuction

**When**: Item w aukcji został sprzedany (po BidAccepted)

```csharp
public sealed record ItemSoldInAuction : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public InventoryItemId ItemId { get; init; }
    public UserId BuyerId { get; init; }
    public decimal SoldPrice { get; init; }
    public string Currency { get; init; }
    public int RemainingItemsInAuction { get; init; }
}
```

**Subscribers**:
- Read Models: Aktualizują sold count, remaining items
- SignalR Hub: Updates UI (item sold, X remaining)
- Analytics: Real-time sales tracking

---

### AuctionEnded

**When**: Aukcja zakończyła się (wszystkie items sprzedane LUB EndAt reached)

```csharp
public sealed record AuctionEnded : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public DateTime EndedAt { get; init; }
    public string EndReason { get; init; } // "AllItemsSold", "TimeExpired", "Manual"
    public int TotalItemsSold { get; init; }
    public int TotalItemsUnsold { get; init; }
    public decimal TotalRevenue { get; init; }
    public string Currency { get; init; }
}
```

**Subscribers**:
- Inventory Context: Releases unsold items (ReservationReleased)
- Bidding Context: Closes bidding
- SignalR Hub: Notyfikuje users że auction ended
- Analytics: Auction performance metrics
- Read Models: Archives auction

**Important**: Unsold items muszą być released back to Available w Inventory!

---

### AuctionCancelled

**When**: Aukcja została manualnie anulowana (przez sprzedawcę lub system)

```csharp
public sealed record AuctionCancelled : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public AuctionId AuctionId { get; init; }
    public DateTime CancelledAt { get; init; }
    public string Reason { get; init; }
    public int ItemsSoldBeforeCancellation { get; init; }
}
```

**Subscribers**:
- Inventory Context: Releases ALL items (including sold - może wymagać refund)
- Bidding Context: Cancels all pending bids
- Reservation Context: Cancels active reservations (refund?)
- SignalR Hub: Notyfikuje users
- Analytics: Track cancellation reasons

**Note**: Cancellation może być skomplikowana jeśli items były już sold - może wymagać refund logic

---

## Events Subscribed (from other contexts)

### ItemWithdrawn (from Inventory)

**Action**: Jeśli item jest w active auction, może wymagać end/cancellation

```csharp
public class ItemWithdrawnEventHandler
{
    public async Task HandleAsync(ItemWithdrawn @event)
    {
        var auctions = await _repository.FindActiveAuctionsWithItemAsync(@event.InventoryItemId);
        
        foreach (var auction in auctions)
        {
            // If it's the last item, end auction
            if (auction.RemainingItemsCount == 1)
            {
                auction.End();
            }
            else
            {
                // Remove item from slots, continue with others
                auction.RemoveItem(@event.InventoryItemId);
            }
            
            await _repository.SaveAsync(auction);
        }
    }
}
```

---

### ReservationExpired (from Inventory)

**Action**: Item może wrócić do auction pool

```csharp
public class ReservationExpiredEventHandler
{
    public async Task HandleAsync(ReservationExpired @event)
    {
        // For MVP: Items nie wracają do auction po expire
        // Future: Może być re-auctioned
        
        _logger.LogInformation(
            "Item {ItemId} reservation expired, not returning to auction",
            @event.InventoryItemId);
    }
}
```

---

## Real-time Event Broadcasting Strategy

### WebSocket/SignalR Groups

Clients subscribe to auction-specific groups:

```csharp
public class AuctionHub : Hub
{
    public async Task JoinAuction(Guid auctionId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"auction-{auctionId}");
    }
    
    public async Task LeaveAuction(Guid auctionId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"auction-{auctionId}");
    }
}
```

### Event → SignalR Mapping

```csharp
public class PriceDroppedEventHandler
{
    private readonly IHubContext<AuctionHub> _hubContext;
    
    public async Task HandleAsync(PriceDropped @event)
    {
        await _hubContext.Clients
            .Group($"auction-{@event.AuctionId}")
            .SendAsync("PriceUpdated", new
            {
                AuctionId = @event.AuctionId,
                CurrentPrice = @event.CurrentPrice,
                Currency = @event.Currency,
                DropsRemaining = @event.DropsRemaining
            });
    }
}
```

**Events for real-time push**:
- `PriceDropped` → Update price display
- `BidAccepted` → Show "Item sold!" animation
- `ItemSoldInAuction` → Update remaining count
- `AuctionEnded` → Show "Auction ended" message

---

## Event Processing Guarantees

### Idempotency
All handlers MUST be idempotent using event deduplication:

```csharp
if (await _eventLog.HasProcessedAsync(@event.EventId, handlerName))
    return;

// Process...

await _eventLog.MarkAsProcessedAsync(@event.EventId, handlerName);
```

### Ordering
- **Per Auction**: Events for same AuctionId maintain order
- **Cross Auction**: No ordering guarantee (OK for MVP)

### Retry & DLQ
- 3 retries with exponential backoff
- After failures → Dead Letter Queue
- Alert operations team

---

## Monitoring

### Key Metrics
- **Event Processing Lag**: OccurredOn → ActualProcessing time
- **Bid Acceptance Rate**: Accepted / Total Bids
- **Bid Rejection Reasons**: Distribution of rejection reasons
- **Real-time Latency**: Event → SignalR push time

### Alerts
- 🚨 Event lag > 2 seconds (critical for bid processing)
- 🚨 Bid rejection rate > 50% (może wskazywać na price calculation bug)
- ⚠️ SignalR push latency > 1 second
