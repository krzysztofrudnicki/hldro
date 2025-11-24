# Coding Standards for AI Agents

## Purpose

Ten dokument zawiera **konkretne, wykonalne zasady** dla AI agents generujących kod dla Reverse Auction Platform. Każda zasada jest jednoznaczna i verifiable.

---

## File Organization Rules

### Rule FO-1: Project Structure MUST Follow Template
```
src/Contexts/{ContextName}/
├── Domain/
│   ├── Aggregates/         # Aggregate roots only
│   ├── Entities/            # Non-root entities
│   ├── ValueObjects/        # Immutable value objects
│   ├── Events/              # Domain events
│   ├── Services/            # Domain services
│   ├── Exceptions/          # Domain-specific exceptions
│   └── Repositories/        # Repository interfaces
├── Application/
│   ├── Commands/            # Command handlers
│   │   └── {Feature}/
│   │       ├── {Command}Command.cs
│   │       ├── {Command}CommandHandler.cs
│   │       └── {Command}CommandValidator.cs
│   ├── Queries/             # Query handlers
│   │   └── {Feature}/
│   │       ├── {Query}Query.cs
│   │       ├── {Query}QueryHandler.cs
│   │       └── {Query}Dto.cs
│   ├── EventHandlers/       # Domain event subscribers
│   └── Services/            # Application services
├── Infrastructure/
│   ├── Persistence/
│   │   ├── Configurations/  # EF Core entity configurations
│   │   ├── Migrations/      # EF Core migrations
│   │   └── {Context}DbContext.cs
│   ├── Repositories/        # Repository implementations
│   └── Services/            # Infrastructure services
└── API/
    ├── Controllers/         # HTTP endpoints
    ├── Requests/            # Request DTOs
    ├── Responses/           # Response DTOs
    └── Middleware/          # Custom middleware
```

**Violation Example**:
```csharp
// ❌ WRONG: Aggregate w Application layer
src/Contexts/Auction/Application/Auction.cs

// ✅ CORRECT:
src/Contexts/Auction/Domain/Aggregates/Auction.cs
```

---

## Naming Conventions

### Rule NC-1: C# Naming Standards
```csharp
// Classes, Interfaces, Records: PascalCase
public sealed class AuctionRepository { }
public interface IAuctionRepository { }
public sealed record AuctionCreated { }

// Methods, Properties: PascalCase
public Result Publish() { }
public AuctionId Id { get; private set; }

// Private fields: _camelCase
private readonly IAuctionRepository _repository;
private List<AuctionItem> _items = new();

// Parameters, local variables: camelCase
public void AddItem(InventoryItemId itemId, int displayOrder) { }

// Constants: PascalCase
public const int MaxItemsPerAuction = 100;
```

### Rule NC-2: Domain-Specific Naming
```csharp
// ✅ GOOD: Business terminology
public sealed class Auction { }
public sealed class Bid { }
public Money CalculateCurrentPrice() { }

// ❌ BAD: Technical jargon
public sealed class AuctionEntity { }  // Remove "Entity"
public sealed class BidRecord { }      // Remove "Record"
public decimal GetPrice() { }          // Use domain term "Calculate"
```

### Rule NC-3: Command/Query Naming Pattern
```csharp
// Commands: {Verb}{Noun}Command
public sealed record CreateAuctionCommand { }
public sealed record PublishAuctionCommand { }
public sealed record PlaceBidCommand { }

// Command Handlers: {Command}Handler
public sealed class CreateAuctionCommandHandler { }

// Queries: Get{Noun}Query or Get{Noun}sQuery
public sealed record GetAuctionQuery { }
public sealed record GetActiveAuctionsQuery { }

// Query Handlers: {Query}Handler
public sealed class GetAuctionQueryHandler { }
```

### Rule NC-4: Event Naming Pattern
```csharp
// Events: {Noun}{PastTenseVerb}
public sealed record AuctionCreated : IDomainEvent { }
public sealed record AuctionPublished : IDomainEvent { }
public sealed record BidAccepted : IDomainEvent { }
public sealed record ItemSold : IDomainEvent { }

// ❌ WRONG: Present tense or future tense
public sealed record AuctionCreate { }    // Should be AuctionCreated
public sealed record WillPublishAuction { }  // Should be AuctionPublished
```

