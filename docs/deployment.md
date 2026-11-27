# Terraform deployment runbook

## GitHub Actions only

Use **Actions → Terraform Plan**, **Terraform Apply**, and **Terraform Destroy (manual)** for infrastructure operations. Do not run local PowerShell Terraform plans, applies, or destroys; the workflows use GitHub OIDC and the environment's remote state. Review the plan output before starting Apply. Apply generates a fresh plan and applies it only after the protected GitHub Environment approval. Destroy requires typing `DESTROY`, reviewing its plan, and approval in `dev-destroy`.

Configure the identities, federated credentials, backend variables, GitHub Environments, approvals, and Azure RBAC from the [GitHub Actions setup guide](github-actions-setup.md). Only `dev` has a Terraform environment folder today. Before selecting `qa`, `uat`, or `prod`, create a matching `terraform/environments/<environment>/terraform.tfvars`, backend settings, OIDC federated credential, and protected GitHub Environment.

## Bootstrap ephemeral ARC runners and deploy the sample app

Dev AKS has a public API endpoint for bootstrap access from GitHub-hosted runners. After Terraform Apply, manually run **Actions → Bootstrap ARC runners in AKS (dev)**. It uses the dev OIDC identity to install the pinned ARC 0.15.1 controller and an ephemeral runner scale set named `arc-aks-dev`, with zero idle runners and a maximum of one active runner. The public endpoint requires Entra/Azure RBAC authentication, but is reachable from the internet; restrict its authorized IP ranges before using this beyond dev.

Create and install a GitHub App for this repository with **Administration: Read and write** and **Metadata: Read-only** repository permissions. Store its app ID, installation ID, and private key as the protected `dev` environment secrets `ARC_GITHUB_APP_ID`, `ARC_GITHUB_APP_INSTALLATION_ID`, and `ARC_GITHUB_APP_PRIVATE_KEY`. The bootstrap workflow creates the Kubernetes secret consumed by ARC; do not commit these values or put them in Helm arguments.

Run **Actions → Build and Deploy NGINX to AKS (dev)** manually, or push a change to the configured `main` paths. The build and ACR push use GitHub-hosted `ubuntu-latest`; deployment uses a one-job ARC runner pod. The pod receives only namespaced permissions to manage the app's ConfigMap, Service, and Deployment and inspect rollout status. ARC creates the pod for the queued job and removes it when the job finishes. Its Kubernetes service-account token is used for in-cluster API access; the deploy job does not request AKS administrator credentials. Build output is retained as a short-lived GitHub Actions artifact.

The `nginx-demo` Service is internal-only (`ClusterIP`); publish it only through a separately approved ingress or gateway configuration.

Optional services are controlled in each environment's `terraform.tfvars`. Dev disables Log Analytics, Azure Monitor Private Link, PostgreSQL, Storage, Event Hubs, Service Bus, Application Insights, Bastion, and Application Gateway. Only the core network, required role assignments, AKS, ACR, and Key Vault are enabled. Review private DNS, routing, role assignments, quota, and recurring costs before enabling other services.

## Private networking

Private endpoints are placed in `snet-private`; private DNS zones are linked to both hub and spoke VNets. Dev keeps the Key Vault private endpoint and DNS links. Storage, Event Hubs, and Service Bus create their private endpoints and DNS links when enabled. PostgreSQL Flexible Server uses VNet injection into a delegated subnet and a private DNS zone instead of a private endpoint.

Azure Monitor uses an Azure Monitor Private Link Scope with `PrivateOnly` ingestion and query access. Ensure clients resolve and route through its private endpoint, including VPN/on-premises clients via DNS forwarding. Check that the VNets are not already linked to a different Azure Monitor Private Link Scope before applying; Azure supports one scope per VNet. ACR private endpoint support is optional and requires Premium SKU, public access disabled, and a VNet-connected GitHub self-hosted runner. Dev keeps ACR public so the existing GitHub-hosted image workflow can reach it.

## Role assignments

Terraform creates role assignments through the shared RBAC module. The current dev setup uses a repository-level ARM app with subscription-level `Contributor` and `User Access Administrator` for Plan, Apply, Bootstrap, Destroy, and ACR workflows. This lets the bootstrap workflow create role assignments, but also gives normal workflows the same broad permissions. GitHub environment approvals do not isolate Azure access for a shared app; use separate identities for least privilege, especially before production.

## Quota and service limits

Azure quota limits still apply. Dev uses one 2-vCPU system node and one 2-vCPU user node, with the user pool capped at one node to fit the current 4-vCPU regional quota. The management VM is disabled; ARC runner pods run in the AKS user pool. Increase quota before adding nodes or re-enabling the management VM. Check regional SKU availability, IP/vCPU quota, subnet capacity, and service costs in the GitHub plan before applying.
