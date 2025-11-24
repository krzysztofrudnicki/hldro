# Tech Stack Details

## Backend Stack

### .NET 8 / C#

**Version**: .NET 8 (LTS - Long Term Support until November 2026)

**Why .NET 8**:
- Performance improvements over .NET 6/7
- Native AOT compilation support
- Enhanced minimal APIs
- Improved observability (OpenTelemetry)
- LTS support dla production stability

### Project Structure (Per Microservice)

```
ServiceName/
├── ServiceName.Domain/              # Domain layer (DDD)
│   ├── Aggregates/
│   ├── Entities/
│   ├── ValueObjects/
│   ├── DomainEvents/
│   ├── DomainServices/
│   └── Exceptions/
├── ServiceName.Application/         # Application layer (CQRS)
│   ├── Commands/
│   ├── Queries/
│   ├── Handlers/
│   ├── Services/
│   └── DTOs/
├── ServiceName.Infrastructure/      # Infrastructure layer
│   ├── Persistence/
│   │   ├── Repositories/
│   │   ├── EntityConfigurations/
│   │   └── Migrations/
│   ├── EventBus/
│   ├── ExternalServices/
│   └── Identity/
└── ServiceName.API/                 # Presentation layer
    ├── Controllers/
    ├── Middlewares/
    ├── Hubs/ (SignalR)
    └── Program.cs
```

### Key Libraries

#### Domain Layer
```xml
<PackageReference Include="MediatR" Version="12.x" />
<!-- For domain events and CQRS patterns -->
```

#### Application Layer
```xml
<PackageReference Include="FluentValidation" Version="11.x" />
<!-- Input validation -->
<PackageReference Include="AutoMapper" Version="12.x" />
<!-- DTO mapping -->
<PackageReference Include="MediatR" Version="12.x" />
<!-- Command/Query handlers -->
```

#### Infrastructure Layer
```xml
<PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.x" />
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.x" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.x" />
<!-- EF Core for persistence -->

<PackageReference Include="Azure.Messaging.ServiceBus" Version="7.x" />
<!-- Event bus (Service Bus) -->

<PackageReference Include="Microsoft.AspNetCore.SignalR.Client" Version="8.x" />
<PackageReference Include="Microsoft.Azure.SignalR" Version="1.x" />
<!-- Real-time communication -->

<PackageReference Include="StackExchange.Redis" Version="2.x" />
<!-- Caching and viewer tracking -->

<PackageReference Include="Polly" Version="8.x" />
<!-- Retry policies, circuit breakers -->

<PackageReference Include="Serilog" Version="3.x" />
<PackageReference Include="Serilog.Sinks.ApplicationInsights" Version="4.x" />
<!-- Structured logging -->
```

#### API Layer
```xml
<PackageReference Include="Swashbuckle.AspNetCore" Version="6.x" />
<!-- OpenAPI/Swagger -->

<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="8.x" />
<!-- JWT authentication -->
```

---

## Frontend Stack

### React 18+

**Version**: React 18.2+

**Why React**:
- Component-based architecture
- Excellent ecosystem
- Strong TypeScript support
- Real-time capabilities (hooks)
- Large talent pool

### Project Structure

```
frontend/
├── src/
│   ├── components/          # Reusable UI components
│   │   ├── auction/
│   │   ├── common/
│   │   └── layout/
│   ├── features/            # Feature-based modules
│   │   ├── auctions/
│   │   ├── catalog/
│   │   └── checkout/
│   ├── hooks/               # Custom React hooks
│   ├── services/            # API clients
│   ├── store/               # State management
│   ├── types/               # TypeScript types
│   ├── utils/
│   └── App.tsx
├── public/
└── package.json
```

