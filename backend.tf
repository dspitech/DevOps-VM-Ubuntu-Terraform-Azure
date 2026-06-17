# ============================================================
# Backend Terraform — Azure Storage Account
# ============================================================
# À exécuter AVANT terraform init :
#   ./scripts/setup-backend.sh
# ============================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "OpenLab-TFState-RG"
    storage_account_name = "openlabtfstate"   # doit être globalement unique
    container_name       = "tfstate"
    key                  = "openlab-vm.terraform.tfstate"
  }
}
