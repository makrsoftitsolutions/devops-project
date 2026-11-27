# Dev environment configuration

The shared Terraform root is in `terraform/root`. This folder contains only the dev inputs and local backend settings. Resource names are derived from `project` and `environment`; the dev formulas preserve existing names such as `rg-platform-dev`, `aks-dev-platform`, `makrsoftdevacr001`, and `kv-makrsoft-dev-002`.

## Dev resources

| Component | Configuration |
| --- | --- |
| Hub and spoke VNets | `10.0.0.0/16` and `10.1.0.0/16`, with subnets defined in `terraform.tfvars` |
| Management VM | Disabled to stay within the subscription's 4-vCPU quota |
| Route tables and role assignments | Enabled for workload routing and the AKS/ACR identities |
| Azure Bastion | Disabled |
| ACR | Enabled with public network access; admin account disabled |
| AKS | Enabled with public API access and pre-created user-assigned control-plane and kubelet identities |
| AKS system pool | One `Standard_D2as_v7` node (2 vCPUs) |
| AKS user pool | One `Standard_D2as_v7` node (2 vCPUs), max count 1 |
| Azure Firewall, Application Gateway, Log Analytics, Azure Monitor Private Link | Disabled |
| Key Vault | Enabled with RBAC, private endpoint, and private DNS |
| PostgreSQL, Storage, Event Hubs, Service Bus, Application Insights | Disabled |

Only networking, route tables, required role assignments, AKS, ACR, Key Vault, and AKS node pools are enabled in dev. The Key Vault private endpoint and private DNS are retained to keep the vault private. The AKS API endpoint is public and internet-reachable; Azure/Entra authentication and Kubernetes RBAC remain enabled. Configure API-server authorized IP ranges before using this beyond dev.

East US is selected after comparing the live subscription limits and VM size catalogs in East US, UK South, Southeast Asia, and South India. On 2026-11-26, Azure reported a 4-vCPU regional quota and a 4-vCPU `Dasv7` family quota. The current dev configuration uses one 2-vCPU `Standard_D2as_v7` system node and one 2-vCPU user node, consuming that quota. The management VM is disabled; the user pool is capped at one node. ARC creates one temporary runner pod in this user pool for an application deployment. Azure's VM SKU API showed `Standard_D2as_v7` available to this subscription in East US, but a plan cannot guarantee physical capacity at apply time. Re-enable the management VM or scale the user pool only after increasing quota.

The previous apply was rejected because `Standard_D2as_v5`, `Standard_D4s_v5`, and `Standard_B2s` are restricted for this subscription in East US. Dev now uses the allowed `Standard_D2as_v7` SKU for both AKS pools. Key Vault uses `kv-makrsoft-dev-002` because `kv-makrsoft-dev-001` is held in a purge-protected deleted-vault record.

## Environment inputs and naming

The environment-specific inputs are in `terraform.tfvars`: subscription, region, environment, project, address spaces, subnet prefixes, feature flags, VM sizes, and role identities. Change subnet CIDRs when the environment must connect to networks that use overlapping ranges.

Names for resource groups, VNets, NSGs, routes, AKS, ACR, Key Vault, and optional services are generated from environment and project. Use the corresponding `*_name` override inputs when generated globally unique names are unavailable or do not meet naming policy.

Only `dev` is configured today. To add `qa`, `uat`, or `prod`, create `terraform/environments/<environment>` and copy in `terraform.tfvars` and `backend.hcl` (plus the example file if useful). Change `environment` and the environment's subscription, region, CIDRs, identities, resource options, and any required name overrides. Point each backend file at the intended state storage account; GitHub Actions uses `<environment>.terraform.tfstate`. Configure the matching GitHub Environment with OIDC and backend variables before running its workflow. The workflow environment choices exist, but a run stops if the matching configuration folder is missing.

## Terraform operations

Run all infrastructure plans, applies, and destroys through the protected GitHub Actions workflows. They use OIDC and the dev remote backend; see the [GitHub Actions setup guide](../../../docs/github-actions-setup.md).

