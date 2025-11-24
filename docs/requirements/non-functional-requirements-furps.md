# Non-Functional Requirements (FURPS+)

## Overview

FURPS+ to framework definiujący non-functional requirements:
- **F**unctionality (funkcjonalność systemowa)
- **U**sability (użyteczność)
- **R**eliability (niezawodność)
- **P**erformance (wydajność)
- **S**upportability (wsparcie)
- **+** (Design, Implementation, Interface, Physical)

---

## F - Functionality (Cross-cutting Concerns)

### F.1 Security 🔒

#### F.1.1 Authentication & Authorization
**Requirement**: System MUSI zapewnić secure authentication i role-based authorization

**Acceptance Criteria**:
- [ ] JWT tokens z krótkim TTL (15 min access, 7 days refresh)
- [ ] Tokens przechowywane w httpOnly cookies (XSS protection)
- [ ] Azure AD B2C integration dla Marketer/Operator roles
- [ ] Social login support dla Customer (Google, Facebook)
- [ ] MFA required dla Operator role
- [ ] Role-based access control (RBAC): Operator, Marketer, Customer
- [ ] Tenant isolation enforced na poziomie middleware
- [ ] API endpoints chronione [Authorize] attributes

**Validation**:
```csharp
// Security test example
[Fact]
public async Task Unauthorized_User_Cannot_Create_Auction()
{
    var response = await _client.PostAsync("/api/auctions", content);
    Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
}
```

**Standards**:
- OWASP Top 10 compliance
- Password policy: min 8 chars, uppercase, lowercase, digit, special char
- Failed login attempts: max 5, lockout 15 minutes
- Session timeout: 30 minutes inactivity

#### F.1.2 Data Protection
**Requirement**: Sensitive data MUSI być encrypted at rest i in transit

**Acceptance Criteria**:
- [ ] HTTPS only (TLS 1.3)
- [ ] Azure SQL Transparent Data Encryption (TDE) enabled
- [ ] Secrets w Azure Key Vault (NO secrets in code/config)
- [ ] PII data encrypted (email, phone number) - AES-256
- [ ] Connection strings via Managed Identity
- [ ] GDPR compliance: right to erasure, data portability

**Standards**:
- All external API calls over HTTPS
- Certificate pinning dla mobile apps
- Encrypt PII w database (Entity Framework Value Converters)

#### F.1.3 Tenant Isolation
**Requirement**: Tenant data MUSI być całkowicie izolowane

**Acceptance Criteria**:
- [ ] TenantId w każdej tabeli (composite key lub partition)
- [ ] Row-level security policies w SQL
- [ ] Query filters automatycznie dodają WHERE TenantId = @currentTenant
- [ ] Cross-tenant access logowany jako security incident
- [ ] Integration tests sprawdzają tenant isolation

**Validation**:
```sql
-- Row-level security policy
CREATE SECURITY POLICY TenantFilter
ADD FILTER PREDICATE dbo.fn_TenantAccessPredicate(TenantId)
ON dbo.Auctions WITH (STATE = ON);
```

---

### F.2 Auditability 📝

#### F.2.1 Event Logging
**Requirement**: Wszystkie domain events MUSZĄ być persisted dla audit trail

**Acceptance Criteria**:
- [ ] Outbox pattern dla reliable event publishing
- [ ] Event store table: EventId, EventType, EventData (JSON), OccurredOn, ProcessedOn
- [ ] Retention: minimum 90 days (configurable per tenant)
- [ ] Events immutable (append-only)
- [ ] Replay capability dla debugging

**Storage**:
```sql
CREATE TABLE OutboxMessages (
    Id uniqueidentifier PRIMARY KEY,
    TenantId uniqueidentifier NOT NULL,
    EventType nvarchar(200) NOT NULL,
    EventData nvarchar(MAX) NOT NULL, -- JSON
    OccurredOn datetime2 NOT NULL,
    ProcessedOn datetime2 NULL,
    INDEX IX_OutboxMessages_ProcessedOn (ProcessedOn)
        WHERE ProcessedOn IS NULL
);
```

