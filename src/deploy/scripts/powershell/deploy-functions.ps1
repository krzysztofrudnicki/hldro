# Deploy Azure Functions
# Usage: .\deploy-functions.ps1 -Environment dev -FunctionAppName hldro-dev-func -PackagePath ./publish.zip

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'test', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,

    [Parameter(Mandatory=$true)]
    [string]$PackagePath,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "hldro-$Environment-rg",

    [Parameter(Mandatory=$false)]
    [string]$SlotName = $null  # For blue-green deployment
)

# ========================================
# INITIALIZATION
# ========================================
$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "HLDRO Azure Functions Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Function App: $FunctionAppName"
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Package: $PackagePath"
if ($SlotName) {
    Write-Host "Slot: $SlotName"
}
Write-Host "=========================================" -ForegroundColor Cyan

# ========================================
# VALIDATION
# ========================================
Write-Host "`nValidating inputs..." -ForegroundColor Yellow

# Check if package exists
if (-not (Test-Path $PackagePath)) {
    Write-Error "Package not found: $PackagePath"
    exit 1
}

# Check if logged in to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not logged in to Azure. Run 'Connect-AzAccount' first."
        exit 1
    }
    Write-Host "Azure Context: $($context.Subscription.Name)" -ForegroundColor Green
} catch {
    Write-Error "Failed to get Azure context: $_"
    exit 1
}

# Check if Function App exists
Write-Host "Checking if Function App exists..."
try {
    $functionApp = Get-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
    Write-Host "Function App found: $($functionApp.Name)" -ForegroundColor Green
} catch {
    Write-Error "Function App not found: $FunctionAppName in $ResourceGroupName"
    exit 1
}

# ========================================
# STOP FUNCTION APP (Optional, for safe deployment)
# ========================================
if ($Environment -eq 'prod' -and -not $SlotName) {
    Write-Host "`nStopping Function App for safe deployment..." -ForegroundColor Yellow
    Stop-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -Force
}

# ========================================
# DEPLOYMENT
# ========================================
Write-Host "`nDeploying Function App..." -ForegroundColor Yellow

try {
    if ($SlotName) {
        # Deploy to slot
        Write-Host "Deploying to slot: $SlotName"
        Publish-AzWebApp `
            -ResourceGroupName $ResourceGroupName `
            -Name $FunctionAppName `
            -ArchivePath $PackagePath `
            -Slot $SlotName `
            -Force
    } else {
        # Deploy to production
        Publish-AzWebApp `
            -ResourceGroupName $ResourceGroupName `
            -Name $FunctionAppName `
            -ArchivePath $PackagePath `
            -Force
    }

    Write-Host "Deployment successful!" -ForegroundColor Green
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}

# ========================================
# START FUNCTION APP
# ========================================
if ($Environment -eq 'prod' -and -not $SlotName) {
    Write-Host "`nStarting Function App..." -ForegroundColor Yellow
    Start-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName
}

# ========================================
# HEALTH CHECK
# ========================================
Write-Host "`nPerforming health check..." -ForegroundColor Yellow

Start-Sleep -Seconds 30  # Wait for app to start

$healthCheckUrl = if ($SlotName) {
    "https://$FunctionAppName-$SlotName.azurewebsites.net/api/health"
} else {
    "https://$FunctionAppName.azurewebsites.net/api/health"
}

try {
    $response = Invoke-WebRequest -Uri $healthCheckUrl -Method Get -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "Health check passed!" -ForegroundColor Green
    } else {
        Write-Warning "Health check returned status: $($response.StatusCode)"
    }
} catch {
    Write-Warning "Health check failed: $_"
    Write-Warning "Please verify manually at: $healthCheckUrl"
}

# ========================================
# SUMMARY
# ========================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Function App: $FunctionAppName" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Green
Write-Host "Status: SUCCESS" -ForegroundColor Green
if ($SlotName) {
    Write-Host "Slot: $SlotName" -ForegroundColor Green
    Write-Host "`nTo swap slots, run:"
    Write-Host "Switch-AzFunctionAppSlot -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -SourceSlotName $SlotName -DestinationSlotName production" -ForegroundColor Yellow
}
Write-Host "=========================================" -ForegroundColor Cyan
