# Inventory Context - Domain Events

## Overview

Domain Events publikowane przez Inventory Context. Te eventy informują inne bounded contexts o zmianach w stanie inventory items.

**Critical**: Auction i Reservation Contexts silnie zależą od tych events dla synchronizacji stanu.

---

## InventoryItem Lifecycle Events

### InventoryItemAdded

**When**: Nowy InventoryItem został dodany do stock

```csharp
public sealed record InventoryItemAdded : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ProductModelId ProductModelId { get; init; }
    public string Condition { get; init; } // New, Unpacked, Display, etc.
    public string? ConditionNotes { get; init; }
    public string? SerialNumber { get; init; }
    public decimal AcquisitionCost { get; init; }
    public string Currency { get; init; }
}
```

**Subscribers**:
- Auction Context: Item może być wystawiony na aukcji
- Read Models: Aktualizują availability counters
- Analytics: Track inventory additions

---

### ItemReserved

**When**: Item został zarezerwowany (dla aukcji lub checkout)

```csharp
public sealed record ItemReserved : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ReservationId ReservationId { get; init; }
    public UserId ReservedBy { get; init; }
    public DateTime ReservedUntil { get; init; }
    public string ReservationSource { get; init; } // "Auction", "Checkout"
}
```

**Subscribers**:
- Auction Context: Rozpoczyna countdown do zakończenia aukcji dla tego item
- Reservation Context: Tworzy Reservation aggregate
- Read Models: Decrementują available count
- Real-time Updates: Notyfikują frontend (item już niedostępny)

**Timing**: Ten event jest **critical** - musi być processed ASAP

---

### ReservationReleased

**When**: Rezerwacja została zwolniona manualnie (np. cancel checkout)

```csharp
public sealed record ReservationReleased : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ReservationId ReservationId { get; init; }
    public string Reason { get; init; } // "CheckoutCancelled", "Manual", etc.
}
```

**Subscribers**:
- Auction Context: Item może być ponownie wystawiony
- Reservation Context: Zamyka Reservation
- Read Models: Incrementują available count

---

### ReservationExpired

**When**: Rezerwacja wygasła (timeout)

```csharp
public sealed record ReservationExpired : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ReservationId ReservationId { get; init; }
    public DateTime ExpiredAt { get; init; }
}
```

**Subscribers**:
- Auction Context: Item wraca do pool, może być re-auctioned
- Reservation Context: Marks reservation as expired
- Read Models: Incrementują available count
- Notification Service: Może notyfikować user o expired reservation

**Processing**: Background job wykrywa expired reservations i publishuje ten event

---

### ItemSold

**When**: Item został sprzedany (po successful checkout)

```csharp
public sealed record ItemSold : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ProductModelId ProductModelId { get; init; }
    public ReservationId ReservationId { get; init; }
    public UserId BuyerId { get; init; }
    public decimal SoldPrice { get; init; }
    public string Currency { get; init; }
    public DateTime SoldOn { get; init; }
}
```

**Subscribers**:
- Auction Context: Kończy aukcję dla tego item
- Analytics: Sales tracking, profit calculation
- Read Models: Decrementują available count permanentnie
- Fulfillment Service (future): Rozpoczyna shipping workflow

**Note**: To jest **terminal state** - item już nie wraca do available

---

### ItemWithdrawn

**When**: Item został wycofany z dostępności (damaged, returned to supplier)

```csharp
public sealed record ItemWithdrawn : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ProductModelId ProductModelId { get; init; }
    public string Reason { get; init; } // Damaged, ReturnedToSupplier, etc.
    public string? Notes { get; init; }
}
```

**Subscribers**:
- Auction Context: Jeśli item był na aukcji, kończy aukcję jako failed
- Read Models: Decrementują available count
- Analytics: Track waste/returns

---

### ItemReturnedToStock

**When**: Wycofany item wrócił do dostępności (rare case)

```csharp
public sealed record ItemReturnedToStock : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public ProductModelId ProductModelId { get; init; }
    public string? Notes { get; init; }
}
```

**Subscribers**:
- Read Models: Incrementują available count
- Auction Context: Item może być ponownie wystawiony

---

### ItemConditionUpdated

**When**: Condition lub ConditionNotes zostały zaktualizowane

```csharp
public sealed record ItemConditionUpdated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public InventoryItemId InventoryItemId { get; init; }
    public string OldCondition { get; init; }
    public string NewCondition { get; init; }
    public string? NewConditionNotes { get; init; }
}
```

