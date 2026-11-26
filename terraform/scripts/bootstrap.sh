#!/bin/bash

set -e

echo "=================================="
echo " Terraform Bootstrap Started"
echo "=================================="

# 1. Check Terraform
terraform version

# 2. Check Azure CLI
az version

# 3. Check Azure Login
az account show

# 4. Check Subscription
SUBSCRIPTION_ID=$(az account show \
  --query id -o tsv)

echo "Subscription: $SUBSCRIPTION_ID"

# 5. Check Tenant
TENANT_ID=$(az account show \
  --query tenantId -o tsv)

echo "Tenant: $TENANT_ID"

# 6. Check Azure Providers
for provider in \
  Microsoft.Network \
  Microsoft.ContainerService \
  Microsoft.Storage \
  Microsoft.ContainerRegistry \
  Microsoft.KeyVault \
  Microsoft.ManagedIdentity \
  Microsoft.Authorization

do
  echo "Checking provider: $provider"

  az provider show \
    --namespace "$provider" \
    --query registrationState -o tsv
done

echo "=================================="
echo " Bootstrap Completed"
echo "=================================="