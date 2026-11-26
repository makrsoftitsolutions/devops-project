# Dev environment

This directory contains the Terraform root module for the `dev` Azure environment. It provisions the platform using a hub-and-spoke network, modular Terraform, and GitHub Actions with Microsoft Entra Workload Identity Federation (OIDC).

## Current configuration

The values in `terraform.tfvars` enable:

| Component | State | Notes |
| --- | --- | --- |
| Hub and spoke VNets, subnets, peering | Enabled | Hub: `10.0.0.0/16`; spoke: `10.1.0.0/16`; includes `AzureFirewallManagementSubnet` (`10.0.3.0/26`) for Firewall Basic |
| Workload NSG and route table | Enabled | Associated with the workloads subnet |
| Azure Bastion | Enabled | Deployed in the hub |
| Management VM | Enabled | Private VM in the spoke; access via Bastion |
| Azure Container Registry (ACR) | Enabled | Admin account disabled |
| Azure Kubernetes Service (AKS) | Enabled | Private cluster with a user-assigned control-plane identity |
| AKS network permission | Enabled | AKS identity has `Network Contributor` on the AKS subnet |
| AKS image pull permission | Enabled | `AcrPull` is granted to the AKS kubelet identity on ACR |
| Azure Firewall | Temporarily disabled | `enable_firewall = false` while the subscription is at its Central India public IP quota; re-enable after quota is increased |
| Application Gateway | Temporarily disabled | `enable_application_gateway = false` while the subscription is at its Central India public IP quota; re-enable after quota is increased |
| Log Analytics | Enabled | `enable_log_analytics = true`; connected to AKS monitoring |
| Key Vault | Enabled | RBAC authorization is enabled; public access is disabled and access uses a private endpoint with private DNS |

Change these options in `terraform.tfvars` to enable or disable optional resources. `enable_aks_acr_pull` independently controls the AKS kubelet `AcrPull` assignment, subject to both AKS and ACR being enabled.

## Azure role assignments

Terraform manages the following assignments in `main.tf`:

| Assignment | Principal | Scope | Purpose |
| --- | --- | --- | --- |
| `aks_network_contributor` | AKS user-assigned control-plane identity | AKS subnet | Allows AKS to manage the required network resources |
| `deployment_acr_rbac_admin` | GitHub Actions deployment service principal | ACR resource | Allows the deployment identity to manage ACR role assignments |
| `deployment_acr_push` | GitHub Actions deployment service principal | ACR resource | Allows the image build workflow to push images |
| `aks_acr_pull` | AKS kubelet identity | ACR resource | Allows AKS nodes to pull container images |

The deployment identity's `Role Based Access Control Administrator` assignment is limited to the ACR resource. It is required because Terraform creates the `AcrPull` and `AcrPush` assignments. This role is broader than either registry data role; review its scope and role assignment conditions against your production access policy.

The GitHub deployment service principal was checked and currently has `Contributor` at subscription scope, `Storage Blob Data Contributor` on the Terraform state storage account, and `Role Based Access Control Administrator` on the ACR. Subscription-level `Contributor` supplies the Azure resource write permissions needed to create the Firewall and Application Gateway. Terraform does not create that subscription-level `Contributor` grant; it must remain assigned through the organization's identity governance process.

`enable_acr_push` controls the Terraform-managed `AcrPush` assignment for the deployment service principal. Apply Terraform before running the image build workflow so this permission exists.

The Application Gateway subnet is dedicated and currently has no NSG or route-table association. Firewall deployment is temporarily disabled while the subscription's public IP quota is full. When it is re-enabled, no workload UDR will route through it unless `enable_workload_firewall_default_route` is also enabled after firewall egress rules are configured.

`enable_workload_firewall_default_route` defaults to `false`. Enable it only after the firewall policy has allow rules for required workload and AKS egress. When enabled, Terraform routes the workloads subnet's `0.0.0.0/0` traffic to the Firewall private IP. The AKS subnet is not associated with this route table.

Key Vault uses `privatelink.vaultcore.azure.net`, linked to the spoke VNet, and the private endpoint is placed in `snet-private`. The management VM can resolve the private vault address through the spoke link. Any other client network that needs vault access must also have a suitable DNS and network path.

