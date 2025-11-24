# Auction Price Calculation Mechanism

## Overview

Kluczowa decision: **On-the-fly price calculation** bez persystowania intermediate prices. Cena jest kalkulowana w czasie rzeczywistym based on elapsed time od publikacji aukcji.

## Why On-the-fly?

### Advantages ✅
- **No storage overhead**: Nie zapisujemy każdej ceny co sekundę
- **No update jobs**: Brak background jobs do update prices
- **Deterministic**: Ta sama formuła zawsze daje ten sam wynik
- **Easy to test**: Pure function, łatwe unit testy
- **Scalable**: Każdy node może kalkulować niezależnie
- **Audit trail**: Możemy zawsze "odtworzyć" cenę w dowolnym momencie

### Trade-offs ⚠️
- **Must recalculate on every query**: CPU overhead (minimalny - < 1ms)
- **Clock sync critical**: Wszystkie serwery muszą mieć zsynchronizowany czas (NTP)
- **Network latency**: Musimy tolerować różnice między client/server time

### Decision
Dla MVP **on-the-fly calculation jest optymalna** - prostota > micro-optimization.

---

## Price Calculation Formula

### Core Formula

```
CurrentPrice = StartPrice - (ElapsedIntervals × DropAmount)

Where:
- ElapsedIntervals = floor(ElapsedSeconds / IntervalInSeconds)
- DropAmount = per-interval drop (absolute or percentage)
- Result is bounded: max(CalculatedPrice, EndPrice)
```

### Example

```
Auction Setup:
- StartPrice: 1000 PLN
- EndPrice: 500 PLN
- Drop Rate: 10 PLN every 30 seconds
- Duration: 1 hour (3600 seconds)

At T+0 (publish):
  ElapsedSeconds = 0
  CurrentPrice = 1000 PLN

At T+30 seconds:
  ElapsedIntervals = floor(30 / 30) = 1
  CurrentPrice = 1000 - (1 × 10) = 990 PLN

At T+90 seconds:
  ElapsedIntervals = floor(90 / 30) = 3
  CurrentPrice = 1000 - (3 × 10) = 970 PLN

At T+3600 seconds (end):
  ElapsedIntervals = floor(3600 / 30) = 120
  CalculatedPrice = 1000 - (120 × 10) = -200 PLN
  CurrentPrice = max(-200, 500) = 500 PLN (bounded)
```

---

## Implementation

### PriceSchedule Value Object

```csharp
public sealed class PriceSchedule : ValueObject
{
    public Money StartPrice { get; }
    public Money EndPrice { get; }
    public PriceDropRate DropRate { get; }
    public TimeSpan Duration { get; }
    
    public Money CalculatePriceAt(DateTime startTime, DateTime currentTime)
    {
        // Edge case: before start
        var elapsed = currentTime - startTime;
        if (elapsed < TimeSpan.Zero)
            return StartPrice;
        
        // Edge case: after duration
        if (elapsed >= Duration)
            return EndPrice;
        
        // Calculate intervals elapsed
        var totalSeconds = (int)elapsed.TotalSeconds;
        var intervalsElapsed = totalSeconds / DropRate.IntervalInSeconds;
        
        // Calculate drop amount
        Money dropAmount;
        if (DropRate.DropType == PriceDropType.Absolute)
        {
            // Simple: DropValue × intervals
            dropAmount = Money.From(
                DropRate.DropValue * intervalsElapsed,
                StartPrice.Currency);
        }
        else // Percentage
        {
            // For percentage: może być linear lub compounding
            // MVP: Linear dla simplicity
            var totalPercentageDrop = DropRate.DropValue * intervalsElapsed;
            var dropAmountValue = StartPrice.Amount * (totalPercentageDrop / 100m);
            dropAmount = Money.From(dropAmountValue, StartPrice.Currency);
        }
        
        // Calculate current price
        var calculatedPrice = StartPrice.Subtract(dropAmount);
        
        // Bound by EndPrice
        if (calculatedPrice.Amount < EndPrice.Amount)
            return EndPrice;
        
        return calculatedPrice;
    }
}
```

### Usage in Aggregate

```csharp
public sealed class Auction : AggregateRoot<AuctionId>
{
    public Money CalculateCurrentPrice(DateTime atTime)
    {
        if (Status != AuctionStatus.Published && Status != AuctionStatus.Active)
            throw new InvalidOperationException(
                "Cannot calculate price for non-published auction");
        
        if (PublishedOn == null)
            throw new InvalidOperationException(
                "Cannot calculate price - auction not yet published");
        
        return PriceSchedule.CalculatePriceAt(PublishedOn.Value, atTime);
    }
}
```

---

## Time Synchronization

### Critical Requirement: UTC Everywhere

```csharp
// ❌ WRONG - Local time
var currentPrice = auction.CalculateCurrentPrice(DateTime.Now);

// ✅ CORRECT - UTC
var currentPrice = auction.CalculateCurrentPrice(DateTime.UtcNow);
```