#### F.2.2 Action Logging
**Requirement**: Critical user actions MUSZĄ być logowane

**Acceptance Criteria**:
- [ ] Log: User ID, Action, Timestamp, IP Address, TenantId
- [ ] Actions logowane: Login, Failed Login, Auction Create, Bid Place, Checkout Complete
- [ ] Structured logging (Serilog + Application Insights)
- [ ] Correlation IDs dla distributed tracing
- [ ] Log retention: 1 year

**Implementation**:
```csharp
_logger.LogInformation(
    "Auction created: {AuctionId} by {UserId} in Tenant {TenantId}",
    auctionId, userId, tenantId);
```

---

## U - Usability 🎨

### U.1 User Experience

#### U.1.1 Response Time Perception
**Requirement**: UI MUSI czuć się "instant" dla users

**Acceptance Criteria**:
- [ ] API response < 200ms dla 95% requests (P95)
- [ ] Page load < 2 seconds (First Contentful Paint)
- [ ] Real-time updates < 500ms latency (SignalR)
- [ ] Optimistic UI updates (bid placement shows immediately)
- [ ] Loading skeletons zamiast spinners
- [ ] Progressive enhancement (works without JS)

**Measurement**:
- Lighthouse score > 90
- Core Web Vitals: LCP < 2.5s, FID < 100ms, CLS < 0.1

#### U.1.2 Accessibility
**Requirement**: System MUSI być accessible (WCAG 2.1 Level AA)

**Acceptance Criteria**:
- [ ] Keyboard navigation dla all features
- [ ] Screen reader support (ARIA labels)
- [ ] Color contrast ratio > 4.5:1
- [ ] Focus indicators widoczne
- [ ] Form validation z clear error messages
- [ ] Skip to main content link
- [ ] No auto-playing audio/video

**Tools**:
- axe DevTools dla automated testing
- Manual testing z NVDA/JAWS

#### U.1.3 Mobile Experience
**Requirement**: Mobile-first responsive design

**Acceptance Criteria**:
- [ ] Touch-friendly targets (min 44x44px)
- [ ] Responsive breakpoints: 320px, 768px, 1024px, 1440px
- [ ] PWA support (Service Worker, manifest.json)
- [ ] Offline mode dla browsing (cached auctions)
- [ ] Fast 3G performance acceptable

---

## R - Reliability 🛡️

### R.1 Availability

#### R.1.1 Uptime SLA
**Requirement**: System MUSI być highly available

**Targets**:
- **Development**: 95% uptime (acceptable dla dev)
- **Staging**: 99% uptime
- **Production**: 99.5% uptime (~3.6h downtime/month)
- **Critical path** (Bidding): 99.9% uptime (~43 min/month)

**Strategies**:
- [ ] Azure App Service z minimum 2 instances (HA)
- [ ] Azure SQL georedundant backups
- [ ] Health checks z auto-restart
- [ ] Blue-green deployments (zero-downtime)
- [ ] Circuit breakers dla external dependencies

#### R.1.2 Disaster Recovery
**Requirement**: System MUSI się odbudować po catastrophic failure

**Acceptance Criteria**:
- [ ] **RTO** (Recovery Time Objective): 4 hours
- [ ] **RPO** (Recovery Point Objective): 15 minutes
- [ ] Automated backups: Azure SQL (daily full, hourly incremental)
- [ ] Geo-replication dla production database
- [ ] Backup restore tested quarterly
- [ ] Disaster recovery playbook dokumentowany

**Backup Strategy**:
```
Daily Full Backup → 30 days retention
Hourly Incremental → 7 days retention
Transaction Log Backup → 15 min interval
Point-in-time restore capability
```

### R.2 Fault Tolerance

#### R.2.1 Graceful Degradation
**Requirement**: System MUSI działać partial jeśli component fails

**Acceptance Criteria**:
- [ ] SignalR down → fallback do HTTP polling
- [ ] Redis down → skip caching, direct DB queries
- [ ] Service Bus down → in-memory queue (temporary)
- [ ] External e-commerce down → show "Checkout temporarily unavailable"
- [ ] Search down → fallback do SQL LIKE queries

