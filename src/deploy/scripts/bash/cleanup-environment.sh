#!/bin/bash
# Cleanup Environment - Delete Resource Group
# Usage: ./cleanup-environment.sh <environment>

set -e

# ========================================
# PARAMETERS
# ========================================
ENVIRONMENT=${1:-dev}
RESOURCE_GROUP="hldro-$ENVIRONMENT-rg"

# ========================================
# COLORS
# ========================================
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========================================
# HEADER
# ========================================
echo -e "${RED}=========================================${NC}"
echo -e "${RED}CLEANUP ENVIRONMENT: $ENVIRONMENT${NC}"
echo -e "${RED}=========================================${NC}"
echo -e "${YELLOW}Resource Group: $RESOURCE_GROUP${NC}"
echo ""

# ========================================
# SAFETY CHECK
# ========================================
if [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${RED}❌ PRODUCTION ENVIRONMENT DETECTED!${NC}"
    echo ""
    echo -e "${YELLOW}Production cleanup requires manual confirmation.${NC}"
    echo -e "${YELLOW}Use Azure Portal or run: az group delete --name $RESOURCE_GROUP${NC}"
    echo ""
    exit 1
fi

# ========================================
# CHECK AZURE LOGIN
# ========================================
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Not logged in to Azure${NC}"
    echo -e "${YELLOW}Run: az login${NC}"
    exit 1
fi

# ========================================
# CHECK IF RESOURCE GROUP EXISTS
# ========================================
echo -e "${YELLOW}Checking if resource group exists...${NC}"

if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo -e "${GREEN}✓ Resource group does not exist - nothing to clean up${NC}"
    exit 0
fi

echo -e "${GREEN}✓ Resource group found${NC}"
echo ""

# ========================================
# LIST RESOURCES
# ========================================
echo -e "${YELLOW}Resources in group:${NC}"
az resource list --resource-group $RESOURCE_GROUP --output table
echo ""

RESOURCE_COUNT=$(az resource list --resource-group $RESOURCE_GROUP --query "length(@)" -o tsv)
echo -e "${CYAN}Total resources: $RESOURCE_COUNT${NC}"
echo ""

# ========================================
# CONFIRMATION
# ========================================
echo -e "${RED}⚠️  WARNING: This will DELETE ALL resources in this group!${NC}"
echo ""
read -p "Type 'DELETE' to confirm deletion of $RESOURCE_GROUP: " CONFIRMATION

if [ "$CONFIRMATION" != "DELETE" ]; then
    echo ""
    echo -e "${YELLOW}Deletion cancelled.${NC}"
    exit 0
fi

# ========================================
# DELETE RESOURCE GROUP
# ========================================
echo ""
echo -e "${RED}Deleting resource group: $RESOURCE_GROUP...${NC}"

az group delete \
    --name $RESOURCE_GROUP \
    --yes \
    --no-wait

echo ""
echo -e "${GREEN}✓ Deletion started (running in background)${NC}"
echo ""
echo -e "${YELLOW}Check status with:${NC}"
echo -e "  az group show --name $RESOURCE_GROUP"
echo ""
echo -e "${YELLOW}Or wait for completion with:${NC}"
echo -e "  az group wait --name $RESOURCE_GROUP --deleted"
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Cleanup initiated successfully${NC}"
echo -e "${GREEN}=========================================${NC}"
