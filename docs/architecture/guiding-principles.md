# Architecture Guiding Principles

## Document Purpose

Ten dokument definiuje **fundamentalne zasady architektoniczne** dla Reverse Auction Platform. Każdy developer/agent pracujący nad tym projektem MUSI przestrzegać tych principles.

**Priorytet zasad**: Jeśli zasady są w konflikcie, priorytet określa kolejność w dokumencie (wcześniejsze > późniejsze).

---

## Core Principles (Najwyższy Priorytet)

### P1: Domain-First Design 🎯

**Principle**: Domain logic jest najważniejsza i najbardziej chroniona warstwa systemu.

**Rules**:
1. **Domain layer NIE może zależeć od innych layers**
   - ❌ NO: Infrastructure, Application, API dependencies w Domain
   - ✅ YES: Pure C# classes, no external package references (except abstractions)

2. **Business logic TYLKO w Domain layer**
   ```csharp
   // ❌ BAD: Business logic w controller
   [HttpPost]
   public async Task<IActionResult> CreateAuction(CreateAuctionRequest request)
   {
       if (request.StartPrice <= request.EndPrice)  // Business logic leak!
           return BadRequest();
       // ...
   }

   // ✅ GOOD: Business logic w aggregate
   public sealed class Auction : AggregateRoot<AuctionId>
   {
       public static Result<Auction> Create(...)
       {
           if (startPrice <= endPrice)
               return Result.Failure("Start price must be greater than end price");
           // ...
       }
   }
   ```

3. **Aggregates enforce invariants**
   - All mutations przez public methods
   - Private setters only
   - Validation w constructor/factory methods
   - DomainEvents dla side effects

4. **Ubiquitous Language**
   - Używamy domain terms w kodzie: `Auction`, `Bid`, `InventoryItem`, nie `AuctionEntity`, `BidRecord`
   - Class/method names match business concepts
   - Avoid technical jargon w domain models

**Validation**:
```csharp
// ✅ Example of well-structured aggregate
public sealed class Auction : AggregateRoot<AuctionId>
{
    public TenantId TenantId { get; private set; }
    public AuctionTitle Title { get; private set; }
    public AuctionStatus Status { get; private set; }
    public PriceSchedule PriceSchedule { get; private set; }

    private readonly List<AuctionItem> _items = new();
    public IReadOnlyCollection<AuctionItem> Items => _items.AsReadOnly();

    // Factory method enforces invariants
    public static Result<Auction> Create(
        TenantId tenantId,
        AuctionTitle title,
        PriceSchedule priceSchedule,
        DateTime endAt)
    {
        // Validation
        if (endAt <= DateTime.UtcNow)
            return Result.Failure("EndAt must be in the future");

        var auction = new Auction
        {
            Id = AuctionId.Create(),
            TenantId = tenantId,
            Title = title,
            PriceSchedule = priceSchedule,
            Status = AuctionStatus.Draft,
            // ...
        };

        auction.AddDomainEvent(new AuctionCreated { /* ... */ });
        return Result.Success(auction);
    }

    // Commands modify state
    public Result Publish()
    {
        if (Status != AuctionStatus.Draft)
            return Result.Failure("Only draft auctions can be published");

        if (_items.Count == 0)
            return Result.Failure("Cannot publish auction without items");

        Status = AuctionStatus.Active;
        PublishedOn = DateTime.UtcNow;

        AddDomainEvent(new AuctionPublished { /* ... */ });
        return Result.Success();
    }

    // Queries read state
    public Money CalculateCurrentPrice(DateTime asOf) =>
        PriceSchedule.CalculatePrice(PublishedOn!.Value, asOf);
}
```

---

### P2: Bounded Context Isolation 🔒

**Principle**: Bounded Contexts są autonomiczne i komunikują się tylko przez events.

**Rules**:
1. **Separate schemas per context**
   ```sql
   CREATE SCHEMA Auction;
   CREATE SCHEMA Inventory;
   CREATE SCHEMA ProductCatalog;
   CREATE SCHEMA Bidding;
   ```

2. **NO cross-schema joins**
   ```sql
   -- ❌ BAD: Join across contexts
   SELECT a.Title, i.SerialNumber
   FROM Auction.Auctions a
   JOIN Inventory.InventoryItems i ON a.ItemId = i.Id;  -- NO!

   -- ✅ GOOD: Denormalize w read model
   SELECT Title, ItemSerialNumber  -- Denormalized
   FROM Auction.AuctionListView;
   ```

