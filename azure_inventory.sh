#!/bin/bash
#
# azure_inventory.sh
#
# This script collects asset inventory from an Azure subscription to be used with the
# Cortex Cloud License Estimator. It is designed to be run in any environment
# with the Azure CLI, including Azure Cloud Shell, with NO ADDITIONAL DEPENDENCIES.
#
# Prerequisites:
# 1. Azure CLI installed and configured with appropriate read-only credentials.
#    (e.g., assign the Reader role to the service principal/user)
# 2. Logged into Azure CLI: az login
#
# Usage:
#    ./azure_inventory.sh [subscription-id]
#    If no subscription-id is provided, uses the default subscription.

# --- Preamble ---
echo "Starting Azure Asset Inventory Collection..."
echo "NOTE: This script queries all enabled Azure regions and requires no dependencies other than the Azure CLI."
echo "This may take a few minutes."
echo "-----------------------------------------------------"

# Set subscription
if [ -n "$1" ]; then
    SUBSCRIPTION_ID="$1"
    echo "Using subscription: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID" 2>/dev/null || {
        echo "Error: Could not set subscription to $SUBSCRIPTION_ID"
        exit 1
    }
else
    SUBSCRIPTION_ID=$(az account show --query id --output tsv 2>/dev/null)
    if [ -z "$SUBSCRIPTION_ID" ]; then
        echo "Error: Not logged into Azure CLI. Please run 'az login' first."
        exit 1
    fi
    echo "Using default subscription: $SUBSCRIPTION_ID"
fi

# --- Global Services (No region loop needed) ---
echo "Querying Global Services..."

# Storage Accounts (for blob containers)
STORAGE_ACCOUNTS=$(az storage account list --subscription "$SUBSCRIPTION_ID" --query "length([].name)" --output tsv 2>/dev/null || echo 0)
echo "Found $STORAGE_ACCOUNTS Storage Accounts."

# Container Registry Images
ACR_REGISTRIES=$(az acr list --subscription "$SUBSCRIPTION_ID" --query "[].name" --output tsv 2>/dev/null)
TOTAL_ACR_IMAGES=0
for registry in $ACR_REGISTRIES; do
    IMAGE_COUNT=$(az acr repository list --name "$registry" --subscription "$SUBSCRIPTION_ID" --query "length(@)" --output tsv 2>/dev/null || echo 0)
    TOTAL_ACR_IMAGES=$((TOTAL_ACR_IMAGES + IMAGE_COUNT))
done

# --- Regional Services (Loop through all enabled regions) ---
echo "Querying Regional Services..."

# Initialize counters
TOTAL_VMS=0
TOTAL_AKS_PODS=0
TOTAL_FUNCTIONS=0
TOTAL_SQL_DB_INSTANCES=0
TOTAL_SQL_DB_STORAGE_GB=0

# Get all enabled regions for the subscription
REGIONS=$(az account list-locations --subscription "$SUBSCRIPTION_ID" --query "[?metadata.regionType=='Physical'].name" --output tsv)

