# Tenant Management Context

## Overview

Zarządzanie tenantami (dużymi sprzedawcami) - ich konfiguracją, brandingiem, hierarchią kategorii, i settings.

## Responsibility

1. **Tenant Onboarding**: Tworzenie nowych tenantów
2. **Configuration Management**: Settings per tenant
3. **Category Hierarchy**: Każdy tenant ma własne drzewo kategorii
4. **Branding**: Subdomena, logo, colors
5. **Status Management**: Active, Suspended, Inactive

---

## Domain Model

### Tenant (Aggregate Root)

```csharp
public sealed class Tenant : AggregateRoot<TenantId>
{
    public TenantName Name { get; private set; }
    public Subdomain Subdomain { get; private set; }
    public ContactEmail ContactEmail { get; private set; }
    
    public TenantStatus Status { get; private set; }
    public DateTime CreatedAt { get; private set; }
    public DateTime? ActivatedAt { get; private set; }
    public DateTime? SuspendedAt { get; private set; }
    
    // Branding
    public BrandingConfiguration Branding { get; private set; }
    
    // Configuration
    public TenantConfiguration Configuration { get; private set; }
    
    // Factory
    public static Tenant Create(
        TenantName name,
        Subdomain subdomain,
        ContactEmail contactEmail);
    
    // Commands
    public void UpdateBranding(BrandingConfiguration branding);
    
    public void UpdateConfiguration(TenantConfiguration configuration);
    
    public void Activate();
    
    public void Suspend(string reason);
    
    public void Deactivate(string reason);
    
    // Queries
    public bool IsActive() => Status == TenantStatus.Active;
}
```

---

### Value Objects

#### TenantName

```csharp
public sealed class TenantName : ValueObject
{
    public string Value { get; }
    
    private TenantName(string value)
    {
        // 3-100 characters
        Value = value;
    }
    
    public static TenantName From(string value);
}
```

#### Subdomain

```csharp
public sealed class Subdomain : ValueObject
{
    public string Value { get; } // e.g., "mediamarkt" → mediamarkt.platform.com
    
    private Subdomain(string value)
    {
        // Lowercase, alphanumeric + dash, 3-50 characters
        // Must be unique across all tenants
        Value = value;
    }
    
    public static Subdomain From(string value);
    public string GetFullDomain() => $"{Value}.reverseauction.com";
}
```

#### ContactEmail

```csharp
public sealed class ContactEmail : ValueObject
{
    public string Value { get; }
    
    private ContactEmail(string value)
    {
        // Valid email format
        Value = value;
    }
    
    public static ContactEmail From(string value);
}
```

#### BrandingConfiguration

```csharp
public sealed class BrandingConfiguration : ValueObject
{
    public string? LogoUrl { get; }
    public HexColor PrimaryColor { get; }
    public HexColor SecondaryColor { get; }
    public string? FaviconUrl { get; }
    
    private BrandingConfiguration(
        string primaryColor,
        string secondaryColor,
        string? logoUrl = null,
        string? faviconUrl = null)
    {
        PrimaryColor = HexColor.From(primaryColor);
        SecondaryColor = HexColor.From(secondaryColor);
        LogoUrl = logoUrl;
        FaviconUrl = faviconUrl;
    }
    
    public static BrandingConfiguration Create(
        string primaryColor,
        string secondaryColor,
        string? logoUrl = null,
        string? faviconUrl = null);
    
    public static BrandingConfiguration Default() =>
        Create("#1E40AF", "#3B82F6"); // Blue theme
}
```

#### TenantConfiguration

```csharp
public sealed class TenantConfiguration : ValueObject
{
    public Currency DefaultCurrency { get; }
    public string DefaultLanguage { get; } // ISO 639-1
    public TimeZoneInfo TimeZone { get; }
    
    // Auction defaults
    public TimeSpan DefaultReservationTimeout { get; }
    public int MaxConcurrentAuctions { get; }
    
    // Integration settings
    public string? EcommercePlatform { get; } // "Shopify", "WooCommerce", etc.
    public string? EcommerceApiKey { get; } // Encrypted
    
    private TenantConfiguration(
        Currency defaultCurrency,
        string defaultLanguage,
        TimeZoneInfo timeZone,
        TimeSpan defaultReservationTimeout,
        int maxConcurrentAuctions)
    {
        DefaultCurrency = defaultCurrency;
        DefaultLanguage = defaultLanguage;
        TimeZone = timeZone;
        DefaultReservationTimeout = defaultReservationTimeout;
        MaxConcurrentAuctions = maxConcurrentAuctions;
    }
    
    public static TenantConfiguration Create(
        Currency defaultCurrency,
        string defaultLanguage,
        string timeZoneId,
        TimeSpan? reservationTimeout = null,
        int? maxConcurrentAuctions = null);
    
    public static TenantConfiguration Default() =>
        Create(Currency.PLN, "pl", "Europe/Warsaw");
}
```

---

### Enums

#### TenantStatus

```csharp
public enum TenantStatus
{
    PendingActivation,  // Created, not yet active
    Active,             // Fully operational
    Suspended,          // Temporarily disabled (payment issue, violations)
    Inactive            // Permanently disabled
}
```

---

## Domain Events

### TenantCreated