3. **NO direct repository calls across contexts**
   ```csharp
   // ❌ BAD: Auction context accessing Inventory repository
   public class CreateAuctionCommandHandler
   {
       private readonly IInventoryItemRepository _inventoryRepo;  // NO!

       public async Task Handle(CreateAuctionCommand command)
       {
           var item = await _inventoryRepo.GetByIdAsync(command.ItemId); // NO!
       }
   }

   // ✅ GOOD: Query via denormalized read model
   public class CreateAuctionCommandHandler
   {
       private readonly IAuctionReadService _readService;

       public async Task Handle(CreateAuctionCommand command)
       {
           var itemAvailable = await _readService
               .IsItemAvailableAsync(command.ItemId);  // Read model query

           if (!itemAvailable)
               return Result.Failure("Item not available");
       }
   }
   ```

4. **Integration przez Domain Events only**
   ```csharp
   // Auction Context publishes event
   public sealed record BidAccepted : IDomainEvent
   {
       public AuctionId AuctionId { get; init; }
       public InventoryItemId ItemId { get; init; }
       public UserId WinnerId { get; init; }
   }

   // Inventory Context subscribes
   public class BidAcceptedEventHandler : IEventHandler<BidAccepted>
   {
       public async Task HandleAsync(BidAccepted @event)
       {
           var item = await _repository.GetByIdAsync(@event.ItemId);
           item.Reserve(/* ... */);
           await _repository.SaveAsync(item);
       }
   }
   ```

5. **Shared Kernel minimized**
   - Only truly shared concepts: `TenantId`, `Money`, `Result<T>`
   - No business logic w shared kernel
   - Value objects only

**Validation Checklist**:
- [ ] Each context ma własny folder w `src/Contexts/`
- [ ] Each context ma własny database schema
- [ ] No project references between contexts (except Shared.Domain)
- [ ] Integration tests verify event-based communication

---

### P3: CQRS Separation ⚖️

**Principle**: Commands (write) i Queries (read) są separated dla performance i clarity.

**Rules**:
1. **Commands modify state, return Result<T>**
   ```csharp
   // Command
   public sealed record CreateAuctionCommand : IRequest<Result<AuctionId>>
   {
       public TenantId TenantId { get; init; }
       public string Title { get; init; }
       // ... other data
   }

   // Handler modifies aggregate
   public class CreateAuctionCommandHandler
       : IRequestHandler<CreateAuctionCommand, Result<AuctionId>>
   {
       public async Task<Result<AuctionId>> Handle(
           CreateAuctionCommand command,
           CancellationToken ct)
       {
           var auction = Auction.Create(/* ... */);
           await _repository.SaveAsync(auction);
           return Result.Success(auction.Id);
       }
   }
   ```

2. **Queries read denormalized models, return DTOs**
   ```csharp
   // Query
   public sealed record GetActiveAuctionsQuery
       : IRequest<Result<List<AuctionListDto>>>
   {
       public TenantId TenantId { get; init; }
       public int Skip { get; init; }
       public int Take { get; init; }
   }

   // Handler reads from read model
   public class GetActiveAuctionsQueryHandler
       : IRequestHandler<GetActiveAuctionsQuery, Result<List<AuctionListDto>>>
   {
       public async Task<Result<List<AuctionListDto>>> Handle(
           GetActiveAuctionsQuery query,
           CancellationToken ct)
       {
           // Read from denormalized view
           var auctions = await _readRepository
               .GetActiveAuctionsAsync(query.TenantId, query.Skip, query.Take);

           var dtos = auctions.Select(a => new AuctionListDto
           {
               AuctionId = a.AuctionId,
               Title = a.Title,
               CurrentPrice = a.CurrentPrice,  // Pre-calculated
               // ...
           }).ToList();

           return Result.Success(dtos);
       }
   }
   ```

3. **Read models updated przez events**
   ```csharp
   public class AuctionPublishedEventHandler
       : IEventHandler<AuctionPublished>
   {
       private readonly IAuctionReadRepository _readRepository;

       public async Task HandleAsync(AuctionPublished @event)
       {
           // Update denormalized read model
           var readModel = new AuctionListReadModel
           {
               AuctionId = @event.AuctionId,
               TenantId = @event.TenantId,
               Title = @event.Title,
               CurrentPrice = @event.StartPrice,
               RemainingItems = @event.TotalItemsCount,
               // Denormalize product data
               MainImageUrl = await _productService
                   .GetMainImageUrlAsync(@event.ProductModelId),
               // ...
           };

           await _readRepository.InsertOrUpdateAsync(readModel);
       }
   }
   ```

