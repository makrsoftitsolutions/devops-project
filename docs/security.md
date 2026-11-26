# Security notes

- Use Azure CLI authentication locally and GitHub OIDC for CI/CD; avoid long-lived client secrets.
- Restrict each GitHub federated credential to the exact repository and intended subject. Prefer separate deployment, pull-request plan, bootstrap, and destroy identities; keep pull-request credentials read-only.
- The current dev setup deliberately shares one repository-level ARM app across deployment, bootstrap, and destroy. It has subscription-level `Contributor` and `User Access Administrator`; all workflows authenticated through any of its federated subjects inherit those permissions. This is a high-risk exception, not the recommended production model.
- Grant least-privilege Azure resource deployment rights and `Storage Blob Data Contributor` on the state container/account.
- Protect remote state with secure transfer, blob versioning, soft delete, and restricted network access.
- Do not commit state files, plan files, credentials, or private keys. Public SSH keys are not secrets, but keep private keys out of Terraform inputs.
- Key Vault, Storage Blob, Event Hubs, Service Bus, and Azure Monitor use private endpoints/private DNS. Storage and messaging services disable public network access when enabled. Azure Monitor AMPLS access is `PrivateOnly`; ensure client DNS and routes reach the private endpoint. PostgreSQL uses VNet injection and PostgreSQL private DNS. Client workloads need VNet/DNS reachability and appropriate data-plane RBAC.
- PostgreSQL administrator credentials must come from the protected GitHub Environment secret `POSTGRES_ADMIN_PASSWORD`; the workflow maps it to `TF_VAR_postgres_admin_password`. Do not store passwords in tfvars or source control.
- Application Insights is connected to Log Analytics and is included in AMPLS when enabled. A VNet can connect to only one AMPLS; check for an existing scope before applying.
- AKS is configured as a private cluster. A GitHub-hosted runner cannot reach its private Kubernetes API without a suitable network path.
- Review NSG rules, route tables, firewall policy, DNS, diagnostic settings, and cost before enabling optional services.
- Bootstrap role-assignment permissions with a separate identity that already has the required authorization when using the least-privilege model; a shared high-privilege app also shares that access with normal workflows.
- Require reviewer approval on the protected `dev`, `dev-bootstrap`, and `dev-destroy` environments. Approval gates do not isolate Azure permissions when the same app is used.
