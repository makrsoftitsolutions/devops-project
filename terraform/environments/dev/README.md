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
| AKS user node pool | Enabled in Terraform | `usernodepl1`; autoscaler is configured for 1–2 `Standard_EC2as_v5` nodes using Azure Linux; apply requires Central India regional and ECasv5-family vCPU quota |
| AKS network permission | Enabled | AKS identity has `Network Contributor` on the AKS subnet |
| AKS image pull permission | Enabled | `AcrPull` is granted to the AKS kubelet identity on ACR |
| Azure Firewall | Temporarily disabled | `enable_firewall = false` while the subscription is at its Central India public IP quota; re-enable after quota is increased |
| Application Gateway | Temporarily disabled | `enable_application_gateway = false` while the subscription is at its Central India public IP quota; re-enable after quota is increased |
| Log Analytics | Enabled | `enable_log_analytics = true`; connected to AKS monitoring |
| Key Vault | Enabled | RBAC authorization is enabled; public access is disabled and access uses a private endpoint with private DNS |

Change these options in `terraform.tfvars` to enable or disable optional resources. `enable_aks_acr_pull` independently controls the AKS kubelet `AcrPull` assignment, subject to both AKS and ACR being enabled.

## Azure role assignments

Terraform manages these assignments through the reusable `terraform/modules/rbac` module. Stable assignment keys and root-level `moved` blocks preserve the existing state when assignments move into the module:

| Assignment | Principal | Scope | Purpose |
| --- | --- | --- | --- |
| `aks_network_contributor` | AKS user-assigned control-plane identity | AKS subnet | Allows AKS to manage the required network resources |
| `deployment_acr_rbac_admin` | GitHub Actions deployment service principal | ACR resource | Allows the deployment identity to manage ACR role assignments |
| `deployment_acr_push` | GitHub Actions deployment service principal | ACR resource | Allows the image build workflow to push images |
| `aks_acr_pull` | AKS kubelet identity | ACR resource | Allows AKS nodes to pull container images |
| `management_vm_resource_reader` | Management VM system-assigned identity | Platform resource group | Allows Azure CLI to discover and read dev resources |
| `management_vm_aks_cluster_user` | Management VM system-assigned identity | AKS cluster | Allows downloading a user kubeconfig |
| `management_vm_aks_rbac` | Management VM system-assigned identity | AKS cluster | `Azure Kubernetes Service RBAC Cluster Admin` for read/write cluster administration |

The deployment identity's existing `Role Based Access Control Administrator` assignment is limited to the ACR resource. It is required because Terraform creates the `AcrPull` and `AcrPush` assignments. A second, condition-constrained assignment is defined for the platform resource group so GitHub Actions can manage only the management VM's Reader and AKS role assignments.

The GitHub deployment service principal was checked and currently has `Contributor` at subscription scope, `Storage Blob Data Contributor` on the Terraform state storage account, and `Role Based Access Control Administrator` on the ACR. Subscription-level `Contributor` supplies the Azure resource write permissions needed to create the Firewall and Application Gateway. Terraform does not create that subscription-level `Contributor` grant; it must remain assigned through the organization's identity governance process.

`enable_acr_push` controls the Terraform-managed `AcrPush` assignment for the deployment service principal. Apply Terraform before running the image build workflow so this permission exists.

### Use the management VM to access AKS

The management VM's system-assigned identity is granted Azure `Reader` on the platform resource group, the AKS Cluster User role, and `Azure Kubernetes Service RBAC Cluster Admin` on the cluster. This permits cluster-wide read/write operations, including listing nodes. It is a powerful permission; change `management_vm_aks_rbac_role` to Reader or Writer if full cluster administration is not needed. The GitHub deployment identity's ABAC condition limits this delegated role to the management VM identity and the three supported AKS RBAC roles.

The GitHub deployment identity cannot grant itself permission to create role assignments. Each time the allowed AKS role list changes, update the delegation with an Azure identity that already has role-assignment write permission on `rg-platform-dev` before running GitHub Actions. The delegation is limited to assigning `Reader`, `Azure Kubernetes Service Cluster User Role`, and one of the allowed AKS RBAC roles to the management VM identity at this resource group or its child scopes. It cannot assign these roles to other principals. The same authorized identity needs access to the Terraform remote state. From PowerShell in this directory, run:

```powershell
az login
az account set --subscription "aa61b080-74f9-41ed-a75f-8e60a60ccae4"
terraform init -reconfigure -backend-config="backend.hcl"
terraform plan -target='module.rbac_deployment_management'
terraform apply -target='module.rbac_deployment_management'
```

Review the plan and confirm it grants the GitHub deployment principal the condition-constrained role at `rg-platform-dev`. Once the bootstrap apply succeeds, rerun **Actions > Terraform Apply**; GitHub Actions can then create the management VM assignments in the shared state. Subsequent applies use the normal workflow.

Use the VM identity instead of interactive device login after the role assignments have been applied:

