# Integration Patterns Between Bounded Contexts

## Overview

Bounded Contexts komunikują się ze sobą używając różnych integration patterns w zależności od use case.

## Core Principles

1. **No Direct DB Access**: BC nigdy nie accessuje bazy danych innego BC
2. **Event-Driven Communication**: Asynchronous communication via domain events
3. **Anti-Corruption Layer**: Translate external models do własnego domain model
4. **Eventual Consistency**: Cross-BC operations są eventually consistent
5. **Autonomous Services**: Każdy BC może działać niezależnie

---

## Integration Patterns Used

### 1. Event Collaboration (Primary Pattern)

**When**: BC musi reagować na zmiany w innym BC

**How**: 
- BC A publikuje domain event
- BC B subskrybuje event i reaguje

**Example**: Auction → Inventory
```
Auction: BidAccepted event published
    ↓
Service Bus
    ↓
Inventory: Subscribes to BidAccepted
    → Reserves item
    → Publishes ItemReserved event
```

**Implementation**:
```csharp
// Publishing side (Auction Context)
public class Auction : AggregateRoot<AuctionId>
{
    public Result<AcceptedBid> AcceptBid(...)
    {
        // Business logic...
        
        AddDomainEvent(new BidAccepted
        {
            EventId = Guid.NewGuid(),
            OccurredOn = DateTime.UtcNow,
            TenantId = this.TenantId,
            AuctionId = this.Id,
            BidId = bidId,
            ItemId = itemId,
            WinnerId = userId,
            WinningPrice = bidPrice.Amount,
            ReservationId = ReservationId.Create()
        });
        
        return Result.Success(acceptedBid);
    }
}

// Subscribing side (Inventory Context)
public class BidAcceptedEventHandler : IEventHandler<BidAccepted>
{
    public async Task HandleAsync(BidAccepted @event)
    {
        var item = await _repository.GetByIdAsync(@event.ItemId);
        
        item.Reserve(
            @event.ReservationId,
            @event.WinnerId,
            TimeSpan.FromMinutes(15));
        
        await _repository.SaveAsync(item);
        
        // ItemReserved event published
    }
}
```

**Pros**:
- Loose coupling
- Asynchronous
- Scalable

**Cons**:
- Eventual consistency
- More complex debugging

---

### 2. Shared Reference (ID Only)

**When**: BC needs to reference entity from another BC bez coupling

**How**:
- BC A stores ID from BC B
- BC A może query BC B gdy potrzebuje details (read-only)

**Example**: Inventory → Product Catalog
```csharp
public class InventoryItem : AggregateRoot<InventoryItemId>
{
    public ProductModelId ProductModelId { get; private set; } // Reference only
    
    // NO ProductModel details stored here
    // Query ProductCatalog when needed dla display
}
```

**Query for Details** (Read side only):
```csharp
public class InventoryItemReadModel
{
    public Guid InventoryItemId { get; set; }
    public Guid ProductModelId { get; set; }
    
    // Denormalized dla performance (updated via events)
    public string ProductName { get; set; }
    public string ProductImageUrl { get; set; }
}
```

**Pros**:
- No coupling of domain models
- Clear boundaries

**Cons**:
- Need to query for details
- Denormalization dla performance

---

### 3. Command Message

**When**: BC needs to request action from another BC

**How**:
- BC A sends command to BC B
- BC B validates and executes
- BC B publishes result event

**Example**: Bidding → Auction
```csharp
// Bidding Context sends command
public class PlaceBidCommand : ICommand
{
    public BidId BidId { get; init; }
    public AuctionId AuctionId { get; init; }
    public UserId UserId { get; init; }
    public Money BidPrice { get; init; }
    public DateTime PlacedAt { get; init; }
}

// Auction Context handles command
public class PlaceBidCommandHandler : ICommandHandler<PlaceBidCommand>
{
    public async Task<Result> HandleAsync(PlaceBidCommand command)
    {
        var auction = await _repository.GetByIdAsync(command.AuctionId);
        
        var result = auction.AcceptBid(
            command.BidId,
            command.UserId,
            command.BidPrice,
            command.PlacedAt);
        
        if (result.IsSuccess)
        {
            await _repository.SaveAsync(auction);
            // BidAccepted or BidRejected event published
        }
        
        return result;
    }
}
```