4. **NO business logic w query handlers**
   ```csharp
   // ❌ BAD: Business logic w query
   public class GetCurrentPriceQueryHandler
   {
       public async Task<decimal> Handle(GetCurrentPriceQuery query)
       {
           var auction = await _repo.GetByIdAsync(query.AuctionId);

           // NO! Business logic here
           var elapsed = DateTime.UtcNow - auction.PublishedOn;
           var drops = elapsed.TotalSeconds / auction.DropInterval;
           return auction.StartPrice - (drops * auction.PricePerDrop);
       }
   }

   // ✅ GOOD: Query returns pre-calculated value
   public class GetCurrentPriceQueryHandler
   {
       public async Task<decimal> Handle(GetCurrentPriceQuery query)
       {
           var readModel = await _readRepo.GetByIdAsync(query.AuctionId);
           return readModel.CurrentPrice;  // Pre-calculated w read model
       }
   }
   ```

**Command/Query Checklist**:
- [ ] Commands w `Application/Commands/` folder
- [ ] Queries w `Application/Queries/` folder
- [ ] Commands return `Result<T>`, nie DTOs
- [ ] Queries return DTOs
- [ ] Read models w separate tables (lub Cosmos DB)
- [ ] Event handlers update read models

---

### P4: Event-Driven Communication 📡

**Principle**: Loose coupling przez asynchronous domain events.

**Rules**:
1. **Domain Events for significant state changes**
   ```csharp
   public sealed record AuctionPublished : IDomainEvent
   {
       public Guid EventId { get; init; }
       public DateTime OccurredOn { get; init; }
       public TenantId TenantId { get; init; }

       public AuctionId AuctionId { get; init; }
       public string Title { get; init; }
       public decimal StartPrice { get; init; }
       // ... event data
   }
   ```

2. **Events are immutable records**
   ```csharp
   // ✅ GOOD: Immutable record
   public sealed record ItemSold : IDomainEvent
   {
       public Guid EventId { get; init; }
       // ... properties with init only
   }

   // ❌ BAD: Mutable class
   public class ItemSold : IDomainEvent
   {
       public Guid EventId { get; set; }  // NO! Should be init-only
   }
   ```

3. **Outbox Pattern for reliable publishing**
   ```csharp
   public async Task SaveAsync(Auction auction)
   {
       using var transaction = await _dbContext.Database
           .BeginTransactionAsync();

       try
       {
           // 1. Save aggregate
           _dbContext.Auctions.Update(auction);

           // 2. Save events to outbox (same transaction!)
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

   // Background job publishes from outbox
   public class OutboxProcessor : BackgroundService
   {
       protected override async Task ExecuteAsync(CancellationToken ct)
       {
           while (!ct.IsCancellationRequested)
           {
               var unpublished = await _repo.GetUnpublishedMessagesAsync();

               foreach (var message in unpublished)
               {
                   await _serviceBus.PublishAsync(message.EventData);
                   message.ProcessedOn = DateTime.UtcNow;
                   await _repo.SaveAsync(message);
               }

               await Task.Delay(TimeSpan.FromSeconds(5), ct);
           }
       }
   }
   ```

4. **Event Handlers MUST be idempotent**
   ```csharp
   public class ItemReservedEventHandler : IEventHandler<ItemReserved>
   {
       public async Task HandleAsync(ItemReserved @event)
       {
           // Check if already processed
           var processed = await _eventLog.HasProcessedAsync(
               @event.EventId,
               nameof(ItemReservedEventHandler));

           if (processed)
           {
               _logger.LogInformation(
                   "Event {EventId} already processed, skipping",
                   @event.EventId);
               return;
           }

           // Process event
           await ProcessEventAsync(@event);

           // Mark as processed
           await _eventLog.MarkAsProcessedAsync(
               @event.EventId,
               nameof(ItemReservedEventHandler));
       }
   }
   ```

5. **Events contain sufficient data**
   ```csharp
   // ❌ BAD: Insufficient data, subscriber musi query
   public sealed record ItemSold : IDomainEvent
   {
       public InventoryItemId ItemId { get; init; }  // Only ID
   }

   // ✅ GOOD: Sufficient data for subscribers
   public sealed record ItemSold : IDomainEvent
   {
       public InventoryItemId ItemId { get; init; }
       public ProductModelId ProductModelId { get; init; }
       public UserId BuyerId { get; init; }
       public decimal SoldPrice { get; init; }
       public string Currency { get; init; }
       public DateTime SoldOn { get; init; }
       // Subscribers don't need to query!
   }
   ```

**Event Guidelines**:
- Event names: past tense (AuctionPublished, BidAccepted)
- Events są facts - nie można ich "cancel"
- Retry policy: 3 attempts, exponential backoff
- Dead Letter Queue dla permanently failed events
- Events stored w OutboxMessages table dla audit trail

---

### P5: Fail-Fast Validation ⚠️

**Principle**: Validate early, fail explicitly, never save invalid state.

