provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "azure-openai-rg" {
  name = "azure-openai-rg"
  location = "Switzerland North"
}