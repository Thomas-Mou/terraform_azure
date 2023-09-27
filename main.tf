terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.74.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
  tenant_id = "e8b88f3d-222b-4ce5-b9d1-46b0ff9466a0"
  subscription_id = "380a10c2-0513-492d-ac62-b291196fe623"
}

locals{
    location = "West Europe"
    resource_group_name = "Thomas-Mou"

    custom_data = file("${path.module}/config.sh")

}

resource "azurerm_virtual_network" "vnet" {
  name                = "thomas-network"
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "thomas-machine"
  location            = local.location
  resource_group_name = local.resource_group_name
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "Adminpwd1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data             = base64encode(local.custom_data)
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-vm"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAppTraffic"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "lp_ip" {
  name                = "PublicIPForLB"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb" {
  name                = "LoadBalancer"
  location            = local.location
  resource_group_name = local.resource_group_name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lp_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backenpool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEnd"
}

resource "azurerm_network_interface_backend_address_pool_association" "backend_association" {
  network_interface_id    = azurerm_network_interface.nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backenpool.id
}

resource "azurerm_lb_rule" "rules" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 5000
  backend_port                   = 5000
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backenpool.id]
}

output "public_ip_loadbalancer" {
  value = azurerm_public_ip.lp_ip.id
  description = "The private IP address of the newly created Azure VM"
}