# Security notes

- Use Azure CLI authentication locally and GitHub OIDC for CI/CD; avoid long-lived client secrets.
- Restrict each GitHub federated credential to the exact repository and intended subject. Prefer separate deployment, bootstrap, and destroy identities.
- The current dev setup deliberately shares one repository-level ARM app across deployment, bootstrap, and destroy. It has subscription-level `Contributor` and `User Access Administrator`; all workflows authenticated through any of its federated subjects inherit those permissions. This is a high-risk exception, not the recommended production model.
- Grant least-privilege Azure resource deployment rights and `Storage Blob Data Contributor` on the state container/account.
- Protect remote state with secure transfer, blob versioning, soft delete, and restricted network access.
- Do not commit state files, plan files, credentials, or private keys. Public SSH keys are not secrets, but keep private keys out of Terraform inputs.
- Dev Key Vault uses a private endpoint and private DNS. Optional Storage, Event Hubs, Service Bus, Azure Monitor, and PostgreSQL resources are disabled; their private endpoint, DNS, and data-plane requirements apply when enabled.
- PostgreSQL administrator credentials must come from the protected GitHub Environment secret `POSTGRES_ADMIN_PASSWORD`; the workflow maps it to `TF_VAR_postgres_admin_password`. Do not store passwords in tfvars or source control.
- Application Insights is connected to Log Analytics and is included in AMPLS when enabled. A VNet can connect to only one AMPLS; check for an existing scope before applying.
- Dev AKS uses a public API endpoint so GitHub-hosted runners can deploy directly. The deployment workflow authenticates to Azure with OIDC and currently retrieves temporary AKS admin credentials; this is dev-only and should be replaced with narrowly scoped AKS RBAC before production. The API endpoint is internet-reachable; restrict it with authorized IP ranges where feasible.
- The dev app Ingress exposes plain HTTP through a public LoadBalancer. The community `ingress-nginx` project reached end of support in March 2026; this is a temporary dev choice with no expectation of upstream security fixes. Replace it with a supported ingress controller and enable TLS before production.
- Review NSG rules, route tables, firewall policy, DNS, diagnostic settings, and cost before enabling optional services.
- Bootstrap role-assignment permissions with a separate identity that already has the required authorization when using the least-privilege model; a shared high-privilege app also shares that access with normal workflows.
- Require reviewer approval on the protected `dev`, `dev-bootstrap`, and `dev-destroy` environments. Approval gates do not isolate Azure permissions when the same app is used.