**Implementation**:
```csharp
try
{
    await _signalRHub.SendAsync("PriceUpdated", data);
}
catch (Exception ex)
{
    _logger.LogWarning(ex, "SignalR failed, degrading to polling mode");
    _fallbackService.EnablePolling();
}
```

#### R.2.2 Retry & Circuit Breaker
**Requirement**: Transient failures MUSZĄ być handled gracefully

**Acceptance Criteria**:
- [ ] Polly library dla resilience patterns
- [ ] Retry policy: 3 attempts, exponential backoff (2s, 4s, 8s)
- [ ] Circuit breaker: open after 5 consecutive failures, half-open after 30s
- [ ] Timeout policy: 10s dla external APIs, 5s dla internal
- [ ] Dead Letter Queue dla permanently failed events

**Configuration**:
```csharp
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)));

var circuitBreaker = Policy
    .Handle<HttpRequestException>()
    .CircuitBreakerAsync(
        handledEventsAllowedBeforeBreaking: 5,
        durationOfBreak: TimeSpan.FromSeconds(30));
```

---

## P - Performance 🚀

### P.1 Response Time

#### P.1.1 API Latency
**Requirement**: API endpoints MUSZĄ spełniać latency targets

| Endpoint Type | P50 | P95 | P99 | Max |
|---------------|-----|-----|-----|-----|
| Read (GET) | < 50ms | < 200ms | < 500ms | < 1s |
| Write (POST/PUT) | < 100ms | < 300ms | < 800ms | < 2s |
| Complex Query | < 200ms | < 500ms | < 1s | < 3s |
| Bid Placement | < 100ms | < 200ms | < 300ms | < 500ms |

**Measurement**:
- Application Insights dla tracking
- Load tests z k6 lub JMeter
- Alerts jeśli P95 > threshold

**Optimization**:
- [ ] Database indexing strategy documented
- [ ] N+1 query detection (EF Core logging)
- [ ] Caching strategy dla read-heavy endpoints
- [ ] Async/await throughout (no blocking calls)

#### P.1.2 Database Performance
**Requirement**: Database queries MUSZĄ być optimized

**Acceptance Criteria**:
- [ ] No queries > 1 second (alerted w Application Insights)
- [ ] Execution plans reviewed dla complex queries
- [ ] Indexes na all foreign keys
- [ ] Covering indexes dla frequent queries
- [ ] Query Store enabled dla performance analysis
- [ ] Parameterized queries (SQL injection prevention)

**Indexing Strategy**:
```sql
-- Example: Auction queries
CREATE INDEX IX_Auctions_TenantId_Status_PublishedOn
ON Auctions(TenantId, Status, PublishedOn DESC)
INCLUDE (Title, CurrentPrice, EndAt);

-- Partial index dla active auctions only
CREATE INDEX IX_Auctions_Active
ON Auctions(TenantId, PublishedOn DESC)
WHERE Status = 'Active';
```

### P.2 Throughput

#### P.2.1 Concurrent Users
**Requirement**: System MUSI handle expected load

**Targets**:
- **MVP**: 1,000 concurrent users
- **Phase 2**: 10,000 concurrent users
- **Phase 3**: 50,000 concurrent users

**Per Tenant Limits**:
- Max concurrent auctions per tenant: 100 (configurable)
- Max viewers per auction: 10,000
- Max bids per second per auction: 100

**Load Testing**:
```javascript
// k6 load test scenario
export let options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp-up
    { duration: '5m', target: 1000 }, // Sustained load
    { duration: '2m', target: 0 },    // Ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% < 500ms
    http_req_failed: ['rate<0.05'],   // Error rate < 5%
  },
};
```

#### P.2.2 Data Volume
**Requirement**: System MUSI scale z data growth

**Projections** (Year 1):
- Tenants: 50
- Auctions: 10,000/month = 120,000/year
- Inventory Items: 500,000/year
- Bids: 1,000,000/year
- Events: 5,000,000/year

