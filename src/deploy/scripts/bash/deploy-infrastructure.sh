#!/bin/bash
# Deploy Infrastructure using Bicep
# Usage: ./deploy-infrastructure.sh <environment>

set -e  # Exit on error
set -u  # Exit on undefined variable

# ========================================
# PARAMETERS
# ========================================
ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# ========================================
# VARIABLES
# ========================================
BICEP_TEMPLATE="$DEPLOY_ROOT/templates/bicep/main.bicep"
PARAMETERS_FILE="$DEPLOY_ROOT/environments/$ENVIRONMENT/parameters.json"
DEPLOYMENT_NAME="hldro-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"

# ========================================
# VALIDATION
# ========================================
echo "========================================="
echo "HLDRO Infrastructure Deployment"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo "Template: $BICEP_TEMPLATE"
echo "Parameters: $PARAMETERS_FILE"
echo "========================================="

# Check if files exist
if [ ! -f "$BICEP_TEMPLATE" ]; then
    echo "ERROR: Bicep template not found: $BICEP_TEMPLATE"
    exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
    echo "ERROR: Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in to Azure. Run 'az login' first."
    exit 1
fi

# ========================================
# WHAT-IF (Preview Changes)
# ========================================
echo ""
echo "Running 'what-if' to preview changes..."
az deployment sub what-if \
    --name "$DEPLOYMENT_NAME" \
    --location westeurope \
    --template-file "$BICEP_TEMPLATE" \
    --parameters "$PARAMETERS_FILE"

# ========================================
# CONFIRMATION
# ========================================
echo ""
read -p "Do you want to proceed with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# ========================================
# DEPLOYMENT
# ========================================
echo ""
echo "Starting deployment..."
az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location westeurope \
    --template-file "$BICEP_TEMPLATE" \
    --parameters "$PARAMETERS_FILE" \
    --output table

# ========================================
# OUTPUT RESULTS
# ========================================
echo ""
echo "Deployment completed successfully!"
echo "Retrieving outputs..."

az deployment sub show \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs \
    --output json

echo ""
echo "========================================="
echo "Deployment Summary"
echo "========================================="
echo "Deployment Name: $DEPLOYMENT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Status: SUCCESS"
echo "========================================="