**Pros**:
- Clear intent
- Request-response pattern

**Cons**:
- Coupling (sender knows about command structure)
- Synchronous nature (może timeout)

---

### 4. Anti-Corruption Layer

**When**: Integrating with external systems (e.g., e-commerce platforms)

**How**:
- Create adapter that translates external model → domain model
- Isolates domain from external changes

**Example**: Reservation → E-commerce Platform
```csharp
// Domain model (our)
public class CheckoutRequest
{
    public InventoryItemId ItemId { get; set; }
    public Money Price { get; set; }
    public string BuyerEmail { get; set; }
}

// External model (Shopify)
public class ShopifyCheckoutRequest
{
    public string variant_id { get; set; }
    public decimal price { get; set; }
    public string customer_email { get; set; }
}

// Anti-Corruption Layer
public class ShopifyAdapter : IEcommerceIntegration
{
    public async Task<CheckoutSession> CreateCheckoutAsync(CheckoutRequest request)
    {
        // Translate: Our model → Shopify model
        var shopifyRequest = new ShopifyCheckoutRequest
        {
            variant_id = request.ItemId.ToString(),
            price = request.Price.Amount,
            customer_email = request.BuyerEmail
        };
        
        var shopifyResponse = await _httpClient.PostAsync(
            "https://api.shopify.com/checkouts",
            shopifyRequest);
        
        // Translate: Shopify model → Our model
        return new CheckoutSession
        {
            Id = shopifyResponse.id,
            Url = shopifyResponse.web_url,
            ExpiresAt = shopifyResponse.expires_at
        };
    }
}
```

**Pros**:
- Domain protected from external changes
- Can swap external systems

**Cons**:
- Translation overhead
- More code

---

### 5. Read Model Denormalization

**When**: Query side needs data from multiple BCs dla performance

**How**:
- Subscribe to events from multiple BCs
- Build denormalized read model
- Query read model directly

**Example**: Auction List View
```csharp
// Read model combines data from Auction, Inventory, ProductCatalog
public class AuctionListReadModel
{
    public Guid AuctionId { get; set; }
    
    // From Auction
    public string Title { get; set; }
    public decimal CurrentPrice { get; set; }
    public DateTime EndAt { get; set; }
    
    // From Inventory
    public int RemainingItems { get; set; }
    
    // From ProductCatalog
    public string MainImageUrl { get; set; }
    public string CategoryName { get; set; }
}

// Event handlers update read model
public class AuctionPublishedEventHandler : IEventHandler<AuctionPublished>
{
    public async Task HandleAsync(AuctionPublished @event)
    {
        var productDetails = await _catalogQuery.GetProductDetailsAsync(
            @event.ProductModelId);
        
        var readModel = new AuctionListReadModel
        {
            AuctionId = @event.AuctionId,
            Title = @event.Title,
            CurrentPrice = @event.StartPrice,
            EndAt = @event.EndAt,
            RemainingItems = @event.TotalItemsCount,
            MainImageUrl = productDetails.MainImageUrl,
            CategoryName = productDetails.CategoryName
        };
        
        await _readRepository.UpsertAsync(readModel);
    }
}
```

**Pros**:
- Fast queries (single table)
- No joins across BCs

**Cons**:
- Eventual consistency
- Duplicate data
- Must handle all relevant events

---

## Service Bus Configuration

### Topics and Subscriptions

```
Topic: auction-events
├── Subscription: inventory-service
│   └── Filter: EventType = 'BidAccepted' OR EventType = 'AuctionEnded'
├── Subscription: bidding-service
│   └── Filter: EventType = 'PriceDropped' OR EventType = 'BidAccepted'
└── Subscription: reservation-service
    └── Filter: EventType = 'BidAccepted'

Topic: inventory-events
├── Subscription: auction-service
│   └── Filter: EventType = 'ItemWithdrawn' OR EventType = 'ReservationExpired'
└── Subscription: read-model-updater
    └── Filter: (all events)
```

### Message Format