**Subscribers**:
- Auction Context: Może wpłynąć na current/future auctions (price adjustment?)
- Read Models: Aktualizują condition filters
- Analytics: Track condition changes

---

## Events Subscribed (from other contexts)

### BidAccepted (from Auction Context)

**Action**: Reserve item for winner

```csharp
public class BidAcceptedEventHandler
{
    public async Task HandleAsync(BidAccepted @event)
    {
        var item = await _repository.GetByIdAsync(@event.InventoryItemId);
        
        item.Reserve(
            @event.ReservationId,
            @event.BuyerId,
            TimeSpan.FromMinutes(15)); // Checkout timeout
        
        await _repository.SaveAsync(item);
        
        // ItemReserved event will be published
    }
}
```

---

### CheckoutCompleted (from Reservation Context)

**Action**: Mark item as sold

```csharp
public class CheckoutCompletedEventHandler
{
    public async Task HandleAsync(CheckoutCompleted @event)
    {
        var item = await _repository.GetByIdAsync(@event.InventoryItemId);
        
        item.MarkAsSold(
            @event.BuyerId,
            Money.From(@event.FinalPrice, @event.Currency));
        
        await _repository.SaveAsync(item);
        
        // ItemSold event will be published
    }
}
```

---

### CheckoutCancelled (from Reservation Context)

**Action**: Release reservation

```csharp
public class CheckoutCancelledEventHandler
{
    public async Task HandleAsync(CheckoutCancelled @event)
    {
        var item = await _repository.GetByIdAsync(@event.InventoryItemId);
        
        item.ReleaseReservation("CheckoutCancelled");
        
        await _repository.SaveAsync(item);
        
        // ReservationReleased event will be published
    }
}
```

---

## Event Processing Patterns

### At-Least-Once Delivery

Wszystkie event handlers MUSZĄ być **idempotent**:

```csharp
public class ItemReservedEventHandler
{
    public async Task HandleAsync(ItemReserved @event)
    {
        // Check if already processed
        var processed = await _eventLog.HasProcessedAsync(
            @event.EventId, 
            nameof(ItemReservedEventHandler));
        
        if (processed)
        {
            _logger.LogInformation("Event {EventId} already processed", @event.EventId);
            return;
        }
        
        // Process event
        await ProcessEventAsync(@event);
        
        // Mark as processed
        await _eventLog.MarkAsProcessedAsync(
            @event.EventId, 
            nameof(ItemReservedEventHandler));
    }
}
```

---

### Event Ordering Guarantees

**Per Aggregate**: Events dla tego samego InventoryItemId zachowują kolejność

**Cross Aggregate**: Brak gwarancji (eventual consistency OK)

---

### Retry Policy

```csharp
var retryPolicy = Policy
    .Handle<Exception>()
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: retryAttempt => 
            TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
        onRetry: (exception, timeSpan, retryCount, context) =>
        {
            _logger.LogWarning(
                "Retry {RetryCount} after {TimeSpan} due to {Exception}",
                retryCount, timeSpan, exception.Message);
        });
```

---

### Dead Letter Queue

Po N failed retries → DLQ:
- Manual investigation required
- Możliwość replay po fix
- Alert dla operations team

---

## Real-time Updates Strategy

### SignalR Integration

Niektóre events powinny być pushed do frontend real-time:

```csharp
public class ItemReservedEventHandler
{
    private readonly IHubContext<AuctionHub> _hubContext;
    
    public async Task HandleAsync(ItemReserved @event)
    {
        // Domain logic...
        
        // Real-time notification
        await _hubContext.Clients
            .Group($"auction-{@event.AuctionId}") // Assuming event has AuctionId
            .SendAsync("ItemReserved", new
            {
                InventoryItemId = @event.InventoryItemId.Value,
                ReservedBy = @event.ReservedBy.Value
            });
    }
}
```

**Events dla real-time push**:
- `ItemReserved` → "Ktoś właśnie kupił!"
- `ReservationExpired` → "Przedmiot znów dostępny!"
- `ItemSold` → "Wyprzedane!"

---

## Monitoring & Alerting

### Key Metrics

- **Event Processing Lag**: Czas między OccurredOn a actual processing
- **Failed Events**: Count events w DLQ
- **Reservation Expiry Rate**: % reservations that expire without sale
- **Concurrent Reservation Attempts**: Detect potential double-booking bugs

### Alerts

- 🚨 Event processing lag > 5 seconds
- 🚨 More than 10 events in DLQ
- 🚨 Optimistic locking failures spike (contention issue)
- ⚠️ Reservation expiry rate > 30%