**Strategies**:
- [ ] Partitioning strategy: by TenantId
- [ ] Archival policy: auctions older than 1 year → cold storage
- [ ] Pagination dla all list endpoints (max 100 items per page)
- [ ] Database size monitoring i alerts

### P.3 Scalability

#### P.3.1 Horizontal Scaling
**Requirement**: System MUSI scale out with load

**Acceptance Criteria**:
- [ ] Stateless application tier (no in-process sessions)
- [ ] Session state w Redis (distributed)
- [ ] SignalR backplane z Redis
- [ ] Azure App Service auto-scaling rules
- [ ] Database connection pooling configured

**Auto-scaling Rules**:
```
Scale Out when:
- CPU > 70% for 5 minutes
- Request queue > 100 for 2 minutes

Scale In when:
- CPU < 30% for 10 minutes
- Request queue < 10 for 5 minutes

Min instances: 2 (HA)
Max instances: 10 (cost control)
```

#### P.3.2 Caching Strategy
**Requirement**: Appropriate caching MUSI reduce database load

**Acceptance Criteria**:
- [ ] Redis distributed cache dla shared data
- [ ] Cache-Aside pattern dla reads
- [ ] Event-based cache invalidation
- [ ] Cache hit rate > 70% dla read models

**Cache TTL Guidelines**:
| Data Type | TTL | Invalidation |
|-----------|-----|--------------|
| Tenant Config | 30 min | Event-based |
| Product Catalog | 10 min | Event-based |
| Current Price | 5 sec | Event-based |
| Category Tree | 1 hour | Event-based |
| User Session | 30 min | Sliding |

**Implementation**:
```csharp
public async Task<Auction> GetAuctionAsync(AuctionId id)
{
    var cacheKey = $"auction:{id}";

    var cached = await _cache.GetAsync<Auction>(cacheKey);
    if (cached != null) return cached;

    var auction = await _repository.GetByIdAsync(id);
    await _cache.SetAsync(cacheKey, auction, TimeSpan.FromMinutes(5));

    return auction;
}
```

---

## S - Supportability 🔧

### S.1 Maintainability

#### S.1.1 Code Quality
**Requirement**: Codebase MUSI być maintainable i readable

