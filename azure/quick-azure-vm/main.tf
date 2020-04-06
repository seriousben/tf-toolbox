# Configure the Microsoft Azure Provider
provider "azurerm" {
  version = "~>2.0"
  features {}
}

variable "name_prefix" {
  description = "unique part of the name to give to resources"
}

variable "owner" {}

variable "usage" {}

variable "region" {
  default     = "westus2"
}

locals {
  # Common tags to be assigned to all resources
  common_tags = {
    owner = "${var.owner}"
    usage = "${var.usage}"
  }
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "group" {
  name     = "${var.name_prefix}-rg"
  location = "${var.region}"

  tags = local.common_tags
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
  name                = "${var.name_prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location = "${var.region}"
  resource_group_name = azurerm_resource_group.group.name

  tags = local.common_tags
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.group.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "publicip" {
  name                = "${var.name_prefix}-public-ip"
  location = "${var.region}"
  resource_group_name = azurerm_resource_group.group.name
  allocation_method   = "Dynamic"

  tags = local.common_tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name_prefix}-nsg"
  location = "${var.region}"
  resource_group_name = azurerm_resource_group.group.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.name_prefix}-nic"
  location = "${var.region}"
  resource_group_name = azurerm_resource_group.group.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }

  tags = local.common_tags
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.name_prefix}-vm"
  location = "${var.region}"
  resource_group_name   = azurerm_resource_group.group.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_B1s"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  computer_name                   = "consul-agent-testing-vm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  tags = local.common_tags
}
