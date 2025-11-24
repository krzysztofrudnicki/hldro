# CQRS Implementation Approach

## Overview

Command Query Responsibility Segregation (CQRS) - separacja komend (write) od queries (read) dla lepszej scalability i separation of concerns.

## Why CQRS for This System?

1. **Different scaling needs**: Queries (browsing auctions) >> Commands (placing bids)
2. **Read optimization**: Denormalized read models dla fast queries
3. **Event-driven**: Natural fit z DDD i Event Sourcing
4. **Complexity justification**: Auction system ma złożone read requirements (current price, availability, viewer count)

---

## Architecture Pattern

### Command Side (Write Model)

```
Frontend → Command → Handler → Aggregate → Repository → Database
                                     ↓
                              Domain Events
                                     ↓
                              Event Publisher
```

### Query Side (Read Model)

```
Frontend → Query → Handler → Read Repository → Read Database
```

### Event Projection

```
Domain Events → Event Handlers → Update Read Models
```

---

## Implementation with MediatR

### Command

```csharp
public sealed record CreateAuctionCommand : IRequest<Result<AuctionId>>
{
    public TenantId TenantId { get; init; }
    public string Title { get; init; }
    public string Description { get; init; }
    public decimal StartPrice { get; init; }
    public decimal EndPrice { get; init; }
    public DateTime EndAt { get; init; }
    public List<Guid> ItemIds { get; init; }
}
```

### Command Handler

```csharp
public sealed class CreateAuctionCommandHandler 
    : IRequestHandler<CreateAuctionCommand, Result<AuctionId>>
{
    private readonly IAuctionRepository _repository;
    private readonly IEventPublisher _eventPublisher;
    
    public async Task<Result<AuctionId>> Handle(
        CreateAuctionCommand command,
        CancellationToken cancellationToken)
    {
        // Validation
        // Business logic
        
        // Create aggregate
        var auction = Auction.Create(
            command.TenantId,
            AuctionTitle.From(command.Title),
            AuctionDescription.From(command.Description),
            PriceSchedule.Create(...),
            command.EndAt);
        
        // Add items
        foreach (var itemId in command.ItemIds)
        {
            auction.AddItem(InventoryItemId.From(itemId), displayOrder: /* ... */);
        }
        
        // Save aggregate
        await _repository.SaveAsync(auction);
        
        // Publish domain events
        await _eventPublisher.PublishAsync(auction.DomainEvents);
        auction.ClearDomainEvents();
        
        return Result.Success(auction.Id);
    }
}
```

### Query

```csharp
public sealed record GetActiveAuctionsQuery : IRequest<Result<List<AuctionListDto>>>
{
    public TenantId TenantId { get; init; }
    public int Skip { get; init; } = 0;
    public int Take { get; init; } = 20;
    public string? CategoryId { get; init; }
}
```

### Query Handler

```csharp
public sealed class GetActiveAuctionsQueryHandler 
    : IRequestHandler<GetActiveAuctionsQuery, Result<List<AuctionListDto>>>
{
    private readonly IAuctionReadRepository _readRepository;
    
    public async Task<Result<List<AuctionListDto>>> Handle(
        GetActiveAuctionsQuery query,
        CancellationToken cancellationToken)
    {
        // Query optimized read model
        var auctions = await _readRepository.GetActiveAuctionsAsync(
            query.TenantId,
            query.Skip,
            query.Take,
            query.CategoryId);
        
        // Map to DTO
        var dtos = auctions.Select(a => new AuctionListDto
        {
            AuctionId = a.AuctionId,
            Title = a.Title,
            CurrentPrice = a.CurrentPrice, // Pre-calculated or cached
            ImageUrl = a.MainImageUrl,
            RemainingItems = a.RemainingItems,
            EndAt = a.EndAt
        }).ToList();
        
        return Result.Success(dtos);
    }
}
```

---

## Read Models

### Denormalized for Performance

```csharp
// Read model - flat, denormalized
public class AuctionListReadModel
{
    public Guid AuctionId { get; set; }
    public Guid TenantId { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    
    // Denormalized from Inventory
    public int TotalItems { get; set; }
    public int RemainingItems { get; set; }
    
    // Denormalized from ProductCatalog
    public string MainImageUrl { get; set; }
    public string CategoryName { get; set; }
    
    // Pre-calculated
    public decimal CurrentPrice { get; set; } // Updated periodically
    public DateTime? LastPriceUpdate { get; set; }
    
    public DateTime PublishedOn { get; set; }
    public DateTime EndAt { get; set; }
    public string Status { get; set; }
}
```

### Projection (Event Handler)

```csharp
public class AuctionPublishedEventHandler : IEventHandler<AuctionPublished>
{
    private readonly IAuctionReadRepository _readRepository;
    private readonly IProductCatalogQueryService _catalogService;
    
    public async Task HandleAsync(AuctionPublished @event)
    {
        // Get additional data for denormalization
        var productDetails = await _catalogService.GetProductDetailsAsync(
            @event.ItemIds.First()); // Assuming items of same model
        
        // Create read model
        var readModel = new AuctionListReadModel
        {
            AuctionId = @event.AuctionId,
            TenantId = @event.TenantId,
            Title = @event.Title,
            TotalItems = @event.TotalItemsCount,
            RemainingItems = @event.TotalItemsCount,
            MainImageUrl = productDetails.MainImageUrl,
            CategoryName = productDetails.CategoryName,
            CurrentPrice = @event.StartPrice, // Initial price
            PublishedOn = @event.PublishedOn,
            EndAt = @event.EndAt,
            Status = "Active"
        };
        
        await _readRepository.InsertOrUpdateAsync(readModel);
    }
}
```

---

## Storage Options