**Rules**:
1. **Value Objects enforce invariants w constructor**
   ```csharp
   public sealed class AuctionTitle : ValueObject
   {
       public string Value { get; }

       private AuctionTitle(string value)
       {
           // Fail fast w constructor
           if (string.IsNullOrWhiteSpace(value))
               throw new ArgumentException(
                   "Auction title cannot be empty",
                   nameof(value));

           if (value.Length < 10)
               throw new ArgumentException(
                   "Auction title must be at least 10 characters",
                   nameof(value));

           if (value.Length > 200)
               throw new ArgumentException(
                   "Auction title cannot exceed 200 characters",
                   nameof(value));

           Value = value.Trim();
       }

       public static AuctionTitle From(string value) => new(value);

       protected override IEnumerable<object> GetEqualityComponents()
       {
           yield return Value;
       }
   }
   ```

2. **FluentValidation dla input DTOs**
   ```csharp
   public class CreateAuctionRequestValidator
       : AbstractValidator<CreateAuctionRequest>
   {
       public CreateAuctionRequestValidator()
       {
           RuleFor(x => x.Title)
               .NotEmpty()
               .MinimumLength(10)
               .MaximumLength(200);

           RuleFor(x => x.StartPrice)
               .GreaterThan(0)
               .LessThanOrEqualTo(1_000_000);

           RuleFor(x => x.EndPrice)
               .GreaterThan(0)
               .LessThan(x => x.StartPrice)
               .WithMessage("End price must be less than start price");

           RuleFor(x => x.EndAt)
               .GreaterThan(DateTime.UtcNow)
               .WithMessage("End date must be in the future");
       }
   }

   // Register w pipeline
   services.AddMediatR(cfg =>
   {
       cfg.RegisterServicesFromAssembly(typeof(Program).Assembly);
       cfg.AddBehavior(typeof(IPipelineBehavior<,>),
           typeof(ValidationBehavior<,>));
   });
   ```

3. **Result<T> pattern, NO exceptions dla business rule violations**
   ```csharp
   // ❌ BAD: Exception dla business rule
   public void Publish()
   {
       if (Status != AuctionStatus.Draft)
           throw new InvalidOperationException(
               "Only draft auctions can be published");
   }

   // ✅ GOOD: Result pattern
   public Result Publish()
   {
       if (Status != AuctionStatus.Draft)
           return Result.Failure(
               "INVALID_STATUS",
               "Only draft auctions can be published");

       if (_items.Count == 0)
           return Result.Failure(
               "NO_ITEMS",
               "Cannot publish auction without items");

       Status = AuctionStatus.Active;
       AddDomainEvent(new AuctionPublished { /* ... */ });

       return Result.Success();
   }
   ```

4. **Global exception handling**
   ```csharp
   app.UseExceptionHandler(errorApp =>
   {
       errorApp.Run(async context =>
       {
           var exceptionHandler = context.Features
               .Get<IExceptionHandlerFeature>();

           var exception = exceptionHandler?.Error;

           var problemDetails = exception switch
           {
               ValidationException ve => new ValidationProblemDetails(
                   ve.Errors.ToDictionary(
                       e => e.PropertyName,
                       e => new[] { e.ErrorMessage }))
               {
                   Status = StatusCodes.Status400BadRequest
               },

               DomainException de => new ProblemDetails
               {
                   Status = StatusCodes.Status400BadRequest,
                   Title = "Domain Rule Violation",
                   Detail = de.Message
               },

               _ => new ProblemDetails
               {
                   Status = StatusCodes.Status500InternalServerError,
                   Title = "An error occurred"
               }
           };

           context.Response.StatusCode = problemDetails.Status ?? 500;
           await context.Response.WriteAsJsonAsync(problemDetails);
       });
   });
   ```

**Validation Layers**:
1. **Input validation**: FluentValidation dla DTOs
2. **Domain validation**: Value objects + aggregate invariants
3. **Business rules**: Aggregate methods return Result<T>
4. **Infrastructure validation**: Database constraints

---

### P6: Testability by Design 🧪

**Principle**: Code MUSI być testable, tests są first-class citizens.

**Rules**:
1. **Dependency Injection everywhere**
   ```csharp
   // ✅ GOOD: Dependencies injected
   public class CreateAuctionCommandHandler
   {
       private readonly IAuctionRepository _repository;
       private readonly IEventPublisher _eventPublisher;
       private readonly ILogger<CreateAuctionCommandHandler> _logger;

       public CreateAuctionCommandHandler(
           IAuctionRepository repository,
           IEventPublisher eventPublisher,
           ILogger<CreateAuctionCommandHandler> logger)
       {
           _repository = repository;
           _eventPublisher = eventPublisher;
           _logger = logger;
       }
   }

   // ❌ BAD: New up dependencies
   public class CreateAuctionCommandHandler
   {
       public async Task Handle(CreateAuctionCommand command)
       {
           var repository = new AuctionRepository();  // NO!
           var logger = new ConsoleLogger();  // NO!
       }
   }
   ```

