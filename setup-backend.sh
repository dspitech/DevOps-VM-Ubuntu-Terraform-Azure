#!/bin/bash
# ============================================================
# setup-backend.sh
# Crée le Storage Account Azure pour stocker le state Terraform
# À exécuter UNE SEULE FOIS avant terraform init
# ============================================================

set -euo pipefail

# ---------- Configuration (modifiez si besoin) ----------
RG_NAME="OpenLab-TFState-RG"
LOCATION="swedencentral"
STORAGE_ACCOUNT="openlabtfstate$RANDOM"   # suffixe aléatoire pour unicité globale
CONTAINER_NAME="tfstate"
# --------------------------------------------------------

echo "==> Création du Resource Group pour le backend..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --output none

echo "==> Création du Storage Account : $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --output none

echo "==> Création du container blob : $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --output none

echo ""
echo "✅ Backend prêt. Mettez à jour backend.tf avec :"
echo "   storage_account_name = \"$STORAGE_ACCOUNT\""
echo ""
echo "==> Puis lancez :"
echo "   terraform init"
echo "   terraform fmt && terraform validate"
echo "   terraform plan"
echo "   terraform apply -auto-approve"
