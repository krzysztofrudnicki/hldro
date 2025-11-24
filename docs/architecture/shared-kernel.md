# Shared Kernel

## Overview

Shared Kernel zawiera typy i koncepty współdzielone między bounded contexts. Te elementy muszą być zsynchronizowane między wszystkimi kontekstami i wymagają agreement przy zmianach.

**Zasada**: Minimalizuj Shared Kernel - im mniejszy, tym mniejsze coupling między BC.

## Value Objects

### Money

**Responsibility**: Reprezentacja wartości pieniężnej z walutą

```csharp
public sealed class Money : ValueObject
{
    public decimal Amount { get; }
    public Currency Currency { get; }
    
    // Invariants:
    // - Amount must have max 2 decimal places
    // - Amount cannot be negative for prices
    // - Currency must be valid ISO code
    
    public Money Add(Money other);
    public Money Subtract(Money other);
    public Money MultiplyBy(decimal multiplier);
    public Money ApplyPercentageDiscount(decimal percentage);
    
    // Equality based on Amount + Currency
}
```

**Usage Contexts**: Auction, Bidding, Reservation, Product Catalog

---

### TenantId

**Responsibility**: Identyfikator tenanta (sprzedawcy)

```csharp
public sealed class TenantId : ValueObject
{
    public Guid Value { get; }
    
    // Invariants:
    // - Cannot be empty Guid
    // - Format: GUID v4
    
    public static TenantId Create();
    public static TenantId From(Guid value);
    public static TenantId From(string value);
}
```

**Usage**: **EVERY** bounded context - wszystkie operacje muszą być w kontekście tenanta

---

### ProductModelId

**Responsibility**: Identyfikator "klasy" produktu (modelu)

```csharp
public sealed class ProductModelId : ValueObject
{
    public Guid Value { get; }
    
    public static ProductModelId Create();
    public static ProductModelId From(Guid value);
}
```

**Usage Contexts**: Product Catalog (origin), Inventory (reference)

---

### InventoryItemId

**Responsibility**: Identyfikator konkretnego fizycznego egzemplarza

```csharp
public sealed class InventoryItemId : ValueObject
{
    public Guid Value { get; }
    
    public static InventoryItemId Create();
    public static InventoryItemId From(Guid value);
}
```

**Usage Contexts**: Inventory (origin), Auction (reference), Reservation (reference)

---

### AuctionId

**Responsibility**: Identyfikator aukcji

```csharp
public sealed class AuctionId : ValueObject
{
    public Guid Value { get; }
    
    public static AuctionId Create();
    public static AuctionId From(Guid value);
}
```

**Usage Contexts**: Auction (origin), Bidding (reference), Reservation (reference)

---

### UserId

**Responsibility**: Identyfikator użytkownika (kupujący/sprzedawca)

```csharp
public sealed class UserId : ValueObject
{
    public Guid Value { get; }
    
    public static UserId Create();
    public static UserId From(Guid value);
}
```

**Usage Contexts**: Identity (origin), Bidding (reference), Reservation (reference)

---

## Enums (Shared)

### Currency

```csharp
public enum Currency
{
    PLN,
    EUR,
    USD,
    GBP
}
```

**Note**: W przyszłości może być to value object z validation przeciwko ISO 4217

---

## Common Interfaces

### IAggregateRoot

```csharp
public interface IAggregateRoot
{
    IReadOnlyCollection<IDomainEvent> DomainEvents { get; }
    void ClearDomainEvents();
}
```

### IDomainEvent

```csharp
public interface IDomainEvent
{
    Guid EventId { get; }
    DateTime OccurredOn { get; }
    TenantId TenantId { get; }
}
```

**Note**: TenantId w każdym evencie dla proper routing i filtering

### IEntity

```csharp
public interface IEntity<TId> where TId : ValueObject
{
    TId Id { get; }
}
```

---

## Base Classes

### ValueObject

```csharp
public abstract class ValueObject
{
    protected abstract IEnumerable<object> GetEqualityComponents();
    
    public override bool Equals(object obj);
    public override int GetHashCode();
    public static bool operator ==(ValueObject left, ValueObject right);
    public static bool operator !=(ValueObject left, ValueObject right);
}
```

### Entity<TId>

```csharp
public abstract class Entity<TId> : IEntity<TId> where TId : ValueObject
{
    public TId Id { get; protected set; }
    
    public override bool Equals(object obj); // Based on Id
    public override int GetHashCode(); // Based on Id
}
```

### AggregateRoot<TId>

```csharp
public abstract class AggregateRoot<TId> : Entity<TId>, IAggregateRoot 
    where TId : ValueObject
{
    private readonly List<IDomainEvent> _domainEvents = new();
    
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();
    
    protected void AddDomainEvent(IDomainEvent domainEvent)
    {
        _domainEvents.Add(domainEvent);
    }
    
    public void ClearDomainEvents()
    {
        _domainEvents.Clear();
    }
}
```

---

## Common Exceptions

### DomainException

```csharp
public abstract class DomainException : Exception
{
    public string ErrorCode { get; }
    
    protected DomainException(string errorCode, string message) 
        : base(message)
    {
        ErrorCode = errorCode;
    }
}
```

Przykłady:
- `InvalidPriceException`
- `InvalidTenantException`
- `AggregateNotFoundException`

---

## Guidelines

### Value Object Creation
- Static factory methods (`Create()`, `From()`)
- Validation w konstruktorze (fail fast)
- Immutable - brak setterów

### Entity ID Guidelines
- Zawsze strongly-typed IDs (nie `Guid` directly)
- Generate w domain, nie w infrastructure
- Semantic naming (`ProductModelId` nie `ProductId`)

### Domain Event Guidelines
- Past tense naming (`ItemReserved` nie `ReserveItem`)
- Zawsze TenantId dla routing
- Immutable data class
- Contained data - nie references do aggregates

### Shared Kernel Changes
⚠️ **Breaking changes w Shared Kernel wymagają agreement wszystkich BC maintainers**

Proces:
1. Propose change + impact analysis
2. Update wszystkich affected BC simultaneously
3. Versioning jeśli breaking change

---

## Anti-Patterns

❌ **Anemic Value Objects** - Value Object bez behavior to tylko data class
❌ **Mutable Value Objects** - Value Objects MUSZĄ być immutable
❌ **Primitive Obsession** - nie używaj `Guid`, `decimal`, `string` bezpośrednio
❌ **Too Much in Shared Kernel** - każda dodatkowa rzecz w SK to coupling

✅ **Good Practice**: Jeśli wątpisz czy coś powinno być w SK, najpierw zaimplementuj lokalnie w BC
