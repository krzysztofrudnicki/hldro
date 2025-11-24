# Reservation & Checkout Context

## Overview

Zarządzanie rezerwacją wygranych items i przekazywanie do checkout flow w external e-commerce platform sprzedawcy.

## Responsibility

1. **Reservation Management**: Tymczasowe zablokowanie wygranego item dla buyer
2. **Checkout Orchestration**: Przekazanie do e-commerce platform z rabatem
3. **Timeout Handling**: Release reservation jeśli checkout nie completed
4. **Integration**: Anti-corruption layer dla różnych e-commerce platforms

## Business Rules

1. **Reservation Timeout**: 15 minut na completed checkout
2. **One Reservation Per Win**: Jeden win = jedna reservation
3. **Immutable Reservation**: Nie można modify po creation
4. **Integration Per Tenant**: Każdy tenant może mieć różną e-commerce platform

---

## Domain Model

### Reservation (Aggregate Root)

```csharp
public sealed class Reservation : AggregateRoot<ReservationId>
{
    public TenantId TenantId { get; private set; }
    public AuctionId AuctionId { get; private set; }
    public BidId BidId { get; private set; }
    public InventoryItemId ItemId { get; private set; }
    public UserId BuyerId { get; private set; }
    
    public Money WinningPrice { get; private set; }
    public DateTime CreatedAt { get; private set; }
    public DateTime ExpiresAt { get; private set; }
    
    public ReservationStatus Status { get; private set; }
    public DateTime? CompletedAt { get; private set; }
    public DateTime? CancelledAt { get; private set; }
    public string? CancellationReason { get; private set; }
    
    // External checkout reference
    public ExternalCheckoutId? ExternalCheckoutId { get; private set; }
    
    // Factory
    public static Reservation Create(
        TenantId tenantId,
        AuctionId auctionId,
        BidId bidId,
        InventoryItemId itemId,
        UserId buyerId,
        Money winningPrice,
        TimeSpan timeout);
    
    // Commands
    public void LinkExternalCheckout(ExternalCheckoutId checkoutId);
    
    public void MarkAsCompleted();
    
    public void Cancel(string reason);
    
    public void MarkAsExpired();
    
    // Queries
    public bool IsActive() => Status == ReservationStatus.Active;
    public bool IsExpired() => DateTime.UtcNow > ExpiresAt && IsActive();
}
```

---

### Value Objects

#### ExternalCheckoutId

```csharp
public sealed class ExternalCheckoutId : ValueObject
{
    public string Platform { get; } // "Shopify", "WooCommerce", etc.
    public string CheckoutId { get; } // Platform-specific ID
    
    private ExternalCheckoutId(string platform, string checkoutId)
    {
        Platform = platform;
        CheckoutId = checkoutId;
    }
    
    public static ExternalCheckoutId From(string platform, string checkoutId);
}
```

---

### Enums

#### ReservationStatus

```csharp
public enum ReservationStatus
{
    Active,      // Reserved, waiting for checkout
    Completed,   // Checkout successfully completed
    Cancelled,   // Manually cancelled
    Expired      // Timeout reached without completion
}
```

---

## Application Services

### CheckoutOrchestrationService

```csharp
public sealed class CheckoutOrchestrationService
{
    private readonly IReservationRepository _repository;
    private readonly IEcommerceIntegrationFactory _integrationFactory;
    private readonly ICommandBus _commandBus;
    
    public async Task<CheckoutResult> InitiateCheckoutAsync(ReservationId reservationId)
    {
        var reservation = await _repository.GetByIdAsync(reservationId);
        
        // Get tenant-specific e-commerce integration
        var integration = await _integrationFactory.GetIntegrationAsync(
            reservation.TenantId);
        
        // Create checkout session in external platform
        var checkoutSession = await integration.CreateCheckoutSessionAsync(new
        {
            ItemId = reservation.ItemId,
            Price = reservation.WinningPrice,
            BuyerEmail = await GetBuyerEmailAsync(reservation.BuyerId),
            CallbackUrl = $"https://api.platform.com/checkout/callback/{reservationId}"
        });
        
        // Link to reservation
        reservation.LinkExternalCheckout(
            ExternalCheckoutId.From(integration.PlatformName, checkoutSession.Id));
        
        await _repository.SaveAsync(reservation);
        
        return new CheckoutResult
        {
            CheckoutUrl = checkoutSession.Url,
            ExpiresAt = reservation.ExpiresAt
        };
    }
    
    public async Task HandleCheckoutCompletedAsync(
        ReservationId reservationId,
        string externalOrderId)
    {
        var reservation = await _repository.GetByIdAsync(reservationId);
        
        reservation.MarkAsCompleted();
        await _repository.SaveAsync(reservation);
        
        // Publish event
        // CheckoutCompleted event → Inventory marks item as Sold
    }
}
```

