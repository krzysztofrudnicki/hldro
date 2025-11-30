# Run Smoke Tests
# Usage: .\run-smoke-tests.ps1 -Environment dev

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'test', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [string]$SlotName = $null
)

# ========================================
# INITIALIZATION
# ========================================
$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "HLDRO Smoke Tests" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
if ($SlotName) {
    Write-Host "Slot: $SlotName"
}
Write-Host "=========================================" -ForegroundColor Cyan

# ========================================
# CONFIGURATION
# ========================================
$functionAppName = "hldro-$Environment-func"
$baseUrl = if ($SlotName) {
    "https://$functionAppName-$SlotName.azurewebsites.net"
} else {
    "https://$functionAppName.azurewebsites.net"
}

$tests = @()
$passedTests = 0
$failedTests = 0

# ========================================
# TEST: Health Endpoint
# ========================================
Write-Host "`nTest 1: Health Endpoint" -ForegroundColor Yellow
$test = @{
    Name = "Health Check"
    Url = "$baseUrl/api/health"
    ExpectedStatus = 200
    Passed = $false
}

try {
    $response = Invoke-WebRequest -Uri $test.Url -Method Get -TimeoutSec 10
    if ($response.StatusCode -eq $test.ExpectedStatus) {
        Write-Host "  PASSED: Health endpoint returned 200" -ForegroundColor Green
        $test.Passed = $true
        $passedTests++
    } else {
        Write-Host "  FAILED: Expected $($test.ExpectedStatus), got $($response.StatusCode)" -ForegroundColor Red
        $failedTests++
    }
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    $failedTests++
}
$tests += $test

# ========================================
# TEST: API Availability
# ========================================
Write-Host "`nTest 2: API Availability" -ForegroundColor Yellow
$test = @{
    Name = "API Availability"
    Url = "$baseUrl/api/auctions"
    ExpectedStatus = 200
    Passed = $false
}

try {
    $response = Invoke-WebRequest -Uri $test.Url -Method Get -TimeoutSec 10
    if ($response.StatusCode -eq $test.ExpectedStatus -or $response.StatusCode -eq 401) {
        Write-Host "  PASSED: API endpoint is available" -ForegroundColor Green
        $test.Passed = $true
        $passedTests++
    } else {
        Write-Host "  FAILED: Expected 200 or 401, got $($response.StatusCode)" -ForegroundColor Red
        $failedTests++
    }
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    $failedTests++
}
$tests += $test

# ========================================
# TEST: Application Insights
# ========================================
Write-Host "`nTest 3: Application Insights" -ForegroundColor Yellow
$test = @{
    Name = "Application Insights"
    Passed = $false
}

try {
    $resourceGroupName = "hldro-$Environment-rg"
    $appInsightsName = "hldro-$Environment-ai"

    $appInsights = Get-AzApplicationInsights -ResourceGroupName $resourceGroupName -Name $appInsightsName -ErrorAction Stop

    if ($appInsights) {
        Write-Host "  PASSED: Application Insights is configured" -ForegroundColor Green
        Write-Host "  Instrumentation Key: $($appInsights.InstrumentationKey.Substring(0, 8))..." -ForegroundColor Gray
        $test.Passed = $true
        $passedTests++
    } else {
        Write-Host "  FAILED: Application Insights not found" -ForegroundColor Red
        $failedTests++
    }
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    $failedTests++
}
$tests += $test

# ========================================
# TEST: Service Bus
# ========================================
Write-Host "`nTest 4: Service Bus Connectivity" -ForegroundColor Yellow
$test = @{
    Name = "Service Bus"
    Passed = $false
}

try {
    $resourceGroupName = "hldro-$Environment-rg"
    $serviceBusName = "hldro-$Environment-sb"

    $serviceBus = Get-AzServiceBusNamespace -ResourceGroupName $resourceGroupName -Name $serviceBusName -ErrorAction Stop

    if ($serviceBus.Status -eq 'Active') {
        Write-Host "  PASSED: Service Bus is active" -ForegroundColor Green
        $test.Passed = $true
        $passedTests++
    } else {
        Write-Host "  FAILED: Service Bus status is $($serviceBus.Status)" -ForegroundColor Red
        $failedTests++
    }
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    $failedTests++
}
$tests += $test

# ========================================
# SUMMARY
# ========================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Smoke Tests Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($tests.Count)"
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($passedTests / $tests.Count) * 100, 2))%"
Write-Host "=========================================" -ForegroundColor Cyan

# ========================================
# EXIT CODE
# ========================================
if ($failedTests -gt 0) {
    Write-Host "`nSome tests failed. Please investigate." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
}
