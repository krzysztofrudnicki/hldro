# Bidding Context - Domain Events

## Events Published

### BidAttemptCreated

**When**: Użytkownik złożył bid attempt

```csharp
public sealed record BidAttemptCreated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public BidId BidId { get; init; }
    public AuctionId AuctionId { get; init; }
    public UserId UserId { get; init; }
    public decimal BidPrice { get; init; }
    public string Currency { get; init; }
}
```

**Subscribers**:
- Analytics: Track bid attempt rate
- Audit Log: Record all bid attempts

---

### ViewerSessionStarted

**When**: Użytkownik dołączył do oglądania aukcji

```csharp
public sealed record ViewerSessionStarted : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ViewerSessionId SessionId { get; init; }
    public AuctionId AuctionId { get; init; }
    public UserId? UserId { get; init; } // Null if anonymous
    public string ConnectionId { get; init; }
}
```

**Subscribers**:
- Analytics: Track viewer engagement
- Read Models: Update active viewers count

---

### ViewerSessionEnded

**When**: Użytkownik opuścił auction page

```csharp
public sealed record ViewerSessionEnded : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ViewerSessionId SessionId { get; init; }
    public AuctionId AuctionId { get; init; }
    public TimeSpan Duration { get; init; }
}
```

**Subscribers**:
- Analytics: Calculate average viewing time
- Read Models: Decrement active viewers count

---

## Events Subscribed (from other contexts)

### From Auction Context

- **AuctionPublished** → Start accepting viewers/bids
- **PriceDropped** → Push price update to viewers via SignalR
- **BidAccepted** → Update BidAttempt status, notify winner + other viewers
- **BidRejected** → Update BidAttempt status, notify bidder
- **ItemSoldInAuction** → Notify all viewers
- **AuctionEnded** → Stop accepting bids, notify viewers

---

## SignalR Push Messages (Not Domain Events)

These are real-time notifications pushed via SignalR, not persisted events:

### PriceUpdated
```typescript
{
  auctionId: string,
  currentPrice: number,
  currency: string,
  dropsRemaining: number
}
```

### BidSubmitted
```typescript
{
  auctionId: string,
  bidPrice: number
  // No user info for privacy
}
```

### ItemSold
```typescript
{
  auctionId: string,
  remainingItems: number,
  message: "Item was just sold!"
}
```

### ViewerCountUpdated
```typescript
{
  auctionId: string,
  activeViewers: number
}
```

### BidAccepted (to winner only)
```typescript
{
  bidId: string,
  winningPrice: number,
  reservationId: string,
  message: "Congratulations! Proceed to checkout."
}
```

### BidRejected (to bidder only)
```typescript
{
  bidId: string,
  reason: string,
  currentPrice: number,
  message: "Bid rejected. Please try again."
}
```

---

## Event Processing Notes

- **Idempotency**: All handlers check for duplicate processing
- **Latency**: Real-time handlers prioritized (< 500ms target)
- **Ordering**: Per BidAttempt ordering maintained