---

## Domain Layer Rules

### Rule DL-1: Aggregate Root MUST Inherit from AggregateRoot<TId>
```csharp
// ✅ CORRECT:
public sealed class Auction : AggregateRoot<AuctionId>
{
    // Implementation
}

// ❌ WRONG: Plain class
public sealed class Auction
{
    public Guid Id { get; set; }
}
```

### Rule DL-2: Value Objects MUST Be Immutable Records
```csharp
// ✅ CORRECT: Immutable record
public sealed record Money : ValueObject
{
    public decimal Amount { get; init; }
    public string Currency { get; init; }

    private Money(decimal amount, string currency)
    {
        Amount = amount;
        Currency = currency;
    }

    public static Money From(decimal amount, string currency) => new(amount, currency);

    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }
}

// ❌ WRONG: Mutable class
public class Money
{
    public decimal Amount { get; set; }  // Should be init-only
    public string Currency { get; set; }  // Should be init-only
}
```

### Rule DL-3: Properties MUST Have Private Setters
```csharp
// ✅ CORRECT:
public sealed class Auction : AggregateRoot<AuctionId>
{
    public AuctionTitle Title { get; private set; }
    public AuctionStatus Status { get; private set; }

    private readonly List<AuctionItem> _items = new();
    public IReadOnlyCollection<AuctionItem> Items => _items.AsReadOnly();

    // State changes through methods only
    public Result Publish() { /* ... */ }
}

// ❌ WRONG: Public setters
public sealed class Auction
{
    public string Title { get; set; }  // Should be private set
    public string Status { get; set; }  // Should be private set
    public List<AuctionItem> Items { get; set; }  // Should be IReadOnlyCollection
}
```

### Rule DL-4: Factory Method Pattern for Creation
```csharp
// ✅ CORRECT:
public sealed class Auction : AggregateRoot<AuctionId>
{
    // Private constructor
    private Auction() { }

    // Public static factory method
    public static Result<Auction> Create(
        TenantId tenantId,
        AuctionTitle title,
        PriceSchedule priceSchedule,
        DateTime endAt)
    {
        // Validation
        if (endAt <= DateTime.UtcNow)
            return Result.Failure("End date must be in the future");

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
}

// ❌ WRONG: Public constructor with validation
public sealed class Auction
{
    public Auction(string title)  // Public constructor
    {
        if (string.IsNullOrEmpty(title))
            throw new ArgumentException();  // Exceptions in constructor
        Title = title;
    }
}
```

### Rule DL-5: Domain Events MUST Be Added, Not Published
```csharp
// ✅ CORRECT: Add to aggregate, publish later
public Result Publish()
{
    Status = AuctionStatus.Active;
    AddDomainEvent(new AuctionPublished
    {
        EventId = Guid.NewGuid(),
        OccurredOn = DateTime.UtcNow,
        AuctionId = Id,
        TenantId = TenantId,
        // ...
    });
    return Result.Success();
}

// ❌ WRONG: Direct publishing w domain
public Result Publish(IEventPublisher eventPublisher)
{
    Status = AuctionStatus.Active;
    await eventPublisher.PublishAsync(new AuctionPublished());  // NO!
    return Result.Success();
}
```

### Rule DL-6: NO Infrastructure Dependencies in Domain
```csharp
// ❌ WRONG: Infrastructure leak
public sealed class Auction : AggregateRoot<AuctionId>
{
    private readonly IAuctionRepository _repository;  // NO!
    private readonly ILogger _logger;  // NO!
    private readonly IEventBus _eventBus;  // NO!
}

// ✅ CORRECT: Pure domain, no dependencies
public sealed class Auction : AggregateRoot<AuctionId>
{
    // Only domain concepts
    public AuctionTitle Title { get; private set; }
    public PriceSchedule PriceSchedule { get; private set; }
}
```

---

## Application Layer Rules

