# Dev environment configuration

The shared Terraform root is in `terraform/root`. This folder contains only the dev inputs and local backend settings. Resource names are derived from `project` and `environment`; the dev formulas preserve existing names such as `rg-platform-dev`, `aks-dev-platform`, `makrsoftdevacr001`, and `kv-makrsoft-dev-001`.

## Dev resources

| Component | Configuration |
| --- | --- |
| Hub and spoke VNets | `10.0.0.0/16` and `10.1.0.0/16`, with subnets defined in `terraform.tfvars` |
| Management VM | Enabled, private, `Standard_B2als_v2`, in zone 1, with a pre-created user-assigned identity |
| Azure Bastion | Enabled in the hub |
| ACR | Enabled; admin account disabled |
| AKS | Enabled; private cluster with pre-created user-assigned control-plane and kubelet identities |
| AKS system pool | One node; `aks_system_vm_size` defaults to `Standard_D2s_v5` |
| AKS user pool | Enabled; `Standard_D2s_v5`, autoscale 0–2, starts at zero nodes |
| Azure Firewall | Disabled to preserve the limited regional public IP quota; its separate management IP is optional and off unless forced tunneling is required |
| Application Gateway | Disabled to preserve the limited regional public IP quota; backend FQDN is unset |
| Log Analytics | Enabled and connected to AKS monitoring |
| Key Vault | Enabled with RBAC, private endpoint, and private DNS |
| PostgreSQL Flexible Server | Optional; VNet-injected in a delegated subnet with private DNS |
| Storage Account | Optional; public access disabled and Blob private endpoint/DNS enabled |
| Event Hubs | Optional; namespace and hub use private endpoint/DNS |
| Service Bus | Optional; namespace and queue use private endpoint/DNS |
| Application Insights | Optional; linked to Log Analytics |
| Azure Monitor diagnostics | Diagnostic settings send enabled service logs to Log Analytics |
| Azure Monitor Private Link | Enabled for Log Analytics with an AMPLS private endpoint and five DNS zones |

PostgreSQL, Storage, Event Hubs, Service Bus, and Application Insights are disabled in dev by default. Azure Monitor Private Link is enabled for the existing Log Analytics workspace. Review the plan, SKU availability, recurring private-endpoint costs, and app identity/RBAC before enabling other services. PostgreSQL additionally needs `POSTGRES_ADMIN_PASSWORD` configured in the protected `dev`, `dev-bootstrap`, and `dev-destroy` GitHub Environments. Do not place that password in `terraform.tfvars`. Generated PostgreSQL, Storage, Event Hubs, and Service Bus names may need environment-specific overrides for global uniqueness.

East US is selected after comparing the live subscription limits and VM size catalogs in East US, UK South, Southeast Asia, and South India. On 2026-11-26, Azure listed 1,698 VM size entries in East US, 1,362 in UK South, 1,299 in Southeast Asia, and 1,120 in South India. The subscription's limits were also the same in each checked region: 4 regional vCPUs, 4 DSv5-family vCPUs, and 3 public IP addresses. The broader East US SKU catalog therefore does not increase this subscription's quota or guarantee compute capacity. The configured AKS system pool and management VM each use 2 vCPUs, consuming the 4-vCPU quota; the user pool starts at zero and cannot scale until quota is increased or another VM is removed. The current apply was rejected because the subscription policy disallows `Standard_D2s_v5` for AKS, and Azure reported temporary zone-1 capacity limits for management VM size `Standard_B2als_v2`. Before retrying, have the subscription administrator allow an AKS-compatible 2-vCPU SKU (and confirm quota), and select a management VM size/zone with current capacity. With AKS standard load balancer egress and Bastion, only one public IP remains under the limit of three. Enabling both public Azure Firewall and public Application Gateway would exceed that limit; use one at a time, make one frontend private, or request more public IP quota. East US moves all regional resources and data out of India, so retain it only if that residency and the added user latency are acceptable. Recheck `az vm list-usage --location eastus`, `az network list-usages --location eastus`, and `az vm list-sizes --location eastus` before applying. SKU listings do not guarantee current capacity; Azure can still reject a deployment when a size is temporarily unavailable.

## Environment inputs and naming

The environment-specific inputs are in `terraform.tfvars`: subscription, region, environment, project, address spaces, subnet prefixes, feature flags, VM sizes, and role identities. Change subnet CIDRs when the environment must connect to networks that use overlapping ranges.

Names for resource groups, VNets, NSGs, routes, the management VM, Log Analytics, Firewall, Bastion, Application Gateway, AKS, ACR, Key Vault, PostgreSQL, Storage, Event Hubs, and Service Bus are generated from environment and project. Use the corresponding `*_name` override inputs when generated globally unique names are unavailable or do not meet naming policy.

Only `dev` is configured today. To add `qa`, `uat`, or `prod`, create `terraform/environments/<environment>` and copy in `terraform.tfvars` and `backend.hcl` (plus the example file if useful). Change `environment` and the environment's subscription, region, CIDRs, identities, resource options, and any required name overrides. Point each backend file at the intended state storage account; GitHub Actions uses `<environment>.terraform.tfstate`. Configure the matching GitHub Environment with OIDC and backend variables before running its workflow. The workflow environment choices exist, but a run stops if the matching configuration folder is missing.

