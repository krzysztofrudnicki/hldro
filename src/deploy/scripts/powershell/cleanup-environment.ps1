# Cleanup Environment - Delete Resource Group
# Usage: .\cleanup-environment.ps1 -Environment dev

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'test', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ========================================
# VARIABLES
# ========================================
$resourceGroupName = "hldro-$Environment-rg"

Write-Host "=========================================" -ForegroundColor Red
Write-Host "CLEANUP ENVIRONMENT: $Environment" -ForegroundColor Red
Write-Host "=========================================" -ForegroundColor Red
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Yellow
Write-Host ""

# ========================================
# SAFETY CHECK
# ========================================
if ($Environment -eq 'prod' -and -not $Force) {
    Write-Host "❌ PRODUCTION ENVIRONMENT DETECTED!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To delete production, use: -Force parameter" -ForegroundColor Yellow
    Write-Host "Example: .\cleanup-environment.ps1 -Environment prod -Force" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# ========================================
# CHECK IF RESOURCE GROUP EXISTS
# ========================================
Write-Host "Checking if resource group exists..." -ForegroundColor Yellow

try {
    $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop

    Write-Host "✓ Resource group found" -ForegroundColor Green
    Write-Host ""
    Write-Host "Location: $($rg.Location)"
    Write-Host "Tags: $($rg.Tags | ConvertTo-Json -Compress)"
    Write-Host ""

    # List resources
    Write-Host "Resources in group:" -ForegroundColor Yellow
    $resources = Get-AzResource -ResourceGroupName $resourceGroupName
    $resources | Format-Table Name, ResourceType, Location -AutoSize
    Write-Host ""
    Write-Host "Total resources: $($resources.Count)" -ForegroundColor Cyan

} catch {
    Write-Host "✓ Resource group does not exist - nothing to clean up" -ForegroundColor Green
    exit 0
}

# ========================================
# CONFIRMATION
# ========================================
Write-Host ""
Write-Host "⚠️  WARNING: This will DELETE ALL resources in this group!" -ForegroundColor Red
Write-Host ""

$confirmation = Read-Host "Type 'DELETE' to confirm deletion of $resourceGroupName"

if ($confirmation -ne 'DELETE') {
    Write-Host ""
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# ========================================
# DELETE RESOURCE GROUP
# ========================================
Write-Host ""
Write-Host "Deleting resource group: $resourceGroupName..." -ForegroundColor Red

try {
    Remove-AzResourceGroup `
        -Name $resourceGroupName `
        -Force `
        -AsJob

    Write-Host ""
    Write-Host "✓ Deletion started (running as background job)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Check status with:" -ForegroundColor Yellow
    Write-Host "  Get-AzResourceGroup -Name $resourceGroupName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or wait for completion with:" -ForegroundColor Yellow
    Write-Host "  Get-Job | Wait-Job" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "❌ Deletion failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Cleanup initiated successfully" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