The AKS ingress endpoint has not been deployed yet, so `application_gateway_backend_fqdn` remains `null`. Set it to the ingress FQDN after deployment before directing application traffic through the gateway.

### One-time Terraform bootstrap

Azure does not allow a deployment identity to grant itself permission to create role assignments. The first creation of `deployment_acr_rbac_admin` must therefore run as an Azure identity that already has role-assignment write permission at the ACR scope. This is a one-time Terraform bootstrap; it does not require creating the assignment manually in the Azure portal.

From PowerShell, in this directory, sign in with that authorized identity. It must also be able to read and write the configured Terraform remote state:

```powershell
az login
az account set --subscription "aa61b080-74f9-41ed-a75f-8e60a60ccae4"
terraform init -reconfigure -backend-config="backend.hcl"
terraform plan -target='azurerm_role_assignment.deployment_acr_rbac_admin[0]'
terraform apply -target='azurerm_role_assignment.deployment_acr_rbac_admin[0]'
```

Before approving the plan, confirm the target is the GitHub Actions service principal and the scope is the intended ACR. The target option is used only for this initial bootstrap. Terraform stores the resulting assignment in the remote state.

After the bootstrap succeeds, commit and push the Terraform changes, then run **Actions > Terraform Apply > Run workflow**. The workflow authenticates as the GitHub OIDC deployment identity, creates the registry data-role assignments, and applies other pending changes. Subsequent applies use the normal workflow without the `-target` option.

If the bootstrap must run entirely in GitHub Actions, use a separate OIDC identity that already has role-assignment write permission on the ACR. The current deployment identity cannot bootstrap its own authorization.

## Terraform state

Terraform state uses the Azure Storage backend configured by `backend.hcl` and `backend.tf`:

| Setting | Value |
| --- | --- |
| Resource group | `rg-tfstate-devops` |
| Storage account | `stmakrdevops001` |
| Container | `tfstate` |
| State key | `dev.terraform.tfstate` |

The GitHub Actions identity needs Azure AD/OIDC access to the state container, typically through `Storage Blob Data Contributor`, in addition to the Azure resource permissions required by the configuration.

## GitHub Actions

The repository has separate Terraform Plan and Terraform Apply workflows under `.github/workflows/`.

- **Plan** runs for pull requests that change Terraform files and can also be started manually.
- **Apply** runs manually, initializes the remote backend, validates the configuration, creates a plan, and applies it.
- Both workflows use GitHub OIDC; no client secret is required.
- Both use a concurrency group to prevent overlapping operations against the dev state.

Configure these GitHub repository or environment variables:

| Variable | Purpose |
| --- | --- |
| `ARM_CLIENT_ID` | Entra application/client ID for the GitHub deployment identity |
| `ARM_TENANT_ID` | Entra tenant ID |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID |
| `ACR_NAME` | ACR registry name used by the NGINX image workflow (dev: `makrsoftdevacr001`) |
| `TF_BACKEND_RESOURCE_GROUP` | Terraform state resource group |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform state storage account |
| `TF_BACKEND_CONTAINER` | Terraform state container |
| `TF_BACKEND_KEY` | Terraform state file key |
| `MANAGEMENT_ADMIN_SSH_PUBLIC_KEY` | Public SSH key used by the apply workflow for the management VM |

The GitHub OIDC federated credential must match the repository and the `dev` GitHub Environment used by the apply job.

## Build and push the NGINX image

The `docker/` directory contains a minimal NGINX image and landing page. The `Build and Push NGINX Image` workflow authenticates to Azure with the existing GitHub OIDC identity, logs in to ACR, and pushes `nginx-demo:<commit-sha>`.

The workflow runs when files under `docker/` change or can be started manually from **Actions > Build and Push NGINX Image > Run workflow**. Configure `ACR_NAME` as a variable in the GitHub `dev` environment. The workflow pushes the image to ACR; deploying it to AKS requires a separate Kubernetes deployment manifest or Helm release.

## Useful commands

Run from `terraform/environments/dev`:

```powershell
terraform fmt -check -recursive
terraform init -reconfigure -backend-config="backend.hcl"
terraform validate
terraform plan
```

Use the GitHub Actions workflow for routine applies so that deployments use the configured OIDC identity and remote state.
