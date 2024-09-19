terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}


provider "azurerm" {
  subscription_id = "d055dd42-c99f-4996-a41c-c5eeaae843f3"
  features {}
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "test"
  location = "East US"
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "test"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Public IP for Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Load Balancer
resource "azurerm_lb" "lb" {
  name                = "test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }
}

# Create Load Balancer Backend Pool
resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "test"
}

# Create Load Balancer Health Probe
resource "azurerm_lb_probe" "lb_health_probe" {
 
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "test"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Create Load Balancer Rule for HTTP traffic
resource "azurerm_lb_rule" "lb_rule" {
  
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "test"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "PublicIPAddress"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]  # Corrected this line
  probe_id                       = azurerm_lb_probe.lb_health_probe.id
}


# Network Security Group for VMs
resource "azurerm_network_security_group" "nsg" {
  name                = "test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Network Interface for VM1
resource "azurerm_network_interface" "nic1" {
  name                = "example-nic1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Network Interface for VM2
resource "azurerm_network_interface" "nic2" {
  name                = "test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate Network Interface 1 with the Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "nic1_lb_backend_pool_assoc" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

# Associate Network Interface 2 with the Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "nic2_lb_backend_pool_assoc" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}


# Create Virtual Machine 1
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "testvm1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic1.id]
  size                  = "Standard_B1s"

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

  admin_username = "azureuser"
  admin_password = "Password1234!"
}

# Create Virtual Machine 2
resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "testvm2"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic2.id]
  size                  = "Standard_B1s"

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

  admin_username = "azureuser"
  admin_password = "Password1234!"
}