2. **Pure domain logic (no side effects w aggregates)**
   ```csharp
   // ✅ GOOD: Pure business logic, easy to test
   public sealed class Auction : AggregateRoot<AuctionId>
   {
       public Money CalculateCurrentPrice(DateTime asOf)
       {
           if (Status != AuctionStatus.Active)
               return Money.Zero(PriceSchedule.Currency);

           return PriceSchedule.CalculatePrice(PublishedOn!.Value, asOf);
       }
   }

   // Test w isolation
   [Fact]
   public void CalculateCurrentPrice_Should_Return_Correct_Price()
   {
       // Arrange
       var auction = AuctionTestBuilder.Create()
           .WithStatus(AuctionStatus.Active)
           .WithPriceSchedule(start: 1000, end: 100, duration: 1h)
           .WithPublishedOn(DateTime.UtcNow.AddMinutes(-30))
           .Build();

       // Act
       var currentPrice = auction.CalculateCurrentPrice(DateTime.UtcNow);

       // Assert
       Assert.Equal(550, currentPrice.Amount); // Halfway through
   }
   ```

3. **Test Builders dla complex objects**
   ```csharp
   public class AuctionTestBuilder
   {
       private TenantId _tenantId = TenantId.Create();
       private AuctionTitle _title = AuctionTitle.From("Test Auction Title");
       private AuctionStatus _status = AuctionStatus.Draft;
       private PriceSchedule _priceSchedule;
       private DateTime? _publishedOn;

       public static AuctionTestBuilder Create() => new();

       public AuctionTestBuilder WithTenantId(TenantId tenantId)
       {
           _tenantId = tenantId;
           return this;
       }

       public AuctionTestBuilder WithStatus(AuctionStatus status)
       {
           _status = status;
           return this;
       }

       public AuctionTestBuilder WithPublishedOn(DateTime publishedOn)
       {
           _publishedOn = publishedOn;
           return this;
       }

       public Auction Build()
       {
           var auction = Auction.Create(
               _tenantId,
               _title,
               _priceSchedule,
               DateTime.UtcNow.AddHours(1))
               .Value;

           // Use reflection dla setting private fields (test only!)
           if (_status != AuctionStatus.Draft)
           {
               typeof(Auction)
                   .GetProperty(nameof(Auction.Status))!
                   .SetValue(auction, _status);
           }

           if (_publishedOn.HasValue)
           {
               typeof(Auction)
                   .GetProperty(nameof(Auction.PublishedOn))!
                   .SetValue(auction, _publishedOn);
           }

           return auction;
       }
   }
   ```

4. **Integration tests z TestContainers**
   ```csharp
   public class AuctionRepositoryTests : IAsyncLifetime
   {
       private readonly SqlContainer _sqlContainer = new SqlBuilder()
           .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
           .Build();

       private AuctionDbContext _dbContext;

       public async Task InitializeAsync()
       {
           await _sqlContainer.StartAsync();

           var connectionString = _sqlContainer.GetConnectionString();
           var options = new DbContextOptionsBuilder<AuctionDbContext>()
               .UseSqlServer(connectionString)
               .Options;

           _dbContext = new AuctionDbContext(options);
           await _dbContext.Database.MigrateAsync();
       }

       [Fact]
       public async Task SaveAsync_Should_Persist_Auction()
       {
           // Arrange
           var repository = new AuctionRepository(_dbContext);
           var auction = AuctionTestBuilder.Create().Build();

           // Act
           await repository.SaveAsync(auction);

           // Assert
           var retrieved = await repository.GetByIdAsync(auction.Id);
           Assert.NotNull(retrieved);
           Assert.Equal(auction.Title.Value, retrieved.Title.Value);
       }

       public async Task DisposeAsync()
       {
           await _dbContext.DisposeAsync();
           await _sqlContainer.StopAsync();
       }
   }
   ```

**Test Coverage Targets**:
- Unit tests: 80%+ coverage
- Integration tests: Critical paths (bid placement, price calculation)
- E2E tests: Happy paths only
- Load tests: Before production deployment

---

## Secondary Principles

### P7: Performance by Default ⚡

**Rules**:
1. **Async/await throughout**
   ```csharp
   // ✅ GOOD: Async all the way
   public async Task<Result<AuctionId>> Handle(
       CreateAuctionCommand command,
       CancellationToken ct)
   {
       var auction = Auction.Create(/* ... */);
       await _repository.SaveAsync(auction, ct);  // Async
       await _eventPublisher.PublishAsync(/* ... */, ct);  // Async
       return Result.Success(auction.Id);
   }

   // ❌ BAD: Blocking calls
   public Result<AuctionId> Handle(CreateAuctionCommand command)
   {
       var auction = Auction.Create(/* ... */);
       _repository.SaveAsync(auction).Wait();  // NO! Blocks thread
       return Result.Success(auction.Id);
   }
   ```

