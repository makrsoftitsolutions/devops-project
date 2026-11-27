# Terraform deployment runbook

## GitHub Actions only

Use **Actions → Terraform Plan**, **Terraform Apply**, and **Terraform Destroy (manual)** for infrastructure operations. Do not run local PowerShell Terraform plans, applies, or destroys; the workflows use GitHub OIDC and the environment's remote state. Review the plan output before starting Apply. Apply generates a fresh plan and applies it only after the protected GitHub Environment approval. Destroy requires typing `DESTROY`, reviewing its plan, and approval in `dev-destroy`.

Configure the identities, federated credentials, backend variables, GitHub Environments, approvals, and Azure RBAC from the [GitHub Actions setup guide](github-actions-setup.md). Only `dev` has a Terraform environment folder today. Before selecting `qa`, `uat`, or `prod`, create a matching `terraform/environments/<environment>/terraform.tfvars`, backend settings, OIDC federated credential, and protected GitHub Environment.

## Deploy the sample NGINX app to dev AKS

Run **Actions → Deploy NGINX to AKS (dev)** manually after the dev Terraform Apply and ACR push role assignment have completed. The workflow builds `application/`, pushes an immutable commit-SHA tag to ACR, applies `kubernetes/dev/`, updates the Deployment to that image, and waits for rollout.

Dev AKS is private. The workflow must run on a trusted Linux self-hosted runner labelled `aks-dev` that has Azure CLI and Docker installed and network/DNS access to the AKS private API. The workflow uses the shared `ARM_*` OIDC variables and requests AKS administrator credentials; protect the `dev` GitHub Environment and limit runner access. The `nginx-demo` Service is internal-only (`ClusterIP`); publish it only through a separately approved ingress or gateway configuration.

Optional services are controlled in each environment's `terraform.tfvars`. Dev enables Azure Monitor Private Link for Log Analytics; PostgreSQL, Storage, Event Hubs, Service Bus, and Application Insights are disabled. Set PostgreSQL's administrator password as the protected GitHub Environment secret `POSTGRES_ADMIN_PASSWORD`; the workflow maps it into Terraform. Application Insights requires Log Analytics. Review private DNS, routing, role assignments, quota, and recurring costs before enabling services.

## Private networking

Private endpoints are placed in `snet-private`; private DNS zones are linked to both hub and spoke VNets. Key Vault and Azure Monitor Private Link are enabled in dev. Storage, Event Hubs, and Service Bus create their private endpoints and DNS links when enabled. PostgreSQL Flexible Server uses VNet injection into a delegated subnet and a private DNS zone instead of a private endpoint.

Azure Monitor uses an Azure Monitor Private Link Scope with `PrivateOnly` ingestion and query access. Ensure clients resolve and route through its private endpoint, including VPN/on-premises clients via DNS forwarding. Check that the VNets are not already linked to a different Azure Monitor Private Link Scope before applying; Azure supports one scope per VNet. ACR private endpoint support is optional and requires Premium SKU, public access disabled, and a VNet-connected GitHub self-hosted runner. Dev keeps ACR public so the existing GitHub-hosted image workflow can reach it.

## Role assignments

Terraform creates role assignments through the shared RBAC module. The current dev setup uses a repository-level ARM app with subscription-level `Contributor` and `User Access Administrator` for Plan, Apply, Bootstrap, Destroy, and ACR workflows. This lets the bootstrap workflow create role assignments, but also gives normal workflows the same broad permissions. GitHub environment approvals do not isolate Azure access for a shared app; use separate identities for least privilege, especially before production.

## Quota and service limits

Azure quota limits still apply. The dev AKS user pool starts at zero nodes because regional vCPU quota was exhausted; it may scale when capacity becomes available. Private endpoints consume addresses from `snet-private`. Check regional SKU availability, IP/vCPU quota, subnet capacity, and service costs in the GitHub plan before applying.