```csharp
public class ServiceBusMessage
{
    public string MessageId { get; set; } // Deduplication
    public string EventType { get; set; } // For routing
    public string EventData { get; set; } // Serialized domain event
    public DateTime Timestamp { get; set; }
    public Dictionary<string, string> Properties { get; set; } // Metadata
}
```

---

## Error Handling

### Retry Policy

```csharp
services.AddServiceBus(options =>
{
    options.RetryPolicy = new ServiceBusRetryPolicy
    {
        MaxRetryAttempts = 3,
        Delay = TimeSpan.FromSeconds(2),
        MaxDelay = TimeSpan.FromSeconds(30),
        BackoffType = BackoffType.Exponential
    };
});
```

### Dead Letter Queue

Events that fail after retries → DLQ:
- Manual inspection required
- Can replay after fix
- Alert operations team

```csharp
public class DeadLetterMonitor : IHostedService
{
    public async Task MonitorDeadLetterQueueAsync()
    {
        var deadLetters = await _serviceBus.GetDeadLetterMessagesAsync();
        
        if (deadLetters.Any())
        {
            _logger.LogError("Found {Count} messages in DLQ", deadLetters.Count);
            await _alerting.SendAlertAsync("Dead letter queue not empty");
        }
    }
}
```

---

## Idempotency

### Event Deduplication

```csharp
public abstract class EventHandler<T> : IEventHandler<T> where T : IDomainEvent
{
    protected readonly IEventProcessingLog _eventLog;
    
    public async Task HandleAsync(T @event)
    {
        // Check if already processed
        if (await _eventLog.HasProcessedAsync(@event.EventId, GetType().Name))
        {
            _logger.LogInformation("Event {EventId} already processed", @event.EventId);
            return;
        }
        
        // Process event
        await HandleEventAsync(@event);
        
        // Mark as processed
        await _eventLog.MarkAsProcessedAsync(@event.EventId, GetType().Name);
    }
    
    protected abstract Task HandleEventAsync(T @event);
}
```

---

## Monitoring Integration

### Distributed Tracing

```csharp
// Propagate correlation ID across boundaries
public class EventPublisher
{
    public async Task PublishAsync(IDomainEvent @event)
    {
        var message = new ServiceBusMessage
        {
            EventData = JsonSerializer.Serialize(@event),
            Properties = new Dictionary<string, string>
            {
                ["CorrelationId"] = Activity.Current?.Id ?? Guid.NewGuid().ToString(),
                ["TenantId"] = @event.TenantId.ToString()
            }
        };
        
        await _serviceBus.SendAsync(message);
    }
}
```

### Application Insights

```csharp
// Track dependencies
_telemetry.TrackDependency(
    dependencyTypeName: "ServiceBus",
    target: "auction-events",
    dependencyName: "PublishEvent",
    data: eventType,
    startTime: startTime,
    duration: duration,
    success: success);
```

---

## Testing Integration

### Integration Tests

```csharp
[Fact]
public async Task BidAccepted_ReservesItem_InInventory()
{
    // Arrange
    var auction = await CreatePublishedAuction();
    var item = await CreateAvailableItem();
    
    // Act
    var bidAccepted = new BidAccepted
    {
        AuctionId = auction.Id,
        ItemId = item.Id,
        WinnerId = UserId.Create(),
        // ...
    };
    
    await _eventPublisher.PublishAsync(bidAccepted);
    
    // Wait for event processing
    await Task.Delay(1000);
    
    // Assert
    var updatedItem = await _inventoryRepository.GetByIdAsync(item.Id);
    Assert.Equal(ItemStatus.Reserved, updatedItem.Status);
}
```

---

## Best Practices

1. **Event Versioning**: Include version in event type name
   ```csharp
   public record BidAcceptedV1 : IDomainEvent { }
   public record BidAcceptedV2 : IDomainEvent { }
   ```

2. **Backward Compatibility**: New fields optional, old consumers still work

3. **Event Size**: Keep events small (< 64KB dla Service Bus)

4. **Timeout**: Set reasonable timeouts dla command processing (5-30 seconds)

5. **Circuit Breaker**: Use circuit breaker dla external integrations

6. **Saga Pattern**: Use dla complex multi-step workflows (future)
