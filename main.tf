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