---

### ReservationTimeoutService (Background Job)

```csharp
public class ReservationTimeoutService : IHostedService
{
    private Timer _timer;
    
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _timer = new Timer(
            ProcessExpiredReservations,
            null,
            TimeSpan.Zero,
            TimeSpan.FromMinutes(1)); // Check every minute
        
        return Task.CompletedTask;
    }
    
    private async void ProcessExpiredReservations(object state)
    {
        var expiredReservations = await _repository.GetExpiredReservationsAsync();
        
        foreach (var reservation in expiredReservations)
        {
            reservation.MarkAsExpired();
            await _repository.SaveAsync(reservation);
            
            // Publish ReservationExpired event
            // → Inventory releases item
        }
    }
}
```

---

## Integration Patterns

### Anti-Corruption Layer

```csharp
public interface IEcommerceIntegration
{
    string PlatformName { get; }
    
    Task<CheckoutSession> CreateCheckoutSessionAsync(CheckoutRequest request);
    Task<Order> GetOrderAsync(string orderId);
    Task CancelOrderAsync(string orderId);
}

// Shopify implementation
public class ShopifyIntegration : IEcommerceIntegration
{
    public string PlatformName => "Shopify";
    
    public async Task<CheckoutSession> CreateCheckoutSessionAsync(
        CheckoutRequest request)
    {
        // Translate our domain model → Shopify API
        var shopifyCheckout = new
        {
            line_items = new[]
            {
                new
                {
                    variant_id = request.ItemId.ToString(),
                    quantity = 1,
                    price = request.Price.Amount
                }
            },
            email = request.BuyerEmail
        };
        
        var response = await _httpClient.PostAsync(
            "https://api.shopify.com/checkouts",
            shopifyCheckout);
        
        // Translate Shopify response → our domain model
        return new CheckoutSession
        {
            Id = response.Id,
            Url = response.WebUrl
        };
    }
}
```

---

## Domain Events

### ReservationCreated

```csharp
public sealed record ReservationCreated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ReservationId ReservationId { get; init; }
    public InventoryItemId ItemId { get; init; }
    public UserId BuyerId { get; init; }
    public decimal WinningPrice { get; init; }
    public DateTime ExpiresAt { get; init; }
}
```

### CheckoutCompleted

```csharp
public sealed record CheckoutCompleted : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ReservationId ReservationId { get; init; }
    public InventoryItemId ItemId { get; init; }
    public UserId BuyerId { get; init; }
    public decimal FinalPrice { get; init; }
    public string ExternalOrderId { get; init; }
}
```

**Subscribers**:
- Inventory Context: Mark item as Sold

### ReservationExpired

```csharp
public sealed record ReservationExpired : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ReservationId ReservationId { get; init; }
    public InventoryItemId ItemId { get; init; }
}
```

**Subscribers**:
- Inventory Context: Release item back to Available

---

## Event Handlers

### BidAccepted Handler (from Auction Context)

```csharp
public class BidAcceptedEventHandler : IEventHandler<BidAccepted>
{
    public async Task HandleAsync(BidAccepted @event)
    {
        // Create reservation
        var reservation = Reservation.Create(
            @event.TenantId,
            @event.AuctionId,
            @event.BidId,
            @event.ItemId,
            @event.WinnerId,
            Money.From(@event.WinningPrice, @event.Currency),
            timeout: TimeSpan.FromMinutes(15));
        
        await _repository.SaveAsync(reservation);
        
        // ReservationCreated event published
        // → Triggers checkout flow
    }
}
```

---

## Technical Considerations

### Webhook Handling (from E-commerce Platform)

```csharp
[ApiController]
[Route("api/checkout/webhook")]
public class CheckoutWebhookController : ControllerBase
{
    [HttpPost("shopify")]
    public async Task<IActionResult> ShopifyWebhook([FromBody] ShopifyWebhookPayload payload)
    {
        // Verify webhook signature
        if (!_webhookVerifier.Verify(Request.Headers, payload))
            return Unauthorized();
        
        // Extract reservation ID from metadata
        var reservationId = ReservationId.From(payload.Note);
        
        // Handle completed order
        await _checkoutService.HandleCheckoutCompletedAsync(
            reservationId,
            payload.OrderId);
        
        return Ok();
    }
}
```

### Timeout Strategy

**Option 1**: Background job polls database (current MVP approach)
**Option 2**: Azure Function with time trigger
**Option 3**: Delayed message in Service Bus (more scalable)

---

## Future Enhancements

- **Payment Handling**: Jeśli mamy own payment processing
- **Refund Logic**: If reservation cancelled after payment
- **Multiple Items Checkout**: Bundle multiple wins
