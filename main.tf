provider "azurerm" {
  features {}
}

/*
 * Resource group 
 */
resource "azurerm_resource_group" "azure-openai-rg" {
  name = "azure-openai-rg"
  location = "Switzerland North"
}


/*
 * Network resources
 */
resource "azurerm_virtual_network" "azure-openai-vnet" {
  name = "azure-openai-vnet"
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.azure-openai-rg.location
  resource_group_name = azurerm_resource_group.azure-openai-rg.name
}

resource "azurerm_subnet" "azure-openai-compute-subnet" {
  name = "compute-subnet"
  resource_group_name = azurerm_resource_group.azure-openai-rg.name
  virtual_network_name = azurerm_virtual_network.azure-openai-vnet.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "azure-openai-endpoint-subnet" {
  name = "endpoint-subnet"
  resource_group_name = azurerm_resource_group.azure-openai-rg.name
  virtual_network_name = azurerm_virtual_network.azure-openai-vnet.name
  address_prefixes = ["10.0.2.0/24"]
}


/*
 * Storage account
 */
 resource "azurerm_storage_account" "document-sa" {
   name = "azureopenaidocumentsa"
   resource_group_name = azurerm_resource_group.azure-openai-rg.name
   location = azurerm_resource_group.azure-openai-rg.location
   account_tier = "Standard"
   account_replication_type = "LRS"
 }

 resource "azurerm_storage_container" "document-sa-container" {
   name = "container"
   storage_account_name = azurerm_storage_account.document-sa.name
   container_access_type = "private"
 }

 resource "azurerm_private_endpoint" "document-sa-endpoint" {
   name = "document-sa-private-endpoint"
   location = azurerm_resource_group.azure-openai-rg.location
   resource_group_name = azurerm_resource_group.azure-openai-rg.name
   subnet_id = azurerm_subnet.azure-openai-endpoint-subnet.id

   private_service_connection {
     name = "document-sa-connection"
     is_manual_connection = false
     private_connection_resource_id = azurerm_storage_account.document-sa.id
     subresource_names = ["blob"]
   }
 }