2. **Indexing strategy documented**
   ```csharp
   // EF Core configuration
   protected override void OnModelCreating(ModelBuilder modelBuilder)
   {
       modelBuilder.Entity<Auction>(entity =>
       {
           entity.ToTable("Auctions", "Auction");

           entity.HasKey(e => e.Id);

           // Index dla tenant queries
           entity.HasIndex(e => new { e.TenantId, e.Status, e.PublishedOn })
               .HasDatabaseName("IX_Auctions_TenantId_Status_PublishedOn")
               .IncludeProperties(e => new { e.Title, e.CurrentPrice });

           // Partial index dla active auctions only
           entity.HasIndex(e => new { e.TenantId, e.PublishedOn })
               .HasDatabaseName("IX_Auctions_Active")
               .HasFilter("[Status] = 'Active'");
       });
   }
   ```

3. **Caching with short TTLs**
   ```csharp
   public async Task<AuctionDto> GetAuctionAsync(AuctionId id)
   {
       var cacheKey = $"auction:{id}";

       // Try cache first
       var cached = await _cache.GetAsync<AuctionDto>(cacheKey);
       if (cached != null)
       {
           _logger.LogDebug("Cache hit for auction {AuctionId}", id);
           return cached;
       }

       // Cache miss - query database
       var auction = await _repository.GetByIdAsync(id);
       var dto = MapToDto(auction);

       // Cache with short TTL
       await _cache.SetAsync(
           cacheKey,
           dto,
           TimeSpan.FromSeconds(30));  // Short TTL dla near real-time data

       return dto;
   }
   ```

4. **N+1 query detection**
   ```csharp
   // ❌ BAD: N+1 query problem
   var auctions = await _dbContext.Auctions.ToListAsync();
   foreach (var auction in auctions)
   {
       // This triggers a separate query per auction!
       var items = await _dbContext.AuctionItems
           .Where(i => i.AuctionId == auction.Id)
           .ToListAsync();
   }

   // ✅ GOOD: Single query with Include
   var auctions = await _dbContext.Auctions
       .Include(a => a.Items)
       .ToListAsync();
   ```

5. **Pagination ALWAYS**
   ```csharp
   // ✅ GOOD: Paginated query
   public async Task<List<AuctionDto>> GetAuctionsAsync(
       int skip,
       int take)
   {
       take = Math.Min(take, 100);  // Max 100 per page

       return await _dbContext.Auctions
           .OrderByDescending(a => a.PublishedOn)
           .Skip(skip)
           .Take(take)
           .Select(a => new AuctionDto { /* ... */ })
           .ToListAsync();
   }

   // ❌ BAD: No pagination
   public async Task<List<AuctionDto>> GetAuctionsAsync()
   {
       return await _dbContext.Auctions.ToListAsync();  // Can return millions!
   }
   ```

---

### P8: Security by Default 🔐

**Rules**:
1. **NEVER trust user input**
   ```csharp
   // ✅ GOOD: Validate and sanitize
   public async Task<IActionResult> CreateAuction(
       [FromBody] CreateAuctionRequest request)
   {
       // 1. Input validation
       var validator = new CreateAuctionRequestValidator();
       var validationResult = await validator.ValidateAsync(request);

       if (!validationResult.IsValid)
           return BadRequest(validationResult.Errors);

       // 2. Authorization check
       if (!User.HasClaim("TenantId", request.TenantId.ToString()))
           return Forbid();

       // 3. Sanitize HTML/dangerous content
       var sanitizedDescription = _htmlSanitizer.Sanitize(request.Description);

       // ... proceed with command
   }
   ```

2. **Parameterized queries ALWAYS**
   ```csharp
   // ✅ GOOD: EF Core uses parameterized queries
   var auctions = await _dbContext.Auctions
       .Where(a => a.TenantId == tenantId && a.Title.Contains(searchTerm))
       .ToListAsync();

   // ❌ BAD: String concatenation (SQL injection!)
   var sql = $"SELECT * FROM Auctions WHERE Title LIKE '%{searchTerm}%'";
   var auctions = await _dbContext.Auctions.FromSqlRaw(sql).ToListAsync();
   ```