### Key Dependencies

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "typescript": "^5.0.0",
    
    // State Management
    "zustand": "^4.4.0",
    // Simple, fast, scalable state management
    
    // Routing
    "react-router-dom": "^6.16.0",
    
    // API Client
    "axios": "^1.5.0",
    "react-query": "^3.39.0",
    // Data fetching, caching, synchronization
    
    // Real-time
    "@microsoft/signalr": "^7.0.0",
    // SignalR client
    
    // UI Components (if using library)
    "tailwindcss": "^3.3.0",
    // Utility-first CSS
    
    // Forms
    "react-hook-form": "^7.46.0",
    "zod": "^3.22.0",
    // Form validation
    
    // Date/Time
    "date-fns": "^2.30.0",
    
    // Utilities
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "vite": "^4.4.0",
    "vitest": "^0.34.0",
    "eslint": "^8.49.0",
    "prettier": "^3.0.0"
  }
}
```

---

## Azure Services

### Compute

#### Azure App Service
**Usage**: Hosting dla microservices APIs
- Plan: Premium P1V3 (dla production)
- Auto-scaling: 2-10 instances based on CPU/memory
- Always On: Enabled
- Deployment: Blue-green deployment slots

#### Azure Functions (Optional dla niektórych services)
**Usage**: Background jobs (price drop publisher, reservation timeout)
- Plan: Consumption lub Premium
- Trigger: Time-based (Timer Trigger)

### Data Storage

#### Azure SQL Database
**Usage**: Primary storage dla command side (CQRS)
- Tier: General Purpose (provisioned)
- Size: Standard S2 initially, scale as needed
- Backup: Point-in-time restore (7-35 days)
- Geo-replication: Optional dla HA

**Databases**:
- `AuctionDB` - Auction Context
- `InventoryDB` - Inventory Context
- `ProductCatalogDB` - Product Catalog Context
- `TenantDB` - Tenant Management Context
- Etc.

**Rationale**: Jeden database per bounded context (logical separation)

#### Azure Cosmos DB (Optional dla read side)
**Usage**: CQRS read models dla fast queries
- API: SQL API
- Consistency: Session (default) lub Eventual
- Partitioning: By TenantId
- Throughput: Autoscale RU/s

**Collections**:
- `AuctionListView` - Fast auction browsing
- `InventoryAvailability` - Stock queries

#### Azure Blob Storage
**Usage**: Media storage (product images, documents)
- Tier: Hot dla frequently accessed images
- CDN: Azure CDN dla global distribution
- Lifecycle policies: Move to Cool tier after 30 days

#### Azure Redis Cache
**Usage**: 
- Price calculation cache (short TTL)
- Viewer tracking (in-memory sets)
- Session storage
- Distributed cache dla scalability

**Tier**: Standard C1 (dla MVP), Premium dla HA

### Messaging & Events

#### Azure Service Bus
**Usage**: Event-driven communication between bounded contexts
- Tier: Standard (dla topics and subscriptions)
- Topics: Per event type lub per bounded context
- Subscriptions: Per subscriber with filters

**Topics**:
- `auction-events` - All auction events
- `inventory-events` - All inventory events
- Etc.

**Subscriptions** (example):
- `inventory-service` subscribes to `auction-events/BidAccepted`
- `bidding-service` subscribes to `auction-events/PriceDropped`

#### Azure SignalR Service
**Usage**: Real-time WebSocket connections dla frontend
- Tier: Standard S1 (1000 concurrent connections)
- Scale: Auto-scale dla high traffic
- Authentication: JWT tokens

### Security & Identity

#### Azure Active Directory (Azure AD)
**Usage**: Authentication dla admin/seller users
- B2C dla customer authentication (future)

#### Azure Key Vault
**Usage**: Secrets management
- API keys (e-commerce integration)
- Connection strings
- Certificates

### Monitoring & Observability

#### Azure Application Insights
**Usage**: APM, logging, monitoring
- Telemetry dla all services
- Custom metrics (auction performance, bid success rate)
- Distributed tracing
- Live metrics
- Alerts

#### Azure Monitor
**Usage**: Infrastructure monitoring
- Log Analytics Workspace
- Custom dashboards
- Alerts (CPU, memory, errors)

### Networking

#### Azure Virtual Network (Optional dla enhanced security)
**Usage**: Network isolation
- Private endpoints dla databases
- VNet integration dla App Services

#### Azure CDN
**Usage**: Static content delivery
- Product images
- Frontend static assets
- Edge caching

---

## Development Tools

### IDE
- **Visual Studio 2022** (Windows) lub **Rider** (cross-platform)
- **Visual Studio Code** (dla frontend + lightweight backend)

### Version Control
- **Git** + **Azure DevOps Repos** lub **GitHub**

### CI/CD
- **Azure DevOps Pipelines** lub **GitHub Actions**
- Build → Test → Deploy to staging → Deploy to production

### Container (Optional dla advanced scenarios)
- **Docker** dla local development consistency
- **Azure Container Registry** jeśli używamy containers
- **Azure Kubernetes Service** (overkill dla MVP, consider dla scale)

---

## Database Design Principles

### Entity Framework Core Migrations
```bash
# Add migration
dotnet ef migrations add InitialCreate --project Infrastructure --startup-project API

# Update database
dotnet ef database update --project Infrastructure --startup-project API
```

### Conventions
- Table naming: `Auctions`, `InventoryItems` (plural)
- Primary key: `Id` (Guid)
- Foreign key: `TenantId`, `ProductModelId` (descriptive)
- Timestamps: `CreatedAt`, `UpdatedAt` (UTC)
- Soft deletes: `IsDeleted`, `DeletedAt` (optional)

---

## API Design

### RESTful Conventions
```
GET    /api/auctions              - List auctions
GET    /api/auctions/{id}         - Get auction details
POST   /api/auctions              - Create auction
PUT    /api/auctions/{id}         - Update auction
DELETE /api/auctions/{id}         - Delete auction
POST   /api/auctions/{id}/publish - Custom action
```

### CQRS Endpoints
```
// Commands
POST   /api/auctions/{id}/commands/place-bid
POST   /api/auctions/{id}/commands/cancel

// Queries
GET    /api/auctions/{id}/queries/current-price
GET    /api/auctions/queries/active
```

### Versioning
- URL versioning: `/api/v1/auctions`
- Header versioning: `Accept: application/json; version=1`

### Response Format
```json
{
  "success": true,
  "data": { ... },
  "errors": null
}
```

---

## Performance Targets (SLIs)

| Metric | Target |
|--------|--------|
| API Response Time (p95) | < 200ms |
| Price Calculation | < 10ms |
| Bid Processing | < 100ms |
| Real-time Push Latency | < 500ms |
| Database Query (p95) | < 50ms |
| Page Load Time | < 2s |

---

## Scalability Targets

| Metric | Target |
|--------|--------|
| Concurrent Users | 10,000+ |
| Active Auctions | 1,000+ |
| Bids/second | 100+ |
| WebSocket Connections | 10,000+ |
| Database TPS | 1,000+ |