### Rule AL-1: Command Handler Pattern
```csharp
// ✅ CORRECT: IRequestHandler<TCommand, Result<T>>
public sealed class CreateAuctionCommandHandler
    : IRequestHandler<CreateAuctionCommand, Result<AuctionId>>
{
    private readonly IAuctionRepository _repository;
    private readonly IEventPublisher _eventPublisher;

    public CreateAuctionCommandHandler(
        IAuctionRepository repository,
        IEventPublisher eventPublisher)
    {
        _repository = repository;
        _eventPublisher = eventPublisher;
    }

    public async Task<Result<AuctionId>> Handle(
        CreateAuctionCommand command,
        CancellationToken cancellationToken)
    {
        // 1. Create aggregate
        var auctionResult = Auction.Create(
            command.TenantId,
            AuctionTitle.From(command.Title),
            command.PriceSchedule,
            command.EndAt);

        if (auctionResult.IsFailure)
            return Result.Failure<AuctionId>(auctionResult.Error);

        var auction = auctionResult.Value;

        // 2. Save aggregate
        await _repository.SaveAsync(auction, cancellationToken);

        // 3. Publish events
        await _eventPublisher.PublishAsync(
            auction.DomainEvents,
            cancellationToken);

        auction.ClearDomainEvents();

        return Result.Success(auction.Id);
    }
}
```

### Rule AL-2: FluentValidation for Input DTOs
```csharp
// ✅ CORRECT: Separate validator class
public sealed class CreateAuctionCommandValidator
    : AbstractValidator<CreateAuctionCommand>
{
    public CreateAuctionCommandValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty()
            .MinimumLength(10)
            .MaximumLength(200);

        RuleFor(x => x.StartPrice)
            .GreaterThan(0)
            .WithMessage("Start price must be positive");

        RuleFor(x => x.EndPrice)
            .GreaterThan(0)
            .LessThan(x => x.StartPrice)
            .WithMessage("End price must be less than start price");

        RuleFor(x => x.EndAt)
            .GreaterThan(DateTime.UtcNow)
            .WithMessage("End date must be in the future");
    }
}

// Register w Startup
services.AddValidatorsFromAssemblyContaining<CreateAuctionCommandValidator>();
```

### Rule AL-3: Query Handler Returns DTOs
```csharp
// ✅ CORRECT: Query returns DTO
public sealed record GetAuctionQuery : IRequest<Result<AuctionDto>>
{
    public AuctionId AuctionId { get; init; }
}

public sealed record AuctionDto
{
    public Guid AuctionId { get; init; }
    public string Title { get; init; }
    public decimal CurrentPrice { get; init; }
    public string Currency { get; init; }
    public int RemainingItems { get; init; }
    // ... projection properties only
}

// ❌ WRONG: Query returns domain model
public sealed record GetAuctionQuery : IRequest<Result<Auction>>  // NO!
{
    // Should return DTO, not domain model
}
```

### Rule AL-4: Event Handlers MUST Be Idempotent
```csharp
// ✅ CORRECT: Idempotency check
public sealed class AuctionPublishedEventHandler
    : IEventHandler<AuctionPublished>
{
    private readonly IEventProcessingLog _eventLog;
    private readonly IAuctionReadRepository _readRepository;

    public async Task HandleAsync(AuctionPublished @event)
    {
        // 1. Check if already processed
        var processed = await _eventLog.HasProcessedAsync(
            @event.EventId,
            nameof(AuctionPublishedEventHandler));

        if (processed)
        {
            _logger.LogInformation(
                "Event {EventId} already processed, skipping",
                @event.EventId);
            return;
        }

        // 2. Process event
        var readModel = new AuctionListReadModel
        {
            AuctionId = @event.AuctionId,
            Title = @event.Title,
            // ...
        };

        await _readRepository.InsertOrUpdateAsync(readModel);

        // 3. Mark as processed
        await _eventLog.MarkAsProcessedAsync(
            @event.EventId,
            nameof(AuctionPublishedEventHandler));
    }
}

// ❌ WRONG: No idempotency check
public sealed class AuctionPublishedEventHandler
{
    public async Task HandleAsync(AuctionPublished @event)
    {
        // Directly processing without checking
        await _readRepository.InsertAsync(readModel);  // Can fail on duplicate!
    }
}
```