```csharp
public sealed record TenantCreated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public string Name { get; init; }
    public string Subdomain { get; init; }
    public string ContactEmail { get; init; }
}
```

**Subscribers**:
- Product Catalog: Initialize empty catalog
- Email Service: Send welcome email
- DNS Service: Configure subdomain

### TenantActivated

```csharp
public sealed record TenantActivated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
}
```

**Subscribers**:
- All contexts: Tenant is now operational
- Notification Service: Send activation email

### TenantSuspended

```csharp
public sealed record TenantSuspended : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public string Reason { get; init; }
}
```

**Subscribers**:
- Auction Context: End all active auctions
- Inventory Context: Lock all items
- Notification Service: Alert tenant admin

### TenantConfigurationUpdated

```csharp
public sealed record TenantConfigurationUpdated : IDomainEvent
{
    public Guid EventId { get; init; }
    public DateTime OccurredOn { get; init; }
    public TenantId TenantId { get; init; }
    
    public Dictionary<string, string> ChangedSettings { get; init; }
}
```

---

## Application Services

### TenantOnboardingService

```csharp
public sealed class TenantOnboardingService
{
    public async Task<TenantId> OnboardTenantAsync(
        string name,
        string subdomain,
        string contactEmail)
    {
        // Validate subdomain uniqueness
        if (await _repository.ExistsWithSubdomainAsync(subdomain))
            throw new DomainException("SUBDOMAIN_EXISTS", "Subdomain already taken");
        
        // Create tenant
        var tenant = Tenant.Create(
            TenantName.From(name),
            Subdomain.From(subdomain),
            ContactEmail.From(contactEmail));
        
        await _repository.SaveAsync(tenant);
        
        // TenantCreated event published
        // → Triggers initialization in other contexts
        
        return tenant.Id;
    }
}
```

---

## Multi-tenancy Strategy

### Data Isolation

**Strategy**: Shared database with TenantId partitioning (for MVP)

```sql
-- Every table has TenantId
CREATE TABLE Auctions (
    Id uniqueidentifier PRIMARY KEY,
    TenantId uniqueidentifier NOT NULL,
    Title nvarchar(200) NOT NULL,
    -- ... other fields
    INDEX IX_Auctions_TenantId (TenantId)
);

-- Row-level security
CREATE SECURITY POLICY TenantFilter
ADD FILTER PREDICATE dbo.fn_TenantAccessPredicate(TenantId)
ON dbo.Auctions
WITH (STATE = ON);
```

**Future**: Separate database per tenant (dla enterprise)

### Request Context

```csharp
public interface ITenantContext
{
    TenantId CurrentTenantId { get; }
}

// Populated from subdomain or auth token
public class TenantContextMiddleware
{
    public async Task InvokeAsync(HttpContext context, ITenantContext tenantContext)
    {
        // Extract tenant from subdomain
        var subdomain = ExtractSubdomain(context.Request.Host);
        var tenant = await _tenantRepository.GetBySubdomainAsync(subdomain);
        
        if (tenant == null)
            return Results.NotFound("Tenant not found");
        
        // Set context for request
        tenantContext.SetTenant(tenant.Id);
        
        await _next(context);
    }
}
```

---

## Technical Considerations

### Subdomain Routing

**Azure Configuration**:
```
*.reverseauction.com → Azure App Service
App Service → Extract subdomain → Route to tenant
```

**DNS Wildcard**:
```
*.reverseauction.com  CNAME  app-service.azurewebsites.net
```

### Tenant Discovery

```csharp
public class TenantMiddleware
{
    public async Task InvokeAsync(HttpContext context)
    {
        var host = context.Request.Host.Host;
        
        // Extract subdomain
        // mediamarkt.reverseauction.com → "mediamarkt"
        var parts = host.Split('.');
        if (parts.Length < 3)
            throw new InvalidOperationException("Invalid hostname");
        
        var subdomain = parts[0];
        
        // Lookup tenant (with caching)
        var tenant = await _tenantCache.GetOrAddAsync(
            subdomain,
            () => _tenantRepository.GetBySubdomainAsync(subdomain));
        
        if (tenant == null || !tenant.IsActive())
            return Results.NotFound("Tenant not found or inactive");
        
        context.Items["TenantId"] = tenant.Id;
        
        await _next(context);
    }
}
```

### Caching Strategy

```csharp
// Cache tenant config aggressively (changes rare)
public class CachedTenantRepository
{
    private readonly IMemoryCache _cache;
    private readonly TimeSpan _cacheDuration = TimeSpan.FromMinutes(30);
    
    public async Task<Tenant?> GetBySubdomainAsync(string subdomain)
    {
        var cacheKey = $"tenant:subdomain:{subdomain}";
        
        if (_cache.TryGetValue<Tenant>(cacheKey, out var tenant))
            return tenant;
        
        tenant = await _innerRepository.GetBySubdomainAsync(subdomain);
        
        if (tenant != null)
            _cache.Set(cacheKey, tenant, _cacheDuration);
        
        return tenant;
    }
}
```

---

## Future Enhancements

- **Usage Metrics**: Track auction count, sales volume per tenant
- **Billing Integration**: Usage-based pricing
- **Custom Domains**: Tenant może używać własnej domeny (auctions.mediamarkt.pl)
- **White-labeling**: Pełne custom branding
- **API Keys**: Tenant może używać API dla integracji
