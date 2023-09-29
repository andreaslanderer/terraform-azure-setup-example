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
    purge_protection_enabled    = true
    soft_delete_retention_days  = 7

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
            "SetRotationPolicy",
            "Purge"
        ]
    }
}

resource "azurerm_key_vault_access_policy" "storage_account_access" {
  key_vault_id = azurerm_key_vault.azure-openai-keyvault.id

  tenant_id = var.tenant_id
  object_id = azurerm_storage_account.document-sa.identity.0.principal_id

  key_permissions = [
    "Get", 
    "WrapKey", 
    "UnwrapKey"
  ]
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

resource "azurerm_storage_account_customer_managed_key" "document-sa-cmk" {
  storage_account_id = azurerm_storage_account.document-sa.id
  key_vault_id       = azurerm_key_vault.azure-openai-keyvault.id
  key_name           = azurerm_key_vault_key.azure-openai-sa-key.name
  key_version        = azurerm_key_vault_key.azure-openai-sa-key.version

  depends_on = [
    azurerm_key_vault_access_policy.storage_account_access
  ]
}


/*
 * Azure Cloud Function
 */
 resource "azurerm_storage_account" "create-documents-fa-sa" {
  name                     = "createdocumentsfasa"
  resource_group_name      = azurerm_resource_group.azure-openai-rg.name
  location                 = azurerm_resource_group.azure-openai-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "plan" {
  name                = "azure-functions-service-plan"
  location            = azurerm_resource_group.azure-openai-rg.location
  resource_group_name = azurerm_resource_group.azure-openai-rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "create-documents-fa" {
  name                       = "create-documents-fa"
  location                   = azurerm_resource_group.azure-openai-rg.location
  resource_group_name        = azurerm_resource_group.azure-openai-rg.name
  app_service_plan_id        = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.create-documents-fa-sa.name
  storage_account_access_key = azurerm_storage_account.create-documents-fa-sa.primary_access_key

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "create-documents-fa-document-sa-ra" {
  principal_id   = azurerm_function_app.create-documents-fa.identity.0.principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope          = azurerm_storage_account.document-sa.id

  depends_on = [ azurerm_function_app.create-documents-fa ]
}