---

## Infrastructure Layer Rules

### Rule IL-1: EF Core Configuration in Separate Files
```csharp
// ✅ CORRECT: Separate configuration file
public sealed class AuctionConfiguration : IEntityTypeConfiguration<Auction>
{
    public void Configure(EntityTypeBuilder<Auction> builder)
    {
        builder.ToTable("Auctions", "Auction");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.Id)
            .HasConversion(
                id => id.Value,
                value => AuctionId.From(value))
            .IsRequired();

        builder.Property(a => a.TenantId)
            .HasConversion(
                id => id.Value,
                value => TenantId.From(value))
            .IsRequired();

        builder.OwnsOne(a => a.Title, titleBuilder =>
        {
            titleBuilder.Property(t => t.Value)
                .HasColumnName("Title")
                .HasMaxLength(200)
                .IsRequired();
        });

        // Indexes
        builder.HasIndex(a => new { a.TenantId, a.Status, a.PublishedOn })
            .HasDatabaseName("IX_Auctions_TenantId_Status_PublishedOn");

        // Ignore domain events (not persisted)
        builder.Ignore(a => a.DomainEvents);
    }
}

// DbContext applies configurations
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ApplyConfigurationsFromAssembly(
        typeof(AuctionDbContext).Assembly);
}

// ❌ WRONG: Configuration w DbContext
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Auction>(entity =>
    {
        // 200 lines of configuration here...
    });
}
```

### Rule IL-2: Repository Returns Domain Models Only
```csharp
// ✅ CORRECT: Repository interface w Domain layer
namespace ReverseAuction.Contexts.Auction.Domain.Repositories;

public interface IAuctionRepository
{
    Task<Auction?> GetByIdAsync(AuctionId id, CancellationToken ct = default);
    Task SaveAsync(Auction auction, CancellationToken ct = default);
    Task DeleteAsync(Auction auction, CancellationToken ct = default);
}

// Implementation w Infrastructure layer
namespace ReverseAuction.Contexts.Auction.Infrastructure.Repositories;

public sealed class AuctionRepository : IAuctionRepository
{
    private readonly AuctionDbContext _dbContext;

    public async Task<Auction?> GetByIdAsync(AuctionId id, CancellationToken ct)
    {
        return await _dbContext.Auctions
            .Include(a => a.Items)
            .FirstOrDefaultAsync(a => a.Id == id, ct);
    }

    public async Task SaveAsync(Auction auction, CancellationToken ct)
    {
        _dbContext.Auctions.Update(auction);
        await _dbContext.SaveChangesAsync(ct);
    }
}

// ❌ WRONG: Repository returns DTOs or includes queries
public interface IAuctionRepository
{
    Task<AuctionDto> GetAuctionDtoAsync(Guid id);  // NO! DTOs are for queries
    Task<List<Auction>> GetActiveAuctionsAsync();  // NO! Use Query Handler
}
```

### Rule IL-3: Outbox Pattern for Event Publishing
```csharp
// ✅ CORRECT: Save events to outbox w same transaction
public async Task SaveAsync(Auction auction, CancellationToken ct)
{
    using var transaction = await _dbContext.Database
        .BeginTransactionAsync(ct);

    try
    {
        // 1. Update aggregate
        _dbContext.Auctions.Update(auction);

        // 2. Save events to outbox
        foreach (var domainEvent in auction.DomainEvents)
        {
            var outboxMessage = new OutboxMessage
            {
                Id = Guid.NewGuid(),
                EventType = domainEvent.GetType().AssemblyQualifiedName!,
                EventData = JsonSerializer.Serialize(
                    domainEvent,
                    domainEvent.GetType()),
                OccurredOn = domainEvent.OccurredOn,
                ProcessedOn = null
            };

            _dbContext.OutboxMessages.Add(outboxMessage);
        }

        await _dbContext.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);

        auction.ClearDomainEvents();
    }
    catch
    {
        await transaction.RollbackAsync(ct);
        throw;
    }
}
```

---

## API Layer Rules

