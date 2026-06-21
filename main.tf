# ============================================================
# Provider Azure + TLS (génération clé SSH automatique)
# ============================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "azurerm" {
  features {}
}

# ============================================================
# Variables
# ============================================================
variable "rg_name" {
  default = "OpenLab-Sweden-RG"
}

variable "location" {
  default = "swedencentral"
}

variable "vm_name" {
  default = "OpenLab-VM-Student"
}

variable "admin_username" {
  default = "labadmin"
}

variable "vm_size" {
  default = "Standard_B2s_v2"
}

variable "data_disk_size_gb" {
  default = 64
  description = "Taille du disque de données supplémentaire en Go"
}

# ============================================================
# Génération automatique de la clé SSH via provider TLS
# ============================================================
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Sauvegarde locale de la clé privée (chmod 600 automatique)
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${path.module}/openlab_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/openlab_rsa.pub"
}

# ============================================================
# Resource Group
# ============================================================
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# ============================================================
# Réseau virtuel
# ============================================================
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ============================================================
# IP publique
# ============================================================
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ============================================================
# Network Security Group (NSG) + règles de ports
# ============================================================
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Proxmox"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8006"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-VNC"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5900"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP-Alt"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Custom-8989"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8989"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
security_rule {
  name                       = "Allow-FastAPI"
  priority                   = 106
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "8000"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

security_rule {
  name                       = "Allow-Jenkins-UI"
  priority                   = 107
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "8081"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

security_rule {
  name                       = "Allow-Jenkins-Agent"
  priority                   = 108
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "50000"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

security_rule {
  name                       = "Allow-SonarQube"
  priority                   = 109
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "9000"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

security_rule {
  name                       = "Allow-Prometheus"
  priority                   = 111
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "9090"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

security_rule {
  name                       = "Allow-Grafana"
  priority                   = 112
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "3000"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}
security_rule {
  name                       = "Allow-Staging-Port-8001"
  priority                   = 1013
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "8001"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  description                = "Autorise l acces au port 8001 pour le staging"
}
security_rule {
  name                       = "Allow-Portainer-9443"
  priority                   = 1014
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "9443"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  description                = "Autorise l'acces HTTPS a Portainer sur le port 9443"
}
}

# ============================================================
# Interface réseau (NIC)
# ============================================================
resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ============================================================
# Disque de données supplémentaire (Managed Disk)
# ============================================================
resource "azurerm_managed_disk" "data_disk" {
  name                 = "${var.vm_name}-datadisk"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
}

# ============================================================
# Machine Virtuelle Linux (Ubuntu 22.04)
# ============================================================
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  # Clé SSH générée automatiquement par le provider TLS
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Script cloud-init encodé en base64 pour installer Docker + Git
  custom_data = base64encode(file("${path.module}/cloud-init.yaml"))
}

# Attachement du disque de données à la VM
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attach" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = 10
  caching            = "ReadWrite"
}

# ============================================================
# Outputs
# ============================================================
output "public_ip_address" {
  description = "Adresse IP publique de la VM"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh -i ${path.module}/openlab_rsa ${var.admin_username}@${azurerm_public_ip.public_ip.ip_address}"
}

output "private_key_path" {
  description = "Chemin local vers la clé privée SSH générée"
  value       = local_sensitive_file.private_key.filename
  sensitive   = true
}
