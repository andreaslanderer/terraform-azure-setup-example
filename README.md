# Purpose

This repository contains a simple Azure cloud setup using Terraform.

# Getting started

## Requirements

Make sure you have the following software installed:
* Terraform installed
* Azure CLI installed 

## Local Setup

Before you can start, you need to login to Azure:

```shell
az login
```

Afterwards, make sure you set the tenant and object id, properly:

```shell
export TF_VAR_tenant_id=$(az account show --query 'tenantId' -o tsv)
echo $TF_VAR_tenant_id

export TF_VAR_object_id=$(az ad signed-in-user show --query 'id' -o tsv)
echo $TF_VAR_object_id
```

Initializing Terraform
```shell
terraform init
```

Deploy with Terraform
```shell
terraform apply
```