### Rule API-1: Controller Actions Return IActionResult
```csharp
// ✅ CORRECT:
[ApiController]
[Route("api/v1/auctions")]
public sealed class AuctionsController : ControllerBase
{
    private readonly IMediator _mediator;

    public AuctionsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
    [ProducesResponseType(typeof(AuctionCreatedResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> CreateAuction(
        [FromBody] CreateAuctionRequest request,
        CancellationToken ct)
    {
        var command = new CreateAuctionCommand
        {
            TenantId = GetCurrentTenantId(),
            Title = request.Title,
            Description = request.Description,
            // ... map request to command
        };

        var result = await _mediator.Send(command, ct);

        if (result.IsFailure)
            return BadRequest(new { errors = new[] { result.Error } });

        return CreatedAtAction(
            nameof(GetAuction),
            new { id = result.Value },
            new AuctionCreatedResponse { AuctionId = result.Value.Value });
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AuctionDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetAuction(
        Guid id,
        CancellationToken ct)
    {
        var query = new GetAuctionQuery { AuctionId = AuctionId.From(id) };
        var result = await _mediator.Send(query, ct);

        if (result.IsFailure)
            return NotFound();

        return Ok(result.Value);
    }
}
```

### Rule API-2: Separate Request/Response DTOs
```csharp
// ✅ CORRECT: Dedicated request/response types
public sealed record CreateAuctionRequest
{
    public string Title { get; init; } = string.Empty;
    public string? Description { get; init; }
    public decimal StartPrice { get; init; }
    public decimal EndPrice { get; init; }
    public DateTime EndAt { get; init; }
    public List<Guid> ItemIds { get; init; } = new();
}

public sealed record AuctionCreatedResponse
{
    public Guid AuctionId { get; init; }
}

// ❌ WRONG: Reusing command as request
[HttpPost]
public async Task<IActionResult> CreateAuction(
    [FromBody] CreateAuctionCommand command)  // NO! Exposes internal structure
{
    var result = await _mediator.Send(command);
    // ...
}
```

### Rule API-3: OpenAPI Documentation Required
```csharp
// ✅ CORRECT: XML documentation + attributes
/// <summary>
/// Creates a new auction
/// </summary>
/// <param name="request">Auction details</param>
/// <param name="ct">Cancellation token</param>
/// <returns>Created auction ID</returns>
/// <response code="201">Auction created successfully</response>
/// <response code="400">Invalid request data</response>
/// <response code="401">User not authenticated</response>
/// <response code="403">User not authorized</response>
[HttpPost]
[Authorize(Roles = "Marketer")]
[ProducesResponseType(typeof(AuctionCreatedResponse), StatusCodes.Status201Created)]
[ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status401Unauthorized)]
[ProducesResponseType(StatusCodes.Status403Forbidden)]
public async Task<IActionResult> CreateAuction(
    [FromBody] CreateAuctionRequest request,
    CancellationToken ct)
{
    // ...
}
```

---

## Testing Rules

### Rule T-1: Test File Naming Convention
```
Tests/
├── UnitTests/
│   └── Contexts/
│       └── Auction/
│           └── Domain/
│               └── Aggregates/
│                   └── AuctionTests.cs
├── IntegrationTests/
│   └── Contexts/
│       └── Auction/
│           └── Application/
│               └── Commands/
│                   └── CreateAuctionCommandHandlerTests.cs
└── E2ETests/
    └── Auctions/
        └── AuctionE2ETests.cs
```

### Rule T-2: Test Method Naming: MethodName_Scenario_ExpectedResult
```csharp
// ✅ CORRECT:
[Fact]
public void Publish_WhenStatusIsDraft_ShouldSucceed()
{
    // Arrange
    var auction = AuctionTestBuilder.Create()
        .WithStatus(AuctionStatus.Draft)
        .WithItems(3)
        .Build();

    // Act
    var result = auction.Publish();

    // Assert
    Assert.True(result.IsSuccess);
    Assert.Equal(AuctionStatus.Active, auction.Status);
    Assert.Contains(auction.DomainEvents,
        e => e is AuctionPublished);
}

[Fact]
public void Publish_WhenStatusIsActive_ShouldFail()
{
    // Arrange
    var auction = AuctionTestBuilder.Create()
        .WithStatus(AuctionStatus.Active)
        .Build();

    // Act
    var result = auction.Publish();

    // Assert
    Assert.True(result.IsFailure);
    Assert.Contains("only draft auctions", result.Error, StringComparison.OrdinalIgnoreCase);
}

// ❌ WRONG: Vague test names
[Fact]
public void Test1() { }  // What does this test?

[Fact]
public void PublishTest() { }  // Which scenario?
```