**All timestamps MUST be UTC**:
- `PublishedOn`: UTC
- `EndAt`: UTC
- `BidPlacedAt`: UTC
- `DateTime.UtcNow` for current time

### Server Time Synchronization

**Azure VMs** automatically sync with Azure NTP servers:
- Time drift: < 1 second
- Sufficient dla MVP

**Monitoring**: Track clock drift between servers (alert if > 1 sec)

---

## Network Latency Handling

### Problem

```
Scenario:
1. Client sees price: 950 PLN at T+100
2. Network latency: 500ms
3. Server receives bid at T+100.5
4. Server calculates price: 945 PLN (next interval)
5. Bid rejected: "Price mismatch"
```

### Solution: Tolerance Window

```csharp
public sealed class BidValidationService
{
    public BidValidationResult Validate(
        Auction auction,
        Money bidPrice,
        DateTime bidPlacedAt)
    {
        // Calculate price with tolerance
        var tolerance = TimeSpan.FromSeconds(2); // 2 second window
        
        var priceAtBidTime = auction.CalculateCurrentPrice(bidPlacedAt);
        var priceBeforeTolerance = auction.CalculateCurrentPrice(
            bidPlacedAt - tolerance);
        var priceAfterTolerance = auction.CalculateCurrentPrice(
            bidPlacedAt + tolerance);
        
        var minAcceptablePrice = Math.Min(
            priceAtBidTime.Amount,
            Math.Min(priceBeforeTolerance.Amount, priceAfterTolerance.Amount));
        
        var maxAcceptablePrice = Math.Max(
            priceAtBidTime.Amount,
            Math.Max(priceBeforeTolerance.Amount, priceAfterTolerance.Amount));
        
        if (bidPrice.Amount < minAcceptablePrice || 
            bidPrice.Amount > maxAcceptablePrice)
        {
            return BidValidationResult.Failure(
                $"Bid price {bidPrice} outside valid range [{minAcceptablePrice}, {maxAcceptablePrice}]");
        }
        
        return BidValidationResult.Success();
    }
}
```

**Tolerance**: 2 seconds covers:
- Network latency: ~500ms
- Client-server clock drift: ~1s
- Processing time: ~500ms

---

## Caching Strategy

### Problem
Calculating price on every request może być wasteful:
- Frontend polls every 1 second
- 100 concurrent viewers = 100 calculations/sec
- Most calculations return same value

### Solution: Short TTL Cache

```csharp
public sealed class CachedPriceCalculationService
{
    private readonly IMemoryCache _cache;
    private readonly TimeSpan _cacheDuration = TimeSpan.FromSeconds(5);
    
    public Money GetCurrentPrice(Auction auction)
    {
        var cacheKey = $"auction-price:{auction.Id}";
        
        if (_cache.TryGetValue<Money>(cacheKey, out var cachedPrice))
            return cachedPrice;
        
        var currentPrice = auction.CalculateCurrentPrice(DateTime.UtcNow);
        
        _cache.Set(cacheKey, currentPrice, _cacheDuration);
        
        return currentPrice;
    }
}
```

**Cache Duration**: 5 seconds
- Balance między freshness a load reduction
- Shorter than typical drop interval (30 sec)
- Viewers see ~same price for few seconds

**Alternative**: Redis distributed cache dla multi-server scenario

---

## Price Drop Events (Periodic)

### Purpose
Frontend needs to update price display smoothly. Zamiast polling co sekundę, używamy **periodic events**.

### Background Job

```csharp
public class PriceDropPublisher : IHostedService
{
    private Timer _timer;
    
    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Publish PriceDropped events every 10 seconds
        _timer = new Timer(
            PublishPriceDrops,
            null,
            TimeSpan.Zero,
            TimeSpan.FromSeconds(10));
        
        return Task.CompletedTask;
    }
    
    private async void PublishPriceDrops(object state)
    {
        var activeAuctions = await _repository.GetActiveAuctionsAsync();
        
        foreach (var auction in activeAuctions)
        {
            var currentPrice = auction.CalculateCurrentPrice(DateTime.UtcNow);
            
            var priceDropped = new PriceDropped
            {
                EventId = Guid.NewGuid(),
                OccurredOn = DateTime.UtcNow,
                TenantId = auction.TenantId,
                AuctionId = auction.Id,
                CurrentPrice = currentPrice.Amount,
                Currency = currentPrice.Currency.ToString(),
                DropsRemaining = CalculateRemainingDrops(auction)
            };
            
            await _eventPublisher.PublishAsync(priceDropped);
        }
    }
}
```

### Frontend Integration

```typescript
// SignalR subscription
connection.on("PriceUpdated", (data: PriceUpdate) => {
  updatePriceDisplay(data.currentPrice);
  updateProgressBar(data.dropsRemaining);
});
```

