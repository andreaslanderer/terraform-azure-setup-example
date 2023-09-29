provider "azurerm" {
  features {}
}


/*
 * Variables
 */
variable "tenant_id" {
  description = "Azure Tenant ID"
  default     = "not-provided"
}

variable "object_id" {
  description = "Azure Object ID"
  default     = "not-provided"
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
   
   identity {
    type = "SystemAssigned"
  }
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


 /*
  * Azure key infrastructure
  */
  resource "azurerm_key_vault" "azure-openai-keyvault" {
    name = "azure-openai-keyvault-23"
    location = azurerm_resource_group.azure-openai-rg.location
    resource_group_name = azurerm_resource_group.azure-openai-rg.name
    tenant_id = var.tenant_id
    sku_name = "standard"

    access_policy {
        tenant_id = var.tenant_id
        object_id = var.object_id

        secret_permissions = [
          "Get",
          "Set"
        ]

        key_permissions = [
            "Create",
            "Get",
            "Delete",
            "List",
            "WrapKey",
            "UnwrapKey",
            "Sign",
            "Verify",
            "Backup",
            "Restore",
            "Recover",
            "Rotate",
            "GetRotationPolicy",
            "SetRotationPolicy"
        ]
    }
}

resource "azurerm_key_vault_key" "azure-openai-sa-key" {
  name         = "storage-account-key"
  key_vault_id = azurerm_key_vault.azure-openai-keyvault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}