### Rule T-3: Use Test Builders for Complex Objects
```csharp
// ✅ CORRECT: Fluent test builder
public sealed class AuctionTestBuilder
{
    private TenantId _tenantId = TenantId.Create();
    private AuctionTitle _title = AuctionTitle.From("Test Auction Title");
    private AuctionStatus _status = AuctionStatus.Draft;
    private PriceSchedule _priceSchedule = PriceSchedule.Create(
        Money.From(1000, "PLN"),
        Money.From(100, "PLN"),
        TimeSpan.FromHours(1),
        TimeSpan.FromSeconds(1)).Value;
    private List<AuctionItem> _items = new();

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

    public AuctionTestBuilder WithItems(int count)
    {
        for (int i = 0; i < count; i++)
        {
            _items.Add(AuctionItem.Create(
                InventoryItemId.Create(),
                i).Value);
        }
        return this;
    }

    public Auction Build()
    {
        var auction = Auction.Create(
            _tenantId,
            _title,
            _priceSchedule,
            DateTime.UtcNow.AddHours(1)).Value;

        // Set private state for testing
        if (_status != AuctionStatus.Draft)
        {
            SetPrivateProperty(auction, nameof(Auction.Status), _status);
        }

        foreach (var item in _items)
        {
            GetPrivateField<List<AuctionItem>>(auction, "_items")!.Add(item);
        }

        return auction;
    }

    private static void SetPrivateProperty(object obj, string propertyName, object value)
    {
        var property = obj.GetType().GetProperty(
            propertyName,
            BindingFlags.Public | BindingFlags.Instance);
        property!.SetValue(obj, value);
    }

    private static T? GetPrivateField<T>(object obj, string fieldName)
    {
        var field = obj.GetType().GetField(
            fieldName,
            BindingFlags.NonPublic | BindingFlags.Instance);
        return (T?)field!.GetValue(obj);
    }
}

// Usage w test
var auction = AuctionTestBuilder.Create()
    .WithStatus(AuctionStatus.Active)
    .WithItems(5)
    .Build();
```

### Rule T-4: Integration Tests Use TestContainers
```csharp
// ✅ CORRECT:
public sealed class AuctionRepositoryTests : IAsyncLifetime
{
    private readonly SqlContainer _sqlContainer = new SqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .WithPassword("StrongP@ssw0rd!")
        .Build();

    private AuctionDbContext _dbContext = null!;

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
    public async Task SaveAsync_Should_Persist_Auction_With_Items()
    {
        // Arrange
        var repository = new AuctionRepository(_dbContext);
        var auction = AuctionTestBuilder.Create()
            .WithItems(3)
            .Build();

        // Act
        await repository.SaveAsync(auction);

        // Assert
        var retrieved = await repository.GetByIdAsync(auction.Id);
        Assert.NotNull(retrieved);
        Assert.Equal(3, retrieved.Items.Count);
    }

    public async Task DisposeAsync()
    {
        await _dbContext.DisposeAsync();
        await _sqlContainer.StopAsync();
    }
}
```

---

## Code Quality Rules

### Rule CQ-1: NO Magic Numbers or Strings
```csharp
// ✅ CORRECT: Named constants
public sealed class AuctionConstants
{
    public const int MaxItemsPerAuction = 100;
    public const int MinTitleLength = 10;
    public const int MaxTitleLength = 200;
    public const int DefaultReservationTimeoutMinutes = 15;
}

public Result AddItem(InventoryItemId itemId)
{
    if (_items.Count >= AuctionConstants.MaxItemsPerAuction)
        return Result.Failure($"Cannot exceed {AuctionConstants.MaxItemsPerAuction} items");

    // ...
}

// ❌ WRONG: Magic numbers
public Result AddItem(InventoryItemId itemId)
{
    if (_items.Count >= 100)  // What does 100 mean?
        return Result.Failure("Cannot exceed 100 items");
}
```