for region in $REGIONS; do
    echo "Checking region: $region..."

    # Virtual Machines (Running)
    VM_COUNT=$(az vm list --subscription "$SUBSCRIPTION_ID" --resource-group "" --location "$region" --query "length([?powerState=='VM running'])" --output tsv 2>/dev/null || echo 0)
    TOTAL_VMS=$((TOTAL_VMS + VM_COUNT))

    # AKS Clusters and Running Pods
    AKS_CLUSTERS=$(az aks list --subscription "$SUBSCRIPTION_ID" --resource-group "" --location "$region" --query "[].name" --output tsv 2>/dev/null)
    for cluster in $AKS_CLUSTERS; do
        # Get resource group for the cluster
        RG=$(az aks show --subscription "$SUBSCRIPTION_ID" --name "$cluster" --resource-group "" --location "$region" --query "resourceGroup" --output tsv 2>/dev/null)
        if [ -n "$RG" ]; then
            # Get running pods (this requires kubectl, so we'll estimate based on node count)
            NODE_COUNT=$(az aks show --subscription "$SUBSCRIPTION_ID" --name "$cluster" --resource-group "$RG" --query "agentPoolProfiles[0].count" --output tsv 2>/dev/null || echo 0)
            # Estimate pods per node (typically 30-110 pods per node)
            ESTIMATED_PODS=$((NODE_COUNT * 50))
            TOTAL_AKS_PODS=$((TOTAL_AKS_PODS + ESTIMATED_PODS))
        fi
    done

    # Azure Functions
    FUNCTION_APPS=$(az functionapp list --subscription "$SUBSCRIPTION_ID" --resource-group "" --location "$region" --query "[].name" --output tsv 2>/dev/null)
    for app in $FUNCTION_APPS; do
        # Get function count per app
        RG=$(az functionapp show --subscription "$SUBSCRIPTION_ID" --name "$app" --resource-group "" --location "$region" --query "resourceGroup" --output tsv 2>/dev/null)
        if [ -n "$RG" ]; then
            FUNCTIONS_IN_APP=$(az functionapp function list --subscription "$SUBSCRIPTION_ID" --name "$app" --resource-group "$RG" --query "length(@)" --output tsv 2>/dev/null || echo 0)
            TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + FUNCTIONS_IN_APP))
        fi
    done

    # SQL Database Instances
    SQL_SERVERS=$(az sql server list --subscription "$SUBSCRIPTION_ID" --resource-group "" --location "$region" --query "[].name" --output tsv 2>/dev/null)
    for server in $SQL_SERVERS; do
        RG=$(az sql server show --subscription "$SUBSCRIPTION_ID" --name "$server" --resource-group "" --location "$region" --query "resourceGroup" --output tsv 2>/dev/null)
        if [ -n "$RG" ]; then
            DB_COUNT=$(az sql db list --subscription "$SUBSCRIPTION_ID" --server "$server" --resource-group "$RG" --query "length(@)" --output tsv 2>/dev/null || echo 0)
            TOTAL_SQL_DB_INSTANCES=$((TOTAL_SQL_DB_INSTANCES + DB_COUNT))
            
            # Get storage for each database
            DB_NAMES=$(az sql db list --subscription "$SUBSCRIPTION_ID" --server "$server" --resource-group "$RG" --query "[].name" --output tsv 2>/dev/null)
            for db_name in $DB_NAMES; do
                STORAGE_GB=$(az sql db show --subscription "$SUBSCRIPTION_ID" --name "$db_name" --server "$server" --resource-group "$RG" --query "maxSizeBytes" --output tsv 2>/dev/null || echo 0)
                if [[ "$STORAGE_GB" =~ ^[0-9]+$ ]] && [ "$STORAGE_GB" -gt 0 ]; then
                    # Convert bytes to GB
                    STORAGE_GB=$((STORAGE_GB / 1073741824))  # 1024^3
                    TOTAL_SQL_DB_STORAGE_GB=$((TOTAL_SQL_DB_STORAGE_GB + STORAGE_GB))
                fi
            done
        fi
    done
done

# --- Final Summary ---
echo ""
echo "-----------------------------------------------------"
echo "           Azure Asset Inventory Summary"
echo "-----------------------------------------------------"
echo "Copy these values into the Cortex Cloud License Estimator:"
echo ""
echo "VMs (Total Running Virtual Machines):          $TOTAL_VMS"
echo "  => NOTE: Manually split this total between 'VMs (not running containers)' and 'VMs (running containers)'."
echo ""
echo "CaaS (Managed Containers - AKS Pods):          $TOTAL_AKS_PODS"
echo "  => NOTE: This is an estimate based on node count. Actual pod count may vary."
echo ""
echo "Serverless Functions (Azure Functions):        $TOTAL_FUNCTIONS"
echo "Container Images in Registries (ACR Images):   $TOTAL_ACR_IMAGES"
echo "Cloud Buckets (Storage Accounts):              $STORAGE_ACCOUNTS"
echo "Managed Cloud Database (PaaS - SQL DBs):       $TOTAL_SQL_DB_INSTANCES"

# Calculate TB from GB
TOTAL_SQL_DB_STORAGE_TB=$(echo "scale=2; $TOTAL_SQL_DB_STORAGE_GB / 1024" | bc 2>/dev/null || echo "scale=2; $TOTAL_SQL_DB_STORAGE_GB / 1024" | awk '{printf "%.2f", $1}')

echo "DBaaS Storage:"
echo "  - GB: $TOTAL_SQL_DB_STORAGE_GB"
echo "  - TB: $TOTAL_SQL_DB_STORAGE_TB (use this value for DBaaS field)"
echo ""
echo "Manual Entry Required For:"
echo " - SaaS Users"
echo " - Cloud ASM - Unmanaged Services"
echo "-----------------------------------------------------"

# --- Auto-populate Code Generation ---
AUTO_POPULATE_CODE="vms:$TOTAL_VMS,caas:$TOTAL_AKS_PODS,sls:$TOTAL_FUNCTIONS,img:$TOTAL_ACR_IMAGES,bkt:$STORAGE_ACCOUNTS,paas:$TOTAL_SQL_DB_INSTANCES,dbaas:$TOTAL_SQL_DB_STORAGE_TB"
echo ""
echo "Auto-Populate Code (copy and paste this into the web tool):"
echo "$AUTO_POPULATE_CODE"
echo "-----------------------------------------------------"
echo "Script Finished." 