# Makrsoft Azure platform

This repository provisions an Azure hub-and-spoke platform with reusable Terraform modules and GitHub Actions using Microsoft Entra Workload Identity Federation (OIDC). Shared Terraform code lives in `terraform/root`; environment-specific settings and backend configuration live in `terraform/environments/<environment>`.

Currently, only `dev` has a complete environment configuration. The same Terraform root and workflows support adding `qa`, `uat`, and `prod` after their environment tfvars, backend settings, GitHub Environment, OIDC trust, and Azure permissions are configured.

## Repository layout

```text
terraform/
  root/                       # Shared Terraform root module
  modules/                    # Reusable Azure modules
  environments/
    dev/                      # Dev tfvars and backend configuration
.github/workflows/            # Terraform and ACR image workflows
docker/                       # NGINX image build context
application/                  # NGINX sample app used by the AKS deployment
kubernetes/dev/               # Dev namespace, config, deployment, and service
kubernetes/arc/               # ARC runner scale set and least-privilege RBAC
database/                     # PostgreSQL schema for build-run logs
scripts/                      # Build-log persistence helper
docs/                         # Architecture and deployment notes
```

## Environment configuration

The dev inputs are in `terraform/environments/dev/terraform.tfvars`. They include the subscription, region, environment and project names, hub/spoke CIDRs and subnet prefixes, resource options, VM SKUs, and role-assignment principals. Resource names are generated from project/environment values; ACR, Key Vault, and AKS support explicit name overrides where global naming rules require them.

To prepare another environment, create `terraform/environments/qa` (or `uat`/`prod`) with a copy of the dev `terraform.tfvars` and `backend.hcl`, then update its environment, subscription, region, IP ranges, identities, feature flags, and any required unique-name overrides. The remote state key is derived as `<environment>.terraform.tfstate`, keeping state separate. Configure the matching GitHub Environment and OIDC federated credential. The workflow dropdown includes those names but stops if the environment configuration is missing.

The dev environment's resource details, bootstrap requirements, and quota notes are in [terraform/environments/dev/README.md](terraform/environments/dev/README.md).

The shared root includes opt-in modules for PostgreSQL Flexible Server, Storage, Event Hubs, Service Bus, Application Insights, and Azure Monitor diagnostics/private link. Dev enables Azure Monitor Private Link for Log Analytics; the other added data services are disabled until their costs, names, credentials, and client identities are confirmed. Private endpoints and DNS links for Key Vault, optional ACR/Blob/messaging, and Azure Monitor cover hub and spoke VNets; PostgreSQL uses VNet injection and its DNS zone is linked to both VNets. See the [GitHub OIDC setup guide](docs/github-actions-setup.md) for role assignments, protected environments, and workflow steps.

## Terraform operations

Run Plan, Apply, and Destroy through the protected GitHub Actions workflows. They use GitHub OIDC and the environment-specific remote state. See [GitHub Actions setup](docs/github-actions-setup.md).

## GitHub Actions

Plan, Apply, Bootstrap, and Destroy workflows run only through manual dispatch and use protected GitHub Environments. They inherit the repository-level `ARM_*` identity unless an environment-specific override is configured.

Configure these repository-level Actions variables:

- `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`
- `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_STORAGE_ACCOUNT`, `TF_BACKEND_CONTAINER`

The common ARM app currently has subscription-level `Contributor` and `User Access Administrator`; those permissions are available to every manually dispatched workflow subject federated to that app, not just Bootstrap and Destroy. The backend key is generated from the selected environment; `TF_BACKEND_KEY` is not required. Dev keeps ACR public so GitHub-hosted runners can connect; private ACR needs Premium SKU and a VNet-connected runner.

## NGINX image workflow

The `Build and Push NGINX Image` workflow builds from `docker/` and pushes `nginx-demo:<commit-sha>` to ACR. Commits under `docker/` target dev; manual runs can select another configured environment. Apply Terraform and grant `AcrPush` before running it.

The **Bootstrap ARC runners in AKS (dev)** workflow installs an ephemeral Actions Runner Controller (ARC) scale set from a GitHub larger runner with private VNet access. The **Build and Deploy NGINX to AKS (dev)** workflow builds and pushes on `ubuntu-latest`, then dispatches a one-job ARC runner pod to deploy into private AKS and store build output/status in the existing PostgreSQL database. The ARC scale set is named `arc-aks-dev`, has a maximum of one runner, and deletes runner pods after each job. See [the deployment runbook](docs/deployment.md) for required runner, GitHub App, and PostgreSQL setup. The Service remains `ClusterIP`.

## Network notes

VNet CIDRs and subnet prefixes are environment inputs. Choose ranges that do not overlap with networks that will be peered or connected through VPN/ExpressRoute. VNet peering alone does not route traffic through Azure Firewall; explicit UDRs, firewall rules, and DNS are required.