### Rule CQ-2: Guard Clauses at Method Start
```csharp
// ✅ CORRECT: Guard clauses first
public Result AcceptBid(BidId bidId, UserId userId, Money bidPrice)
{
    // Guards
    if (Status != AuctionStatus.Active)
        return Result.Failure("Auction is not active");

    if (RemainingItemsCount == 0)
        return Result.Failure("No items remaining");

    var currentPrice = CalculateCurrentPrice(DateTime.UtcNow);
    if (bidPrice != currentPrice)
        return Result.Failure("Bid price does not match current price");

    // Business logic
    var bid = Bid.Create(bidId, userId, bidPrice, DateTime.UtcNow).Value;
    _acceptedBids.Add(bid);
    RemainingItemsCount--;

    AddDomainEvent(new BidAccepted { /* ... */ });
    return Result.Success();
}

// ❌ WRONG: Nested ifs
public Result AcceptBid(BidId bidId, UserId userId, Money bidPrice)
{
    if (Status == AuctionStatus.Active)
    {
        if (RemainingItemsCount > 0)
        {
            if (bidPrice == CalculateCurrentPrice(DateTime.UtcNow))
            {
                // Business logic buried deep
            }
        }
    }
}
```

### Rule CQ-3: Single Responsibility Per Method
```csharp
// ✅ CORRECT: Focused methods
public Result Publish()
{
    var validationResult = ValidatePublishPreconditions();
    if (validationResult.IsFailure)
        return validationResult;

    ChangeStatusToActive();
    RecordPublishTimestamp();
    RaisePublishedEvent();

    return Result.Success();
}

private Result ValidatePublishPreconditions()
{
    if (Status != AuctionStatus.Draft)
        return Result.Failure("Only draft auctions can be published");

    if (_items.Count == 0)
        return Result.Failure("Cannot publish auction without items");

    return Result.Success();
}

private void ChangeStatusToActive()
{
    Status = AuctionStatus.Active;
}

private void RecordPublishTimestamp()
{
    PublishedOn = DateTime.UtcNow;
}

private void RaisePublishedEvent()
{
    AddDomainEvent(new AuctionPublished
    {
        EventId = Guid.NewGuid(),
        OccurredOn = DateTime.UtcNow,
        AuctionId = Id,
        TenantId = TenantId,
        // ...
    });
}

// ❌ WRONG: God method doing everything
public Result Publish()
{
    // 200 lines of mixed validation, state changes, and event raising
}
```

### Rule CQ-4: Avoid Abbreviations
```csharp
// ✅ CORRECT: Full words
public sealed class AuctionRepository { }
public decimal CalculateCurrentPrice() { }
public int RemainingItemsCount { get; private set; }

// ❌ WRONG: Abbreviations
public sealed class AucRepo { }  // Use AuctionRepository
public decimal CalcCurPrice() { }  // Use CalculateCurrentPrice
public int RemItemsCnt { get; private set; }  // Use RemainingItemsCount
```

---

## Async/Await Rules

### Rule AA-1: Async All the Way Down
```csharp
// ✅ CORRECT: Async throughout
public async Task<Result<AuctionId>> Handle(
    CreateAuctionCommand command,
    CancellationToken ct)
{
    var auction = Auction.Create(/* ... */).Value;

    await _repository.SaveAsync(auction, ct);  // Async
    await _eventPublisher.PublishAsync(auction.DomainEvents, ct);  // Async

    return Result.Success(auction.Id);
}

// ❌ WRONG: Blocking calls
public async Task<Result<AuctionId>> Handle(CreateAuctionCommand command)
{
    var auction = Auction.Create(/* ... */).Value;

    _repository.SaveAsync(auction).Wait();  // NO! Blocking
    _eventPublisher.PublishAsync(auction.DomainEvents).GetAwaiter().GetResult();  // NO!

    return Result.Success(auction.Id);
}
```

