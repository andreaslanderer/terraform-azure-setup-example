provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "azure-openai-rg" {
  name = "azure-openai-rg"
  location = "Switzerland North"
}

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