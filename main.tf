#Define the provider and version see https://registry.terraform.io/providers/hashicorp/azurerm/latest
provider "azurerm"{
    features {}
}
/*Data section 
Where you reference resources that already exist. In this case we are doing a greenfield deployment. If the RG already existed then you could reference it like below. 
data "azurerm_resource_group" "resGroup" {
    name                         = "RG-terraform"
    location                     = "westus"

    tags = {
      "environment"             = "dev"
      "phase"                   = "testing"
      "deployed_with"           = "terraform"
}
*/
#Resources 
resource "azurerm_resource_group" "resGroup" {
    name                                = "rg-terraform"
    location                            = "westus"

    tags = {
      "environment"                     = "dev"
      "phase"                           = "testing"
      "deployed_with"                   = "terraform"
    }
}
resource "azurerm_virtual_network" "vnet-terraform" {
    name                                = "vnet-terraform"
    location                            = azurerm_resource_group.resGroup.location
    resource_group_name                 = azurerm_resource_group.resGroup.name 
    address_space                       = ["10.96.254.0/24"]

    tags = {
      "environment"                     = "dev"
      "phase"                           = "testing"
      "deployed_with"                   = "terraform"
      }    
}
resource "azurerm_subnet" "snet-hubfw" {
    name                                = "snet-hubfw"
    resource_group_name                 = azurerm_resource_group.resGroup.name
    virtual_network_name                = azurerm_virtual_network.vnet-terraform.name
    address_prefixes                    = ["10.96.254.248/29"]
}
resource "azurerm_public_ip" "pip_outside" {
    name                                = "pipHubFwOutside"
    resource_group_name                 = azurerm_resource_group.resGroup.name
    location                            = azurerm_resource_group.resGroup.location
    allocation_method                   = "Static"

    tags = {
      "environment"                     = "dev"
      "phase"                           = "testing"
      "deployed_with"                   = "terraform"
      }     
}
resource "azurerm_network_interface" "inside_int" {
    name                                = "inside_int"
    location                            = azurerm_resource_group.resGroup.location
    resource_group_name                 = azurerm_resource_group.resGroup.name
    enable_ip_forwarding                = true

    ip_configuration {
        name                            = "internal"
        subnet_id                       = azurerm_subnet.snet-hubfw.id
        private_ip_address_allocation   = "Dynamic" 
    } 
}
resource "azurerm_network_interface" "outside_int" {
    name                                = "outside_int"
    location                            = azurerm_resource_group.resGroup.location
    resource_group_name                 = azurerm_resource_group.resGroup.name
    enable_ip_forwarding                = true  

    ip_configuration {
        name                            = "external"
        subnet_id                       = azurerm_subnet.snet-hubfw.id
        private_ip_address_allocation   = "Dynamic"
        public_ip_address_id            = azurerm_public_ip.pip_outside.id
        
    }
}
resource "azurerm_linux_virtual_machine" "hubPfsense" {
    name                                = "hub-pfsense-fw"
    admin_username                      = "rippee"
    resource_group_name                 = azurerm_resource_group.resGroup.name
    location                            = azurerm_resource_group.resGroup.location
    size                                = "Standard_B1ls"
    network_interface_ids               = [azurerm_network_interface.inside_int.id,azurerm_network_interface.outside_int.id]
    admin_ssh_key {
        username                        = "rippee"
        public_key                      = file("~/.ssh/id_rsa.pub")  
    }
    os_disk {
      caching                           = "ReadWrite"
      storage_account_type              = "Standard_LRS"  
    }
    source_image_reference {
      publisher                         =  "Netgate"
      offer                             =  "netgate-pfsense-plus-fw-vpn-router"
      sku                               =  "netgate-pfsense-plus"
      version                           =  "latest"
    }
    plan {
      name                              = "netgate-pfsense-plus-fw-vpn-router"
      product                           = "netgate-pfsense-plus"
      publisher                         = "Netgate"
    }
    tags = {
      "environment"                     = "dev"
      "phase"                           = "testing"
      "deployed_with"                   = "terraform"
    }           
}
resource "azurerm_marketplace_agreement" "netgate" {
  publisher                             = "Netgate"
  offer                                 = "netgate-pfsense-plus-fw-vpn-router"
  plan                                  = "netgate-pfsense-plus"
  
}