## Terraform operations

Run all infrastructure plans, applies, and destroys through the protected GitHub Actions workflows. They use OIDC and the dev remote backend; see the [GitHub Actions setup guide](../../../docs/github-actions-setup.md).

## Provisioning dependencies

Terraform orders dependent services from resource references and explicit dependencies:

1. Resource groups, VNets, and subnets.
2. NSGs, route tables, and VNet peerings.
3. Network and workload identities and their required role assignments.
4. Management VM, ACR, AKS, optional Firewall/Bastion/Application Gateway, and Key Vault.
5. AKS ACR-pull and management-VM role assignments after their principals and scopes exist.
6. Private DNS zones and VNet links before their private endpoints; PostgreSQL waits for its DNS link and uses a delegated subnet.
7. Application Insights and diagnostic settings after the Log Analytics workspace exists.

The dependency graph allows independent resources to deploy in parallel while blocking each dependent resource until its prerequisites are ready.

## Role assignments and bootstrap

Role assignments use the reusable `terraform/modules/rbac` module. Terraform manages AKS subnet `Network Contributor`, AKS kubelet `AcrPull`, GitHub deployment `AcrPush`, and the management VM's Reader/AKS roles. Optional app data roles are configured with `storage_blob_role_assignments`, `event_hubs_role_assignments`, and `service_bus_role_assignments`; each map accepts stable keys, a principal object ID, and a least-privilege role. Terraform constrains role assignment administration to the exact role/principal pairs it manages. Role IDs are checked against Microsoft's [Azure RBAC built-in role catalog](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).

The deployment identity cannot grant itself the first role-assignment permission. Use the protected **Terraform RBAC Bootstrap** GitHub workflow with a separate OIDC identity that already has `User Access Administrator` and `Reader` on `rg-platform-dev` and state access. An existing Owner/User Access Administrator must grant those bootstrap permissions once; there is no Terraform-only path around that first authorization. The bootstrap creates the constrained grants and only the prerequisite resource group, ACR, and user-assigned identities; a plan guard prevents it from creating the VNet, AKS cluster, or management VM. Normal full plans and applies provision those compute and network resources through the deployment identity.

If creating a new environment, inspect the plan for the assignments and scopes before the first apply. The GitHub OIDC identity for that environment needs a matching federated credential and the necessary role-assignment permissions at the new environment's resource scopes.

## GitHub Actions variables

The detailed GitHub Environment variables, OIDC subjects, Azure permissions, and workflow sequence are in the [GitHub Actions setup guide](../../../docs/github-actions-setup.md). `dev-bootstrap` is for constrained RBAC setup; `dev-destroy` is restricted to teardown. Both should require reviewer approval.

The pull-request Plan workflow uses separate repository variables `PLAN_ARM_CLIENT_ID`, `PLAN_ARM_TENANT_ID`, and `PLAN_ARM_SUBSCRIPTION_ID`, plus a `pull_request` federated credential for its read-only identity.

Set these variables in the protected GitHub Environments:

| Variable | Purpose |
| --- | --- |
| `ARM_CLIENT_ID` | Entra application/client ID for the GitHub deployment identity |
| `ARM_TENANT_ID` | Entra tenant ID |
| `ARM_SUBSCRIPTION_ID` | Subscription for OIDC login; must match that environment's `terraform.tfvars` |
| `TF_BACKEND_RESOURCE_GROUP` | Terraform state resource group |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform state storage account |
| `TF_BACKEND_CONTAINER` | Terraform state container |
Restrict each federated credential to the repository and intended subject. The deployment, bootstrap, and destroy identities use `environment:dev`, `environment:dev-bootstrap`, and `environment:dev-destroy`. Do not give the pull-request identity role-assignment write permission.

## Build and push the NGINX image

The `Build and Push NGINX Image` workflow pushes `nginx-demo:<commit-sha>` to the selected environment's ACR. Pushes to `docker/` target dev; a manual run can select another configured environment. ACR must exist and the workflow identity must have `AcrPush` before running the image workflow.

## Networking and application traffic

The Application Gateway subnet is dedicated and has no NSG or route-table association. Firewall deployment remains disabled while the public IP quota is exhausted. Enabling `enable_workload_firewall_default_route` routes only the workloads subnet through Firewall; enable it only after egress rules are configured. The AKS subnet is not associated with that route table.

Key Vault, Storage Blob, Event Hubs, and Service Bus use private endpoints in `snet-private` and private DNS zones linked to both spoke and hub VNets. Event Hubs and Service Bus share `privatelink.servicebus.windows.net`. PostgreSQL Flexible Server uses VNet injection into the dedicated delegated `snet-postgres` subnet; its private DNS zone is linked to both VNets. Azure Monitor uses an AMPLS linked to Log Analytics and, when enabled, Application Insights, with one private endpoint and five DNS zones linked to both VNets. `PrivateOnly` access means Monitor ingestion and queries must resolve and route through a linked VNet. Ensure custom DNS, VPN, or on-prem clients forward these zones correctly. Each VNet can connect to only one AMPLS, so verify there is no existing one before applying.

The AKS ingress FQDN is not configured as an Application Gateway backend. Set `application_gateway_backend_fqdn` after deploying ingress and confirming a reachable backend.