## Provisioning dependencies

Terraform orders dependent services from resource references and explicit dependencies:

1. Resource groups, VNets, and subnets.
2. NSGs, route tables, and VNet peerings.
3. Network and workload identities and their required role assignments.
4. ACR, AKS, and Key Vault.
5. AKS ACR-pull and deployment role assignments after their principals and scopes exist.
6. Key Vault private DNS zones and VNet links before its private endpoint.

The dependency graph allows independent resources to deploy in parallel while blocking each dependent resource until its prerequisites are ready.

## Role assignments and bootstrap

Role assignments use the reusable `terraform/modules/rbac` module. Terraform manages AKS subnet `Network Contributor`, AKS kubelet `AcrPull`, and GitHub deployment `AcrPush` plus constrained assignment permissions. Optional app data roles are configured with `storage_blob_role_assignments`, `event_hubs_role_assignments`, and `service_bus_role_assignments`; each map accepts stable keys, a principal object ID, and a least-privilege role. Terraform constrains role assignment administration to the exact role/principal pairs it manages. Role IDs are checked against Microsoft's [Azure RBAC built-in role catalog](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).

The current repository-level ARM app is shared by the dev, bootstrap, and destroy workflows and has subscription-level `Contributor` and `User Access Administrator`, plus state access. This allows the bootstrap workflow to create role assignments, but also gives normal Plan/Apply and Destroy the same broad permissions. GitHub environment approvals do not isolate Azure permissions for a shared app. Prefer separate app identities before production; the bootstrap plan guard still limits resources in the targeted bootstrap plan.

If creating a new environment, inspect the plan for the assignments and scopes before the first apply. The GitHub OIDC identity for that environment needs a matching federated credential and the necessary role-assignment permissions at the new environment's resource scopes.

## GitHub Actions variables

The detailed GitHub Environment variables, OIDC subjects, Azure permissions, and workflow sequence are in the [GitHub Actions setup guide](../../../docs/github-actions-setup.md). `dev-bootstrap` is for constrained RBAC setup; `dev-destroy` is restricted to teardown. Both should require reviewer approval.

The common repository-level `ARM_*` variables are inherited by the `dev`, `dev-bootstrap`, and `dev-destroy` workflows. These protected environments provide approval gates, not separate Azure identities. The current ARM app has subscription-level `Contributor` and `User Access Administrator`; all its federated subjects share that access.

| Variable | Purpose |
| --- | --- |
| `ARM_CLIENT_ID` | Entra application/client ID shared by the infrastructure workflows |
| `ARM_TENANT_ID` | Entra tenant ID |
| `ARM_SUBSCRIPTION_ID` | Subscription for OIDC login; must match that environment's `terraform.tfvars` |
| `TF_BACKEND_RESOURCE_GROUP` | Terraform state resource group |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform state storage account |
| `TF_BACKEND_CONTAINER` | Terraform state container |
Restrict each federated credential to the repository and intended subject. The deployment, bootstrap, and destroy identities use `environment:dev`, `environment:dev-bootstrap`, and `environment:dev-destroy`. Do not give the pull-request identity role-assignment write permission.

## Build and push the NGINX image

The `Build and Push NGINX Image` workflow pushes `nginx-demo:<commit-sha>` to the selected environment's ACR. Pushes to `docker/` target dev; a manual run can select another configured environment. ACR must exist and the workflow identity must have `AcrPush` before running the image workflow.

## Networking and application traffic

The Application Gateway subnet is reserved and has no NSG or route-table association. The AKS API endpoint is public; use API-server authorized IP ranges to limit access when required. Firewall, Bastion, and Application Gateway are disabled. Enabling `enable_workload_firewall_default_route` routes only the workloads subnet through Firewall; enable it only after egress rules are configured.

Key Vault uses a private endpoint in `snet-private` and private DNS zones linked to both VNets. Optional data and monitoring services are disabled, so their private endpoints and DNS zones are not provisioned.

The AKS ingress FQDN is not configured as an Application Gateway backend. Application Gateway is disabled in dev.
