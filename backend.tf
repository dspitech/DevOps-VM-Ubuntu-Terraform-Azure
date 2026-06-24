# ============================================================
# Backend Terraform — Azure Storage Account
# ============================================================
# À exécuter AVANT terraform init :
#   ./setup-backend.sh
# ============================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "OpenLab-TFState-RG"
    storage_account_name = "openlabtfstate"   
    container_name       = "tfstate"
    key                  = "openlab-vm.terraform.tfstate"
  }
}