**Acceptance Criteria**:
- [ ] Clean Code principles applied
- [ ] SOLID principles followed
- [ ] DRY (Don't Repeat Yourself)
- [ ] Code review required dla all PRs
- [ ] Cyclomatic complexity < 10 per method
- [ ] SonarQube quality gate passed
- [ ] No critical/blocker issues

**Metrics**:
- Code coverage: > 80% (unit + integration tests)
- Technical debt ratio < 5%
- Duplicated code < 3%
- Maintainability rating: A

**Tools**:
- SonarQube/SonarCloud dla static analysis
- StyleCop dla C# code style
- ESLint/Prettier dla TypeScript/React

#### S.1.2 Documentation
**Requirement**: System MUSI być well-documented

**Acceptance Criteria**:
- [ ] Architecture Decision Records (ADRs) dla major decisions
- [ ] API documentation (Swagger/OpenAPI)
- [ ] Inline code comments dla complex logic
- [ ] README w każdym bounded context
- [ ] Deployment playbooks
- [ ] Troubleshooting guides

**Documentation Structure**:
```
docs/
├── architecture/          # System architecture
├── bounded-contexts/      # Domain models
├── technical/             # Tech stack, CQRS, etc.
├── requirements/          # NFRs, user stories
├── operations/            # Deployment, monitoring
└── adr/                   # Architecture Decision Records
```

### S.2 Testability

#### S.2.1 Test Coverage
**Requirement**: Comprehensive automated testing strategy

**Test Pyramid**:
```
       E2E (5%)
      /        \
   Integration (15%)
  /                  \
Unit Tests (80%)
```

**Targets**:
- Unit test coverage: > 80%
- Integration test coverage: > 60%
- Critical path E2E tests: 100%

**Test Types**:
1. **Unit Tests**: Isolated logic (aggregates, value objects, domain services)
2. **Integration Tests**: Database, external APIs, message bus
3. **Contract Tests**: API contracts (Pact)
4. **E2E Tests**: Critical user journeys (Playwright/Cypress)
5. **Load Tests**: Performance validation (k6)

#### S.2.2 Test Strategy per Layer

**Domain Layer (Unit Tests)**:
```csharp
[Fact]
public void Auction_Should_Accept_Valid_Bid()
{
    // Arrange
    var auction = AuctionTestBuilder.Create()
        .WithStatus(AuctionStatus.Active)
        .WithCurrentPrice(Money.From(100, "PLN"))
        .Build();

    // Act
    var result = auction.AcceptBid(
        BidId.Create(),
        UserId.Create(),
        Money.From(100, "PLN"));

    // Assert
    Assert.True(result.IsSuccess);
    Assert.Contains(auction.DomainEvents,
        e => e is BidAccepted);
}
```

**Application Layer (Integration Tests)**:
```csharp
[Fact]
public async Task CreateAuction_Should_Publish_Event()
{
    // Arrange
    var command = new CreateAuctionCommand { /* ... */ };

    // Act
    var result = await _handler.Handle(command, CancellationToken.None);

    // Assert
    Assert.True(result.IsSuccess);
    _eventBusMock.Verify(x =>
        x.PublishAsync(It.IsAny<AuctionCreated>()),
        Times.Once);
}
```

**API Layer (E2E Tests)**:
```csharp
[Fact]
public async Task Customer_Can_Browse_And_Bid()
{
    // Arrange
    await AuthenticateAsCustomer();
    var auction = await CreateTestAuction();

    // Act
    var auctions = await GetAsync<List<AuctionDto>>("/api/auctions");
    var bidResult = await PostAsync($"/api/auctions/{auction.Id}/bids",
        new { bidPrice = 100 });

    // Assert
    Assert.NotEmpty(auctions);
    Assert.Equal(HttpStatusCode.OK, bidResult.StatusCode);
}
```

#### S.2.3 Test Data Management
**Requirement**: Test data MUSI być isolated i repeatable

**Acceptance Criteria**:
- [ ] Test database per developer (localdb lub Docker)
- [ ] Integration tests używają TestContainers (Docker SQL)
- [ ] Database seeded z known test data
- [ ] Tests cleanup after themselves (transactions rolled back)
- [ ] Test builders dla complex entities

**Test Database Strategy**:
```csharp
public class AuctionTestFixture : IAsyncLifetime
{
    private readonly SqlContainer _sqlContainer = new SqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public async Task InitializeAsync()
    {
        await _sqlContainer.StartAsync();
        await ApplyMigrations();
        await SeedTestData();
    }

    public async Task DisposeAsync()
    {
        await _sqlContainer.StopAsync();
    }
}
```

### S.3 Observability

#### S.3.1 Monitoring
**Requirement**: System health MUSI być continuously monitored

**Metrics to Track**:
- Application metrics: Request rate, error rate, latency (RED)
- Resource metrics: CPU, memory, disk, network
- Business metrics: Auctions created, bids placed, conversion rate
- Custom metrics: Price calculation time, SignalR connections

**Dashboards**:
1. **Platform Health**: Overall system status
2. **Tenant Health**: Per-tenant metrics
3. **Business KPIs**: Sales, conversion, engagement

**Alerts**:
```yaml
Critical Alerts (Page on-call):
- API error rate > 5% for 5 minutes
- API P95 latency > 1s for 5 minutes
- Database CPU > 90% for 5 minutes
- Failed events in DLQ > 10

Warning Alerts (Email/Slack):
- API P95 latency > 500ms for 10 minutes
- Cache hit rate < 50%
- Auction creation rate drops 50%
```

#### S.3.2 Logging
**Requirement**: Comprehensive structured logging

**Acceptance Criteria**:
- [ ] Serilog z structured logging
- [ ] Log levels: Debug, Information, Warning, Error, Critical
- [ ] Correlation IDs dla distributed tracing
- [ ] Sensitive data NEVER logged (PII, passwords, tokens)
- [ ] Logs forwarded do Application Insights
- [ ] Log retention: 90 days

**Log Structure**:
```csharp
_logger.LogInformation(
    "Bid placed: {BidId} on Auction {AuctionId} by User {UserId} " +
    "at Price {Price} | CorrelationId: {CorrelationId}",
    bidId, auctionId, userId, price, correlationId);
```

**Log Levels**:
- **Debug**: Detailed flow (dev only)
- **Information**: Key events (auction created, bid placed)
- **Warning**: Recoverable issues (retry successful)
- **Error**: Failures (API error, database timeout)
- **Critical**: System failures (service down)

#### S.3.3 Distributed Tracing
**Requirement**: Request flow MUSI być traceable across services

**Acceptance Criteria**:
- [ ] OpenTelemetry instrumentation
- [ ] Application Insights distributed tracing
- [ ] Correlation ID propagated przez headers
- [ ] Traces include: API → Service Bus → Event Handlers
- [ ] Traces visualized w Application Map

**Implementation**:
```csharp
// Middleware auto-generates correlation ID
app.UseCorrelationId();

// Propagate to downstream calls
_httpClient.DefaultRequestHeaders.Add("X-Correlation-ID", correlationId);

// Include w logs
using (_logger.BeginScope(new Dictionary<string, object>
{
    ["CorrelationId"] = correlationId,
    ["TenantId"] = tenantId
}))
{
    _logger.LogInformation("Processing auction creation");
}
```

### S.4 Deployability

#### S.4.1 CI/CD Pipeline
**Requirement**: Automated deployment pipeline

**Pipeline Stages**:
```
1. Build
   - Restore dependencies
   - Compile code
   - Run static analysis (SonarQube)

2. Test
   - Run unit tests
   - Run integration tests
   - Generate code coverage report
   - Quality gate check

3. Package
   - Build Docker images (optional)
   - Create deployment artifacts

4. Deploy to Staging
   - Apply database migrations
   - Deploy application
   - Run smoke tests
   - Health check validation

5. Manual Approval
   - Product Owner approves
   - Release notes reviewed

6. Deploy to Production
   - Blue-green deployment
   - Database migrations (backward compatible)
   - Smoke tests
   - Monitor for errors
   - Automatic rollback on failure
```

**Tools**:
- Azure DevOps lub GitHub Actions
- Azure App Service deployment slots
- Entity Framework Core Migrations

#### S.4.2 Database Migrations
**Requirement**: Schema changes MUSZĄ być versioned i reversible

**Acceptance Criteria**:
- [ ] EF Core Migrations dla all schema changes
- [ ] Migrations tested na staging before prod
- [ ] Backward compatible migrations (expand/contract pattern)
- [ ] Migration rollback plan documented
- [ ] Data migrations separated from schema migrations
- [ ] Migrations run automatically w deployment pipeline

**Expand/Contract Pattern**:
```
Phase 1 (Expand): Add new column, keep old column
Phase 2 (Migrate): Dual-write to both columns
Phase 3 (Contract): Remove old column after all apps deployed
```

**Migration Example**:
```csharp
public partial class AddAuctionStatus : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "Status",
            table: "Auctions",
            type: "nvarchar(50)",
            nullable: false,
            defaultValue: "Draft");

        migrationBuilder.CreateIndex(
            name: "IX_Auctions_Status",
            table: "Auctions",
            column: "Status");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_Auctions_Status",
            table: "Auctions");

        migrationBuilder.DropColumn(
            name: "Status",
            table: "Auctions");
    }
}
```

---

## + (Additional Constraints)

### Design Constraints

#### DC.1 Domain-Driven Design
**Requirement**: System MUSI follow DDD tactical patterns

**Acceptance Criteria**:
- [ ] Bounded Contexts clearly defined i isolated
- [ ] Aggregates enforce invariants
- [ ] Value Objects dla domain concepts
- [ ] Domain Events dla cross-context communication
- [ ] Ubiquitous Language w kodzie i dokumentacji
- [ ] Repository pattern dla aggregate persistence
- [ ] No domain logic w controllers

**Aggregate Rules**:
- One transaction per aggregate
- References by ID only (no navigation properties across aggregates)
- Eventual consistency between aggregates
- Optimistic locking dla concurrency control

#### DC.2 CQRS Pattern
**Requirement**: Read i write models MUSZĄ być separated

**Acceptance Criteria**:
- [ ] Command handlers modify aggregates
- [ ] Query handlers read from read models
- [ ] Read models denormalized dla performance
- [ ] Read models updated przez event handlers
- [ ] MediatR dla command/query dispatch
- [ ] Commands return Result<T>, nie DTOs

**Command vs Query**:
```csharp
// Command - modifies state
public sealed record CreateAuctionCommand : IRequest<Result<AuctionId>>
{
    public string Title { get; init; }
    // ... other properties
}

// Query - reads state
public sealed record GetActiveAuctionsQuery : IRequest<Result<List<AuctionDto>>>
{
    public TenantId TenantId { get; init; }
    public int Skip { get; init; }
    public int Take { get; init; }
}
```

### Implementation Constraints

#### IC.1 Technology Stack
**Requirement**: Standardized tech stack

**Backend**:
- .NET 8 (LTS)
- C# 12
- ASP.NET Core Web API
- Entity Framework Core 8
- MediatR dla CQRS
- Polly dla resilience
- FluentValidation dla input validation
- Serilog dla logging
- xUnit + FluentAssertions + Moq dla testing

**Frontend**:
- React 18+
- TypeScript 5+
- Vite dla bundling
- TanStack Query (react-query) dla data fetching
- Zustand lub Jotai dla state management
- TailwindCSS dla styling
- React Hook Form + Zod dla forms
- Vitest + React Testing Library dla testing

**Infrastructure**:
- Azure SQL Database
- Azure Service Bus
- Azure SignalR Service
- Azure Redis Cache
- Azure Blob Storage
- Azure Key Vault
- Application Insights

#### IC.2 Code Organization
**Requirement**: Consistent project structure

**Solution Structure**:
```
src/
├── Shared/
│   ├── Domain/                 # Shared kernel
│   │   ├── TenantId.cs
│   │   ├── Money.cs
│   │   └── Result.cs
│   ├── Infrastructure/
│   │   ├── EventBus/
│   │   └── Persistence/
│   └── Application/
│       └── Abstractions/
├── Contexts/
│   ├── Auction/
│   │   ├── Domain/            # Pure domain logic
│   │   │   ├── Aggregates/
│   │   │   ├── ValueObjects/
│   │   │   ├── Events/
│   │   │   └── Services/
│   │   ├── Application/       # Use cases
│   │   │   ├── Commands/
│   │   │   ├── Queries/
│   │   │   └── EventHandlers/
│   │   ├── Infrastructure/    # External concerns
│   │   │   ├── Persistence/
│   │   │   └── Repositories/
│   │   └── API/               # HTTP endpoints
│   ├── Inventory/
│   ├── ProductCatalog/
│   ├── Bidding/
│   ├── Reservation/
│   └── TenantManagement/
└── Tests/
    ├── UnitTests/
    ├── IntegrationTests/
    └── E2ETests/
```

**Per Bounded Context**:
- Separate database schema
- Separate Azure App Service (optional dla MVP - można shared)
- Clear API boundaries
- No direct database access across contexts

#### IC.3 Data Schema Isolation
**Requirement**: Each bounded context MUSI mieć isolated schema

**Acceptance Criteria**:
- [ ] Separate database schemas: `Auction`, `Inventory`, `ProductCatalog`, etc.
- [ ] No foreign keys across schemas
- [ ] Integration przez events tylko
- [ ] Read models mogą denormalize dane z innych contexts

**Schema Organization**:
```sql
-- Separate schemas per context
CREATE SCHEMA Auction;
CREATE SCHEMA Inventory;
CREATE SCHEMA ProductCatalog;
CREATE SCHEMA Bidding;
CREATE SCHEMA Reservation;
CREATE SCHEMA TenantManagement;

-- Tables w dedicated schemas
CREATE TABLE Auction.Auctions (...);
CREATE TABLE Inventory.InventoryItems (...);
CREATE TABLE ProductCatalog.ProductModels (...);

-- NO cross-schema foreign keys!
-- Integration przez events i denormalization
```

**Cross-Context References**:
```csharp
// ❌ BAD: Direct reference across contexts
public class Auction
{
    public InventoryItem Item { get; set; } // NO!
}

// ✅ GOOD: Reference by ID only
public class Auction
{
    public InventoryItemId ItemId { get; private set; } // YES!
}
```

### Interface Constraints

#### IF.1 API Versioning
**Requirement**: API MUSI być versioned dla backward compatibility

**Acceptance Criteria**:
- [ ] URL versioning: `/api/v1/auctions`
- [ ] Version w route attribute
- [ ] Deprecation warnings w response headers
- [ ] Minimum 6 months deprecation period
- [ ] API documentation per version

**Implementation**:
```csharp
[ApiController]
[Route("api/v1/auctions")]
public class AuctionsV1Controller : ControllerBase
{
    // V1 implementation
}

[ApiController]
[Route("api/v2/auctions")]
public class AuctionsV2Controller : ControllerBase
{
    // V2 with breaking changes
}
```

#### IF.2 API Documentation
**Requirement**: API MUSI być self-documenting

**Acceptance Criteria**:
- [ ] Swagger/OpenAPI spec auto-generated
- [ ] All endpoints documented
- [ ] Request/response examples provided
- [ ] Error codes documented
- [ ] Authentication requirements stated
- [ ] Swagger UI available na /swagger

**OpenAPI Annotations**:
```csharp
/// <summary>
/// Creates a new auction
/// </summary>
/// <param name="request">Auction creation details</param>
/// <returns>Created auction ID</returns>
/// <response code="201">Auction created successfully</response>
/// <response code="400">Invalid request data</response>
/// <response code="401">Unauthorized</response>
[HttpPost]
[ProducesResponseType(typeof(AuctionCreatedResponse), StatusCodes.Status201Created)]
[ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
public async Task<IActionResult> CreateAuction([FromBody] CreateAuctionRequest request)
{
    // ...
}
```

### Physical Constraints

#### PH.1 Multi-Region Support (Future)
**Requirement**: Architecture MUSI allow expansion do multiple regions

**Considerations**:
- [ ] Data residency requirements (GDPR)
- [ ] Geo-replication strategy
- [ ] Latency optimization (CDN dla frontend)
- [ ] Conflict resolution dla multi-master writes

**Not required dla MVP, ale architecture should not preclude it**

#### PH.2 Cost Optimization
**Requirement**: Infrastructure cost MUSI być monitored i optimized

**Targets**:
- Development: < $500/month
- Production (MVP): < $3000/month
- Production (Scale): < $10,000/month

**Strategies**:
- [ ] Azure Cost Management alerts
- [ ] Auto-scaling rules (scale down off-peak)
- [ ] Reserved instances dla predictable workloads
- [ ] Blob storage lifecycle policies (move to cool tier after 30 days)
- [ ] Database DTU right-sizing

---

## NFR Validation Matrix

| NFR Category | Measurement Method | Target | Monitoring |
|--------------|-------------------|--------|------------|
| API Latency | Application Insights | P95 < 200ms | Dashboard |
| Availability | Uptime checks | 99.5% | StatusPage |
| Error Rate | Exception tracking | < 1% | Alerts |
| Test Coverage | Code coverage tool | > 80% | CI/CD gate |
| Security | Penetration testing | OWASP compliance | Quarterly |
| Scalability | Load testing | 1000 concurrent | Pre-release |
| Database Performance | Query Store | No query > 1s | Alerts |

---

## Review & Updates

**Review Frequency**: Quarterly
**Owner**: Lead Architect + Product Owner
**Process**:
1. Review NFR compliance
2. Update targets based on actual usage
3. Add new NFRs as system evolves
4. Archive obsolete NFRs

**Last Updated**: 2025-01-24
**Next Review**: 2025-04-24
