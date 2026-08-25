#!/bin/bash
# One-time, run by hand. Creates the storage account Terraform will use as
# its remote state backend. This CANNOT be created by Terraform itself,
# since Terraform would need this backend to already exist to run.
#
# Usage: ./01-create-state-backend.sh
set -euo pipefail

STATE_RG="rg-blinket-tfstate"
LOCATION="germanywestcentral"
# Storage account names must be globally unique, 3-24 lowercase alphanumeric chars.
# Edit this if it's already taken.
STATE_STORAGE_ACCOUNT="blinkettfstate01"
STATE_CONTAINER="tfstate"

echo "Creating resource group for Terraform state: $STATE_RG"
az group create --name "$STATE_RG" --location "$LOCATION"

echo "Creating storage account: $STATE_STORAGE_ACCOUNT"
az storage account create \
  --name "$STATE_STORAGE_ACCOUNT" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Enabling blob versioning + soft delete (protects state history)"
az storage account blob-service-properties update \
  --account-name "$STATE_STORAGE_ACCOUNT" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 14

echo "Creating blob container: $STATE_CONTAINER"
az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STATE_STORAGE_ACCOUNT" \
  --auth-mode login

cat <<EOF

=============================================================
Save these — you'll need them for 'terraform init' and for the
GitHub Actions workflow's backend-config:

  TF_STATE_RESOURCE_GROUP=$STATE_RG
  TF_STATE_STORAGE_ACCOUNT=$STATE_STORAGE_ACCOUNT
  TF_STATE_CONTAINER=$STATE_CONTAINER
=============================================================
EOF