3. **Secrets w Azure Key Vault**
   ```csharp
   // ✅ GOOD: Key Vault + Managed Identity
   var builder = WebApplication.CreateBuilder(args);

   if (!builder.Environment.IsDevelopment())
   {
       var keyVaultUri = new Uri(
           builder.Configuration["KeyVault:VaultUri"]!);

       builder.Configuration.AddAzureKeyVault(
           keyVaultUri,
           new DefaultAzureCredential());
   }

   // Access secrets
   var connectionString = builder.Configuration["ConnectionStrings:AuctionDb"];

   // ❌ BAD: Secrets w appsettings.json lub hardcoded
   var connectionString = "Server=...;Password=hardcodedPassword123";  // NO!
   ```

4. **Rate limiting dla public endpoints**
   ```csharp
   // Bid placement rate limit
   services.AddRateLimiter(options =>
   {
       options.AddFixedWindowLimiter("BidRateLimit", opt =>
       {
           opt.Window = TimeSpan.FromMinutes(1);
           opt.PermitLimit = 10;  // Max 10 bids per minute per user
           opt.QueueLimit = 0;
       });
   });

   [HttpPost("bids")]
   [EnableRateLimiting("BidRateLimit")]
   public async Task<IActionResult> PlaceBid(PlaceBidRequest request)
   {
       // ...
   }
   ```

---

### P9: Observability First 👁️

**Rules**:
1. **Structured logging everywhere**
   ```csharp
   // ✅ GOOD: Structured logging
   _logger.LogInformation(
       "Auction created: {AuctionId} by User {UserId} in Tenant {TenantId} " +
       "with StartPrice {StartPrice} | CorrelationId: {CorrelationId}",
       auction.Id,
       userId,
       tenantId,
       startPrice,
       correlationId);

   // ❌ BAD: String interpolation
   _logger.LogInformation(
       $"Auction {auction.Id} created by {userId}");  // Not queryable!
   ```

2. **Correlation IDs dla distributed tracing**
   ```csharp
   // Middleware injects correlation ID
   app.Use(async (context, next) =>
   {
       var correlationId = context.Request.Headers["X-Correlation-ID"]
           .FirstOrDefault() ?? Guid.NewGuid().ToString();

       context.Items["CorrelationId"] = correlationId;
       context.Response.Headers.Add("X-Correlation-ID", correlationId);

       using (_logger.BeginScope(new Dictionary<string, object>
       {
           ["CorrelationId"] = correlationId
       }))
       {
           await next();
       }
   });
   ```

3. **Custom metrics dla business events**
   ```csharp
   public class AuctionMetrics
   {
       private readonly TelemetryClient _telemetry;

       public void TrackAuctionCreated(TenantId tenantId)
       {
           _telemetry.TrackEvent("AuctionCreated", new Dictionary<string, string>
           {
               ["TenantId"] = tenantId.Value.ToString()
           });

           _telemetry.GetMetric("Auctions.Created").TrackValue(1);
       }

       public void TrackBidPlaced(AuctionId auctionId, decimal bidPrice)
       {
           _telemetry.TrackEvent("BidPlaced", new Dictionary<string, string>
           {
               ["AuctionId"] = auctionId.Value.ToString(),
               ["BidPrice"] = bidPrice.ToString()
           });

           _telemetry.GetMetric("Bids.Placed").TrackValue(1);
       }
   }
   ```

4. **Health checks dla all dependencies**
   ```csharp
   services.AddHealthChecks()
       .AddSqlServer(
           connectionString,
           name: "database",
           timeout: TimeSpan.FromSeconds(3))
       .AddRedis(
           redisConnectionString,
           name: "redis",
           timeout: TimeSpan.FromSeconds(3))
       .AddAzureServiceBusTopic(
           serviceBusConnectionString,
           topicName: "domain-events",
           name: "servicebus")
       .AddCheck<SignalRHealthCheck>("signalr");

   app.MapHealthChecks("/health", new HealthCheckOptions
   {
       ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
   });
   ```

---

### P10: Configuration over Code 🔧

**Rules**:
1. **Tenant-specific settings configurable**
   ```csharp
   public sealed class TenantConfiguration : ValueObject
   {
       public Currency DefaultCurrency { get; }
       public TimeSpan DefaultReservationTimeout { get; }
       public int MaxConcurrentAuctions { get; }

       // Loaded from database per tenant
   }

   // Usage
   var tenantConfig = await _tenantConfigService
       .GetConfigurationAsync(tenantId);

   var reservation = Reservation.Create(
       /* ... */,
       timeout: tenantConfig.DefaultReservationTimeout);  // Configurable!
   ```

2. **Feature flags dla gradual rollout**
   ```csharp
   services.AddFeatureManagement();

   // Check feature flag
   if (await _featureManager.IsEnabledAsync("NewBiddingAlgorithm"))
   {
       return await _newBiddingService.PlaceBidAsync(bid);
   }
   else
   {
       return await _legacyBiddingService.PlaceBidAsync(bid);
   }
   ```