```bash
az login --identity
az account show --output table
az aks get-credentials --resource-group rg-platform-dev --name aks-dev-platform --overwrite-existing
kubectl get nodes
```

The VM is in the spoke VNet and can reach the private AKS API endpoint. If `az login --identity` still reports no subscriptions, confirm the Reader assignment exists for the VM identity. `AADSTS530035` during a personal interactive login is a separate Microsoft Entra security-defaults block; do not disable security defaults to work around it. Use an authorized organizational identity or the VM's managed identity.

The Application Gateway subnet is dedicated and currently has no NSG or route-table association. Firewall deployment is temporarily disabled while the subscription's public IP quota is full. When it is re-enabled, no workload UDR will route through it unless `enable_workload_firewall_default_route` is also enabled after firewall egress rules are configured.

`enable_workload_firewall_default_route` defaults to `false`. Enable it only after the firewall policy has allow rules for required workload and AKS egress. When enabled, Terraform routes the workloads subnet's `0.0.0.0/0` traffic to the Firewall private IP. The AKS subnet is not associated with this route table.

Key Vault uses `privatelink.vaultcore.azure.net`, linked to the spoke VNet, and the private endpoint is placed in `snet-private`. The management VM can resolve the private vault address through the spoke link. Any other client network that needs vault access must also have a suitable DNS and network path.

The AKS user pool is enabled in `terraform.tfvars` and configured to autoscale between one and two `Standard_EC2as_v5` nodes with the `AzureLinux` OS SKU. The VM size is explicitly set in `aks_user_node_pool_vm_size` so it can be changed to another available SKU without modifying module code. The supplied Central India SKU list marks this 2-vCPU, 16-GiB AMD SEV-SNP confidential VM size as unrestricted for this subscription, with availability in zones 2 and 3; it is the only 2-vCPU size in that list without a subscription/zone restriction. AKS supports confidential VM node pools with Azure Linux 3.0, and selecting this size enables confidential VM behavior automatically. The earlier deployment reported zero remaining regional vCPU quota, so applying the enabled pool may fail until regional and ECasv5-family quota is granted. The list's unrestricted SKU entry does not grant quota or guarantee live capacity. The minimum needs 2 vCPUs, the configured maximum needs 4, and upgrades may need additional headroom. Linux AKS node pool names are limited to 12 lowercase alphanumeric characters, so the requested `usernodepool1` is represented by `usernodepl1`.

The AKS ingress endpoint has not been deployed yet, so `application_gateway_backend_fqdn` remains `null`. Set it to the ingress FQDN after deployment before directing application traffic through the gateway.

### One-time Terraform bootstrap

Azure does not allow a deployment identity to grant itself permission to create role assignments. The first creation of `deployment_acr_rbac_admin` must therefore run as an Azure identity that already has role-assignment write permission at the ACR scope. This is a one-time Terraform bootstrap; it does not require creating the assignment manually in the Azure portal. The management VM delegation has its own one-time Terraform bootstrap at the platform resource group.

From PowerShell, in this directory, sign in with that authorized identity. It must also be able to read and write the configured Terraform remote state:

```powershell
az login
az account set --subscription "aa61b080-74f9-41ed-a75f-8e60a60ccae4"
terraform init -reconfigure -backend-config="backend.hcl"
terraform plan -target='module.rbac_deployment_acr_admin'
terraform apply -target='module.rbac_deployment_acr_admin'
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
| `ACR_NAME` | Optional ACR registry name override for the NGINX image workflow; defaults to `makrsoftdevacr001` |
| `TF_BACKEND_RESOURCE_GROUP` | Terraform state resource group |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform state storage account |
| `TF_BACKEND_CONTAINER` | Terraform state container |
| `TF_BACKEND_KEY` | Terraform state file key |
| `MANAGEMENT_ADMIN_SSH_PUBLIC_KEY` | Public SSH key used by the apply workflow for the management VM |

The GitHub OIDC federated credential must match the repository and the `dev` GitHub Environment used by the apply job.

## Build and push the NGINX image

The `docker/` directory contains a minimal NGINX image and landing page. The `Build and Push NGINX Image` workflow authenticates to Azure with the existing GitHub OIDC identity, logs in to ACR, and pushes `nginx-demo:<commit-sha>`.

The workflow runs when files under `docker/` change or can be started manually from **Actions > Build and Push NGINX Image > Run workflow**. It uses `makrsoftdevacr001` when the GitHub `dev` environment does not define `ACR_NAME`; set that variable only if the registry name differs. The workflow pushes the image to ACR; deploying it to AKS requires a separate Kubernetes deployment manifest or Helm release.

## Useful commands

Run from `terraform/environments/dev`:

```powershell
terraform fmt -check -recursive
terraform init -reconfigure -backend-config="backend.hcl"
terraform validate
terraform plan
```

Use the GitHub Actions workflow for routine applies so that deployments use the configured OIDC identity and remote state.
