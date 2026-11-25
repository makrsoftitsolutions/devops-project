# Azure DevOps Platform Project – Dev Environment

This repository currently contains a **dev-only** Azure Terraform environment. Production configuration has been removed so the first deployment can be tested safely in the personal Azure subscription.

## What the dev environment creates by default

- `rg-network-dev` and `rg-platform-dev`
- Hub VNet (`10.0.0.0/16`) and hub subnets
- Spoke VNet (`10.1.0.0/16`) and workload subnets
- Hub and spoke Network Security Groups, associated with their subnets
- Bidirectional hub/spoke VNet peering

Optional modules are included for Azure Firewall, Bastion, Application Gateway, ACR, AKS, Key Vault and Log Analytics. They are disabled in the supplied `terraform.tfvars` to avoid unexpected costs. Enable and test them one at a time.

## Repository layout

```text
terraform/
  environments/dev/
    backend.tf
    backend.hcl
    providers.tf
    versions.tf
    main.tf
    variables.tf
    terraform.tfvars
    terraform.tfvars.example
  modules/
    acr/ aks/ application-gateway/ bastion/ firewall/
    identity/ key-vault/ log-analytics/ network/ nsg/
    peering/ private-endpoint/ route-table/
.github/workflows/
  terraform-plan.yml
  terraform-apply.yml
  terraform-destroy.yml
docs/
```

## Prerequisites

- Terraform >= 1.6
- Azure CLI
- Access to the personal Azure subscription configured in `terraform.tfvars`
- Existing Azure Storage account and private blob container for remote state

## Azure login and subscription

```powershell
az login --tenant "a24223b8-0a32-4862-922d-d3f2545866a2"
az account set --subscription "aa61b080-74f9-41ed-a75f-8e60a60ccae4"
az account show --output table
```

The account running Terraform needs Azure resource deployment permissions. For remote state with Azure AD authentication, it also needs **Storage Blob Data Contributor** on the state storage account or container. The storage account and container must already exist.

## Configure remote state

Review `terraform/environments/dev/backend.hcl`. The delivered values are based on the state storage details supplied for this project:

- Resource group: `rg-tfstate-devops`
- Storage account: `stmakrdevops001`
- Container: `tfstate`
- State key: `dev.terraform.tfstate`

Confirm these values match the resources in your subscription before initialization. Backend configuration is separate from the AzureRM provider configuration.

## Deploy dev from Windows PowerShell

```powershell
cd C:\path\to\devops-project\terraform\environments\dev

az account set --subscription "aa61b080-74f9-41ed-a75f-8e60a60ccae4"

terraform fmt -recursive
terraform init -backend-config="backend.hcl" -reconfigure
terraform validate
terraform plan -var-file="terraform.tfvars"
```

Review the complete plan. Only if it contains the expected dev resources, run:

```powershell
terraform apply -var-file="terraform.tfvars"
```

Do not run `terraform destroy` against the state storage account. The state storage is a separately managed prerequisite.

## Optional services and costs

In `terraform.tfvars`, enable only what you intend to test:

- `enable_log_analytics`
- `enable_firewall`
- `enable_bastion`
- `enable_application_gateway`
- `enable_acr`
- `enable_aks`
- `enable_key_vault`

Firewall, Bastion, Application Gateway and AKS can create significant ongoing charges. ACR, Key Vault and Log Analytics may also incur charges. Check regional SKU availability, quotas, naming uniqueness and pricing before enabling.

## GitHub Actions

The workflows are dev-only and use GitHub OIDC. Configure GitHub repository/environment variables:

- `ARM_CLIENT_ID`
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID`
- `TF_BACKEND_RESOURCE_GROUP`
- `TF_BACKEND_STORAGE_ACCOUNT`
- `TF_BACKEND_CONTAINER`
- `TF_BACKEND_KEY`

The federated credential subject must match the repository branch or the GitHub `dev` environment used by the workflow. Grant the identity Contributor at the required deployment scope and Storage Blob Data Contributor on the state storage scope. A hosted runner must be able to reach the storage endpoint.

## Network notes

The hub/spoke VNets are peered in both directions. Peering alone does not configure forced tunneling. Do not assume traffic is routed through Azure Firewall; explicit UDRs, firewall rules, DNS and connectivity validation are required.