3. **Environment-specific configuration**
   ```json
   // appsettings.Development.json
   {
     "Logging": {
       "LogLevel": {
         "Default": "Debug"
       }
     },
     "ConnectionStrings": {
       "AuctionDb": "Server=(localdb)\\mssqllocaldb;Database=AuctionDb"
     }
   }

   // appsettings.Production.json
   {
     "Logging": {
       "LogLevel": {
         "Default": "Information"
       }
     },
     "ConnectionStrings": {
       "AuctionDb": "" // From Azure Key Vault
     }
   }
   ```

---

## Anti-Patterns to Avoid ❌

### 1. God Classes
```csharp
// ❌ BAD: Everything w one class
public class AuctionService
{
    public void CreateAuction() { }
    public void PublishAuction() { }
    public void PlaceBid() { }
    public void ProcessPayment() { }
    public void SendEmail() { }
    // ... 50 more methods
}

// ✅ GOOD: Single Responsibility Principle
public class CreateAuctionCommandHandler { }
public class PublishAuctionCommandHandler { }
public class PlaceBidCommandHandler { }
// ... separate handlers
```

### 2. Anemic Domain Model
```csharp
// ❌ BAD: No behavior, just data
public class Auction
{
    public Guid Id { get; set; }
    public string Title { get; set; }
    public decimal StartPrice { get; set; }
    public decimal EndPrice { get; set; }
    public string Status { get; set; }
}

public class AuctionService
{
    public void PublishAuction(Auction auction)
    {
        if (auction.Status != "Draft")
            throw new InvalidOperationException();

        auction.Status = "Active";  // Business logic OUTSIDE domain
    }
}

// ✅ GOOD: Rich domain model
public sealed class Auction : AggregateRoot<AuctionId>
{
    public AuctionStatus Status { get; private set; }

    public Result Publish()
    {
        if (Status != AuctionStatus.Draft)
            return Result.Failure("Only draft auctions can be published");

        Status = AuctionStatus.Active;
        AddDomainEvent(new AuctionPublished { /* ... */ });
        return Result.Success();
    }
}
```

### 3. Premature Optimization
```csharp
// ❌ BAD: Over-engineering before profiling
public class SuperOptimizedCache<T>
{
    // 500 lines of complex caching logic
    // that may not be needed
}

// ✅ GOOD: Start simple, optimize when needed
public class SimpleCache<T>
{
    private readonly IMemoryCache _cache;

    public async Task<T?> GetOrAddAsync(string key, Func<Task<T>> factory)
    {
        if (_cache.TryGetValue(key, out T? value))
            return value;

        value = await factory();
        _cache.Set(key, value, TimeSpan.FromMinutes(5));
        return value;
    }
}
```

### 4. Tight Coupling
```csharp
// ❌ BAD: Direct dependency on concrete class
public class PlaceBidCommandHandler
{
    private readonly AuctionRepository _repository;  // Concrete class!

    public PlaceBidCommandHandler()
    {
        _repository = new AuctionRepository();  // Hard to test!
    }
}

// ✅ GOOD: Depend on abstraction
public class PlaceBidCommandHandler
{
    private readonly IAuctionRepository _repository;  // Interface!

    public PlaceBidCommandHandler(IAuctionRepository repository)
    {
        _repository = repository;  // Injected, easy to mock!
    }
}
```

---

## Code Review Checklist ✅

Before approving PR, verify:

**Domain Logic**:
- [ ] Business logic w Domain layer only
- [ ] Aggregates enforce all invariants
- [ ] Value objects are immutable
- [ ] Domain events dla significant changes

**Architecture**:
- [ ] Bounded context boundaries respected
- [ ] No cross-context repository calls
- [ ] CQRS separation maintained
- [ ] Events used dla cross-context communication

**Quality**:
- [ ] Tests added (unit + integration dla critical paths)
- [ ] Code coverage > 80%
- [ ] No compiler warnings
- [ ] SonarQube quality gate passed

**Performance**:
- [ ] Async/await used correctly
- [ ] No N+1 queries
- [ ] Pagination dla collections
- [ ] Indexes planned dla new queries

**Security**:
- [ ] Input validation present
- [ ] Authorization checks enforced
- [ ] No secrets w code
- [ ] SQL injection not possible

**Observability**:
- [ ] Structured logging added
- [ ] Correlation IDs propagated
- [ ] Metrics tracked dla business events

---

## Continuous Improvement

**Review Principles**: Quarterly
**Add New Principles**: When pattern emerges 3+ times
**Deprecate Principles**: When superseded by better approach

**Last Updated**: 2025-01-24
**Next Review**: 2025-04-24