**Frequency**: 10 seconds
- Balance między real-time feel a network overhead
- Smooth enough dla user experience
- Reduces polling traffic

---

## Edge Cases

### 1. Auction Published in the Past

```
Scenario: System downtime, scheduled auction missed PublishAt time

Solution: Calculate price from PublishAt, not current time
```

```csharp
public void Publish()
{
    if (PublishAt.HasValue && PublishAt.Value < DateTime.UtcNow)
    {
        // Late publish - use scheduled time
        PublishedOn = PublishAt.Value;
    }
    else
    {
        // Normal publish
        PublishedOn = DateTime.UtcNow;
    }
    
    Status = AuctionStatus.Published;
}
```

### 2. Clock Drift Between Servers

```
Scenario: Server A thinks it's 12:00:00, Server B thinks 12:00:05

Mitigation:
- Use NTP sync (Azure VMs auto-sync)
- Monitor drift (alert if > 1 sec)
- Tolerance window in bid validation
```

### 3. Negative Calculated Price

```
Scenario: Price drops below zero due to long duration

Solution: Bound by EndPrice
```

```csharp
var calculatedPrice = StartPrice.Subtract(dropAmount);
return Money.From(
    Math.Max(calculatedPrice.Amount, EndPrice.Amount),
    StartPrice.Currency);
```

### 4. Precision Issues with Decimals

```csharp
// ❌ WRONG - Float precision issues
float price = 1000.0f - (intervals * 0.1f);

// ✅ CORRECT - Decimal for money
decimal price = 1000.0m - (intervals * 0.1m);
```

**Always use `decimal` for money calculations!**

---

## Testing Strategy

### Unit Tests

```csharp
[Fact]
public void CalculatePriceAt_AtStart_ReturnsStartPrice()
{
    // Arrange
    var schedule = PriceSchedule.Create(
        startPrice: Money.From(1000, Currency.PLN),
        endPrice: Money.From(500, Currency.PLN),
        dropRate: PriceDropRate.Absolute(10, 30),
        duration: TimeSpan.FromHours(1));
    
    var startTime = DateTime.UtcNow;
    
    // Act
    var price = schedule.CalculatePriceAt(startTime, startTime);
    
    // Assert
    Assert.Equal(1000, price.Amount);
}

[Fact]
public void CalculatePriceAt_AfterOneInterval_DropsCorrectly()
{
    // Test various intervals...
}

[Fact]
public void CalculatePriceAt_AfterDuration_ReturnsEndPrice()
{
    // Test boundary...
}
```

### Integration Tests

```csharp
[Fact]
public async Task AcceptBid_WithValidPrice_Succeeds()
{
    // Arrange: Published auction
    var auction = await CreatePublishedAuction();
    
    // Act: Bid at current price
    var currentPrice = auction.CalculateCurrentPrice(DateTime.UtcNow);
    var result = auction.AcceptBid(
        BidId.Create(),
        UserId.Create(),
        currentPrice,
        DateTime.UtcNow);
    
    // Assert
    Assert.True(result.IsSuccess);
}
```

### Load Tests

```
Scenario: 1000 concurrent users viewing auction
- Price calculation load: 1000 req/sec
- Target latency: < 10ms p99
- Cache hit rate: > 80%
```

---

## Performance Characteristics

### Calculation Time
- **Best case**: < 1ms (in-memory arithmetic)
- **With cache**: < 0.1ms (cache hit)
- **Worst case**: < 10ms (cache miss + calculation)

### Memory Footprint
- No persistent price history: **Zero**
- Cache per auction: ~100 bytes
- 1000 active auctions: ~100 KB cache

### CPU Usage
- Without cache: ~0.001 CPU-sec per calculation
- With cache (80% hit rate): ~0.0002 CPU-sec per calculation
- 1000 req/sec: ~0.2 CPU cores

**Conclusion**: On-the-fly calculation is **highly efficient** dla MVP scale.

---

## Future Enhancements

### 1. Complex Drop Patterns
Currently: Linear drop
Future: Step functions, exponential decay, accelerating drops

```csharp
public enum PriceDropPattern
{
    Linear,          // Current
    StepFunction,    // Drop in discrete steps
    Exponential,     // Accelerating drops
    Logarithmic      // Decelerating drops
}
```

### 2. Reserve Price (Secret Minimum)
Sprzedawca może ustawić confidential minimum poniżej którego nie sprzeda

```csharp
public class PriceSchedule
{
    public Money? ReservePrice { get; } // Secret, not shown to buyers
    
    public Money CalculatePriceAt(DateTime startTime, DateTime currentTime)
    {
        var calculatedPrice = /* normal calculation */;
        
        // If below reserve, end auction without sale
        if (ReservePrice.HasValue && calculatedPrice < ReservePrice)
            return ReservePrice.Value; // Or end auction
    }
}
```

### 3. Dynamic Adjustments
Adjust drop rate based on demand (AI-driven pricing)

**Out of scope for MVP** - requires ML/analytics