### Rule AA-2: ConfigureAwait(false) in Libraries
```csharp
// ✅ CORRECT: ConfigureAwait(false) w infrastructure
public async Task SaveAsync(Auction auction, CancellationToken ct)
{
    _dbContext.Auctions.Update(auction);
    await _dbContext.SaveChangesAsync(ct).ConfigureAwait(false);
}

// ❌ WRONG: Missing ConfigureAwait in library code
public async Task SaveAsync(Auction auction, CancellationToken ct)
{
    _dbContext.Auctions.Update(auction);
    await _dbContext.SaveChangesAsync(ct);  // Can cause deadlocks
}
```

### Rule AA-3: CancellationToken Parameter Last
```csharp
// ✅ CORRECT: CancellationToken at end
public async Task<Auction?> GetByIdAsync(
    AuctionId id,
    CancellationToken ct = default)
{
    return await _dbContext.Auctions
        .FirstOrDefaultAsync(a => a.Id == id, ct);
}

// ❌ WRONG: CancellationToken not last
public async Task<Auction?> GetByIdAsync(
    CancellationToken ct,
    AuctionId id)  // Wrong order
{
    // ...
}
```

---

## Logging Rules

### Rule L-1: Structured Logging with Serilog
```csharp
// ✅ CORRECT: Structured logging
_logger.LogInformation(
    "Auction created: {AuctionId} by User {UserId} in Tenant {TenantId} " +
    "with StartPrice {StartPrice:C} | CorrelationId: {CorrelationId}",
    auction.Id.Value,
    userId.Value,
    tenantId.Value,
    startPrice,
    correlationId);

// ❌ WRONG: String interpolation
_logger.LogInformation(
    $"Auction {auction.Id} created by {userId}");  // Not queryable!
```

### Rule L-2: Log Levels
```csharp
// Debug: Detailed flow (dev only)
_logger.LogDebug("Entering CreateAuctionCommandHandler.Handle");

// Information: Key events
_logger.LogInformation("Auction {AuctionId} published", auctionId);

// Warning: Recoverable issues
_logger.LogWarning("Retry attempt {RetryCount} for event {EventId}", retryCount, eventId);

// Error: Failures
_logger.LogError(ex, "Failed to publish event {EventId}", eventId);

// Critical: System failures
_logger.LogCritical(ex, "Database connection lost");
```

### Rule L-3: NO Logging of Sensitive Data
```csharp
// ✅ CORRECT: No PII logged
_logger.LogInformation("User {UserId} logged in", userId);

// ❌ WRONG: Logging PII
_logger.LogInformation(
    "User {Email} with password {Password} logged in",
    email,  // PII!
    password);  // NEVER log passwords!
```

---

## Agent Checklist

Before submitting code, verify:

**Domain Layer**:
- [ ] Aggregates inherit from `AggregateRoot<TId>`
- [ ] Value objects are immutable records
- [ ] Properties have private setters
- [ ] Factory methods for creation
- [ ] Domain events added, not published
- [ ] NO infrastructure dependencies

**Application Layer**:
- [ ] Command handlers return `Result<T>`
- [ ] Query handlers return DTOs
- [ ] FluentValidation for input DTOs
- [ ] Event handlers are idempotent

**Infrastructure Layer**:
- [ ] EF Core configurations in separate files
- [ ] Repositories return domain models
- [ ] Outbox pattern for events

**API Layer**:
- [ ] Controllers return `IActionResult`
- [ ] Separate request/response DTOs
- [ ] OpenAPI documentation present

**Testing**:
- [ ] Test file naming correct
- [ ] Test method naming: `MethodName_Scenario_ExpectedResult`
- [ ] Test builders for complex objects
- [ ] Integration tests use TestContainers

**Quality**:
- [ ] No magic numbers or strings
- [ ] Guard clauses at method start
- [ ] Single responsibility per method
- [ ] No abbreviations
- [ ] Async/await throughout
- [ ] Structured logging
- [ ] No sensitive data logged

---

## Versioning

**Last Updated**: 2025-01-24
**Version**: 1.0
**Next Review**: Whenever new patterns emerge (minimum quarterly)