### Option 1: Same Database, Different Tables (MVP)

**Command Side**: `Auctions` table (normalized, aggregate structure)
**Query Side**: `AuctionListView` table (denormalized, optimized for queries)

**Pros**: 
- Simple setup
- ACID transactions possible
- Easy to debug

**Cons**:
- Same database resource for read/write
- Less scalability

### Option 2: Separate Databases (Future)

**Command Side**: Azure SQL (ACID, strong consistency)
**Query Side**: Cosmos DB (eventual consistency, fast queries)

**Pros**:
- Independent scaling
- Optimized storage per use case
- Better performance

**Cons**:
- Eventual consistency gap
- More complexity
- Higher cost

**Decision for MVP**: Option 1 (same database)

---

## Consistency Patterns

### Strong Consistency (Command Side)

```csharp
// ACID transaction within aggregate boundary
public async Task<Result> PlaceBidAsync(PlaceBidCommand command)
{
    using var transaction = await _dbContext.Database.BeginTransactionAsync();
    
    try
    {
        var auction = await _repository.GetByIdAsync(command.AuctionId);
        
        var result = auction.AcceptBid(...);
        
        if (result.IsSuccess)
        {
            await _repository.SaveAsync(auction);
            await transaction.CommitAsync();
        }
        
        return result;
    }
    catch
    {
        await transaction.RollbackAsync();
        throw;
    }
}
```

### Eventual Consistency (Query Side)

```csharp
// Read model may be slightly stale
public async Task<AuctionListDto> GetAuctionAsync(AuctionId id)
{
    var readModel = await _readRepository.GetByIdAsync(id);
    
    // Data may be few milliseconds behind command side
    // Acceptable dla query side
    
    return MapToDto(readModel);
}
```

### Consistency Gap Mitigation

**Strategy 1**: Short cache TTL
```csharp
// Cache read model dla 1-2 seconds
_cache.Set(cacheKey, readModel, TimeSpan.FromSeconds(2));
```

**Strategy 2**: Version/timestamp display
```typescript
// Frontend shows "as of X seconds ago"
<span>Price: {price} PLN (updated {secondsAgo}s ago)</span>
```

**Strategy 3**: Optimistic UI updates
```typescript
// Frontend immediately shows bid result, corrects if needed
const [optimisticPrice, setOptimisticPrice] = useState(currentPrice);
```

---

## Event Publishing

### Outbox Pattern (Reliable Delivery)

```csharp
// Save aggregate + events in same transaction
public async Task SaveAsync(Auction auction)
{
    using var transaction = await _dbContext.Database.BeginTransactionAsync();
    
    try
    {
        // Save aggregate
        _dbContext.Auctions.Update(auction);
        
        // Save events to outbox
        foreach (var domainEvent in auction.DomainEvents)
        {
            var outboxMessage = new OutboxMessage
            {
                Id = Guid.NewGuid(),
                EventType = domainEvent.GetType().Name,
                EventData = JsonSerializer.Serialize(domainEvent),
                OccurredOn = domainEvent.OccurredOn,
                ProcessedOn = null
            };
            
            _dbContext.OutboxMessages.Add(outboxMessage);
        }
        
        await _dbContext.SaveChangesAsync();
        await transaction.CommitAsync();
        
        auction.ClearDomainEvents();
    }
    catch
    {
        await transaction.RollbackAsync();
        throw;
    }
}

// Background job publishes events from outbox
public class OutboxProcessor : IHostedService
{
    public async Task ProcessOutboxAsync()
    {
        var unpublishedMessages = await _repository.GetUnpublishedMessagesAsync();
        
        foreach (var message in unpublishedMessages)
        {
            try
            {
                await _serviceBus.PublishAsync(message.EventData);
                
                message.ProcessedOn = DateTime.UtcNow;
                await _repository.SaveAsync(message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish event {EventId}", message.Id);
                // Retry logic...
            }
        }
    }
}
```

---

## API Controller Pattern

```csharp
[ApiController]
[Route("api/auctions")]
public class AuctionsController : ControllerBase
{
    private readonly IMediator _mediator;
    
    // Command endpoint
    [HttpPost]
    public async Task<IActionResult> CreateAuction(
        [FromBody] CreateAuctionRequest request)
    {
        var command = new CreateAuctionCommand
        {
            TenantId = GetCurrentTenantId(),
            Title = request.Title,
            // ... map request to command
        };
        
        var result = await _mediator.Send(command);
        
        return result.IsSuccess 
            ? Ok(new { auctionId = result.Value })
            : BadRequest(new { errors = result.Errors });
    }
    
    // Query endpoint
    [HttpGet]
    public async Task<IActionResult> GetActiveAuctions(
        [FromQuery] int skip = 0,
        [FromQuery] int take = 20)
    {
        var query = new GetActiveAuctionsQuery
        {
            TenantId = GetCurrentTenantId(),
            Skip = skip,
            Take = take
        };
        
        var result = await _mediator.Send(query);
        
        return Ok(result.Value);
    }
}
```

---

## Benefits for This System

1. **Scalability**: Read side can scale independently (most traffic)
2. **Performance**: Denormalized read models = fast queries
3. **Flexibility**: Can optimize query side without affecting command side
4. **Audit Trail**: All commands tracked through events
5. **Real-time**: Events naturally trigger real-time updates

---

## Challenges & Mitigations

**Challenge**: Eventual consistency gap
**Mitigation**: Short TTL caching, optimistic UI, user expectations management

**Challenge**: Read model synchronization complexity
**Mitigation**: Event handlers well-tested, monitoring dla lag

**Challenge**: Increased code complexity
**Mitigation**: Clear separation, good documentation, worth it dla performance gains
