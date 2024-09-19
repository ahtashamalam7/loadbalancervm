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
  name     = "example-resources"
  location = "East US"
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Public IP for VM1
resource "azurerm_public_ip" "public_ip_vm1" {
  name                = "example-public-ip-vm1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Public IP for VM2
resource "azurerm_public_ip" "public_ip_vm2" {
  name                = "example-public-ip-vm2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


# Create Public IP for Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "example-lb-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Load Balancer
resource "azurerm_lb" "lb" {
  name                = "example-lb"
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
  loadbalancer_id = azurerm_lb.lb.id
  name            = "example-backend-pool"
}

# Create Load Balancer Health Probe
resource "azurerm_lb_probe" "lb_health_probe" {
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "example-health-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Create Load Balancer Rule for HTTP traffic
resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "example-lb-rule"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "PublicIPAddress"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.lb_health_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]  # Reference to backend pool
}

# Create Network Security Group for VMs (Allow HTTP and SSH)
resource "azurerm_network_security_group" "nsg" {
  name                = "example-nsg"
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

  security_rule {
    name                       = "AllowSSH"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Network Interface for VM1
resource "azurerm_network_interface" "nic_vm1" {
  name                = "example-nic-vm1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_vm1.id
  }
}

# Create Network Interface for VM2
resource "azurerm_network_interface" "nic_vm2" {
  name                = "example-nic-vm2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_vm2.id
  }
}

# Associate NSG with Network Interface for VM1
resource "azurerm_network_interface_security_group_association" "nsg_assoc_vm1" {
  network_interface_id      = azurerm_network_interface.nic_vm1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Associate NSG with Network Interface for VM2
resource "azurerm_network_interface_security_group_association" "nsg_assoc_vm2" {
  network_interface_id      = azurerm_network_interface.nic_vm2.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

locals {
  custom_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    echo "Welcome to VM1 - IP: $(hostname -I)" > /var/www/html/index.html
  EOF
}


# Create Virtual Machine 1
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "example-vm1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_vm1.id]
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
  custom_data = base64encode(local.custom_script)

  admin_username = "alam"
  admin_password = "Ahtashamalam@123"

  # Enable password authentication
  disable_password_authentication = false

}

# Create Virtual Machine 2
resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "example-vm2"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_vm2.id]
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
  custom_data = base64encode(local.custom_script)

  admin_username = "alam"
  admin_password = "Ahtashamalam@123"

  # Enable password authentication
  disable_password_authentication = false

}
