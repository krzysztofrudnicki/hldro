# Product Catalog Context - Domain Events

## Overview

Domain Events publikowane przez Product Catalog Context. Inne bounded contexts mogą subskrybować te eventy dla synchronizacji read models lub triggering własnych workflow.

**Note**: Wszystkie events zawierają `TenantId` dla proper routing.

---

## ProductModel Events

### ProductModelCreated

**When**: Nowy ProductModel został utworzony w katalogu

```csharp
public sealed record ProductModelCreated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public SKU SKU { get; init; }
    public string Name { get; init; }
    public string Description { get; init; }
    public CategoryId CategoryId { get; init; }
    public decimal BasePrice { get; init; }
    public string Currency { get; init; }
}
```

**Subscribers**:
- Inventory Context: Może przygotować się na tworzenie inventory items
- Search Service: Indeksuje nowy produkt

---

### ProductModelDetailsUpdated

**When**: Nazwa lub opis ProductModel zostały zaktualizowane

```csharp
public sealed record ProductModelDetailsUpdated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public string NewName { get; init; }
    public string NewDescription { get; init; }
}
```

**Subscribers**:
- Read Models: Denormalizują aktualizowane dane
- Search Service: Reindeksuje produkt

---

### ProductModelCategorized

**When**: ProductModel został przypisany do innej kategorii

```csharp
public sealed record ProductModelCategorized : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public CategoryId OldCategoryId { get; init; }
    public CategoryId NewCategoryId { get; init; }
}
```

**Subscribers**:
- Read Models: Aktualizują category navigation
- Search Service: Aktualizuje facets/filters

---

### ProductModelPriceChanged

**When**: BasePrice został zmieniony

```csharp
public sealed record ProductModelPriceChanged : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public decimal OldPrice { get; init; }
    public decimal NewPrice { get; init; }
    public string Currency { get; init; }
}
```

**Subscribers**:
- Auction Context: Może używać jako reference dla start price
- Analytics: Track price changes

---

### SpecificationAdded

**When**: Nowa specyfikacja została dodana do ProductModel

```csharp
public sealed record SpecificationAdded : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public string Key { get; init; }
    public string Value { get; init; }
}
```

**Subscribers**:
- Read Models: Denormalizują specs
- Search Service: Może używać dla filtering

---

### SpecificationRemoved

**When**: Specyfikacja została usunięta z ProductModel

```csharp
public sealed record SpecificationRemoved : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public string Key { get; init; }
}
```

---

### ProductMediaAdded

**When**: Nowe media (image/video) zostało dodane do ProductModel

```csharp
public sealed record ProductMediaAdded : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public ProductMediaId MediaId { get; init; }
    public string MediaType { get; init; } // Image, Video, Document
    public string Url { get; init; }
    public string? ThumbnailUrl { get; init; }
}
```

**Subscribers**:
- CDN: Może pre-cache media
- Image Processing: Może generować thumbnails/variants

---

### MainImageChanged

**When**: Główne zdjęcie ProductModel zostało zmienione

```csharp
public sealed record MainImageChanged : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public ProductMediaId? OldMainImageId { get; init; }
    public ProductMediaId NewMainImageId { get; init; }
}
```

**Subscribers**:
- Read Models: Aktualizują thumbnail w listach
- CDN: Priority caching dla main image

---

### ProductModelArchived

**When**: ProductModel został zarchiwizowany (soft delete)

```csharp
public sealed record ProductModelArchived : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
    public string Reason { get; init; } // Optional: why archived
}
```

**Subscribers**:
- Inventory Context: Może oznaczyć items jako unavailable
- Search Service: Usuwa z indeksu

---

### ProductModelActivated

**When**: Zarchiwizowany ProductModel został ponownie aktywowany

```csharp
public sealed record ProductModelActivated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public ProductModelId ProductModelId { get; init; }
}
```

**Subscribers**:
- Search Service: Re-indeksuje produkt

---

## Category Events

### CategoryCreated

**When**: Nowa kategoria została utworzona

```csharp
public sealed record CategoryCreated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public CategoryId CategoryId { get; init; }
    public string Name { get; init; }
    public CategoryId? ParentCategoryId { get; init; }
    public string Path { get; init; }
    public int Level { get; init; }
}
```

**Subscribers**:
- Read Models: Budują category tree navigation

---

### CategoryRenamed

**When**: Nazwa kategorii została zmieniona

```csharp
public sealed record CategoryRenamed : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public CategoryId CategoryId { get; init; }
    public string OldName { get; init; }
    public string NewName { get; init; }
}
```

---

### CategoryMoved

**When**: Kategoria została przeniesiona w hierarchii

```csharp
public sealed record CategoryMoved : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public CategoryId CategoryId { get; init; }
    public CategoryId? OldParentCategoryId { get; init; }
    public CategoryId? NewParentCategoryId { get; init; }
    public string OldPath { get; init; }
    public string NewPath { get; init; }
    public int OldLevel { get; init; }
    public int NewLevel { get; init; }
}
```

**Subscribers**:
- Read Models: Przebudowują category tree
- Search Service: Aktualizuje category facets

**Impact**: Może triggerować cascade update wszystkich child categories

---

### CategoryDisplayOrderChanged

**When**: Kolejność wyświetlania kategorii została zmieniona

```csharp
public sealed record CategoryDisplayOrderChanged : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public CategoryId CategoryId { get; init; }
    public int OldDisplayOrder { get; init; }
    public int NewDisplayOrder { get; init; }
}
```

---

### CategoryDeactivated

**When**: Kategoria została zdezaktywowana

```csharp
public sealed record CategoryDeactivated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public CategoryId CategoryId { get; init; }
}
```

**Subscribers**:
- Read Models: Ukrywają kategorię w navigation

---

### CategoryActivated

**When**: Kategoria została reaktywowana

```csharp
public sealed record CategoryActivated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public CategoryId CategoryId { get; init; }
}
```

---

## Event Processing Guidelines

### Idempotency
Wszystkie event handlers MUSZĄ być idempotent - mogą otrzymać ten sam event wielokrotnie.

### Ordering
Events dla tego samego aggregate zachowują kolejność (EventId, OccurredOn).

### Retry Policy
Failed event processing powinien mieć retry z exponential backoff.

### Dead Letter Queue
Po N failed retries, event trafia do DLQ dla manual investigation.

---

## Event Store (Optional)

Rozważ Event Sourcing dla audit trail:
- Wszystkie zmiany w ProductModel jako sekwencja events
- Możliwość rebuild state z event stream
- Time-travel queries (jak wyglądał produkt w przeszłości)

**Trade-off**: Zwiększona complexity vs pełny audit trail
