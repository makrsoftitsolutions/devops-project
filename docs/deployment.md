# Terraform deployment runbook

## GitHub Actions only

Use **Actions → Terraform Plan**, **Terraform Apply**, and **Terraform Destroy (manual)** for infrastructure operations. Do not run local PowerShell Terraform plans, applies, or destroys; the workflows use GitHub OIDC and the environment's remote state. Review the plan output before starting Apply. Apply generates a fresh plan and applies it only after the protected GitHub Environment approval. Destroy requires typing `DESTROY`, reviewing its plan, and approval in `dev-destroy`.

Configure the identities, federated credentials, backend variables, GitHub Environments, approvals, and Azure RBAC from the [GitHub Actions setup guide](github-actions-setup.md). Only `dev` has a Terraform environment folder today. Before selecting `qa`, `uat`, or `prod`, create a matching `terraform/environments/<environment>/terraform.tfvars`, backend settings, OIDC federated credential, and protected GitHub Environment.

## Deploy the sample app from GitHub-hosted runners

Dev AKS has a public API endpoint for access from GitHub-hosted runners. After Terraform Apply, run **Actions → Build and Deploy NGINX to AKS (dev)** manually, or push a change to the configured `main` paths. Both build and deploy jobs run on `ubuntu-latest`. The build job authenticates to Azure with OIDC, builds the image, and pushes it to ACR. The deploy job authenticates separately, gets temporary AKS admin credentials, installs the pinned NGINX Ingress Controller chart, applies the `kubernetes/dev/` manifests, updates the image, and waits for the rollout. The temporary kubeconfig is removed at the end of the job.

No ARC controller, runner scale set, GitHub App, or runner pod is required in AKS. The Ingress exposes the app over plain HTTP through a public LoadBalancer; it has no TLS configuration or hostname. Community `ingress-nginx` support ended in March 2026, so this configuration is for temporary dev use only and should be replaced with a supported ingress solution before production. The public AKS API is internet-reachable; restrict authorized IP ranges where feasible. Using admin credentials is a dev-only shortcut; use narrowly scoped AKS RBAC for production.

If ARC was installed previously, remove its Helm releases and namespaces once from an authenticated shell with `kubectl` and Helm. For a GitHub-hosted runner, first sign in with Azure OIDC, run `az aks get-credentials --admin`, and install Helm with `azure/setup-helm@v4`:

```bash
helm uninstall arc-aks-dev --namespace arc-runners --ignore-not-found
helm uninstall arc-controller --namespace arc-systems --ignore-not-found
kubectl delete namespace arc-runners arc-systems --ignore-not-found=true
```

These commands remove ARC releases and running pods, not AKS or the application namespace. After cleanup, remove the unused `ARC_GITHUB_APP_ID`, `ARC_GITHUB_APP_INSTALLATION_ID`, and `ARC_GITHUB_APP_PRIVATE_KEY` secrets from the GitHub `dev` environment.

The `nginx-demo` Service remains internal-only (`ClusterIP`); the Ingress routes HTTP traffic to it through the NGINX controller's public LoadBalancer.

Optional services are controlled in each environment's `terraform.tfvars`. Dev disables Log Analytics, Azure Monitor Private Link, PostgreSQL, Storage, Event Hubs, Service Bus, Application Insights, Bastion, and Application Gateway. Only the core network, required role assignments, AKS, ACR, and Key Vault are enabled. Review private DNS, routing, role assignments, quota, and recurring costs before enabling other services.

## Private networking

Private endpoints are placed in `snet-private`; private DNS zones are linked to both hub and spoke VNets. Dev keeps the Key Vault private endpoint and DNS links. Storage, Event Hubs, and Service Bus create their private endpoints and DNS links when enabled. PostgreSQL Flexible Server uses VNet injection into a delegated subnet and a private DNS zone instead of a private endpoint.

Azure Monitor uses an Azure Monitor Private Link Scope with `PrivateOnly` ingestion and query access. Ensure clients resolve and route through its private endpoint, including VPN/on-premises clients via DNS forwarding. Check that the VNets are not already linked to a different Azure Monitor Private Link Scope before applying; Azure supports one scope per VNet. ACR private endpoint support is optional and requires Premium SKU, public access disabled, and a VNet-connected GitHub self-hosted runner. Dev keeps ACR public so the existing GitHub-hosted image workflow can reach it.

## Role assignments

Terraform creates role assignments through the shared RBAC module. The current dev setup uses a repository-level ARM app with subscription-level `Contributor` and `User Access Administrator` for Plan, Apply, Bootstrap, Destroy, and ACR workflows. This lets the bootstrap workflow create role assignments, but also gives normal workflows the same broad permissions. GitHub environment approvals do not isolate Azure access for a shared app; use separate identities for least privilege, especially before production.

## Quota and service limits

Azure quota limits still apply. Dev uses one 2-vCPU system node and one 2-vCPU user node, with the user pool capped at one node to fit the current 4-vCPU regional quota. The management VM is disabled; GitHub-hosted runners do not consume AKS node capacity. Increase quota before adding nodes or re-enabling the management VM. Check regional SKU availability, IP/vCPU quota, subnet capacity, and service costs in the GitHub plan before applying.
