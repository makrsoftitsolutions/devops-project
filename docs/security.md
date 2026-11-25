# Security notes

- Use Azure CLI authentication locally and GitHub OIDC for CI/CD; avoid long-lived client secrets.
- Keep the GitHub federated credential restricted to the exact repository branch or protected `dev` environment.
- Grant least-privilege Contributor access at the deployment scope and Storage Blob Data Contributor on the state container/account.
- Protect remote state with secure transfer, blob versioning, soft delete and restricted network access.
- Do not commit state files, plan files, credentials or private keys.
- The sample optional Key Vault and ACR modules use public network access; private access requires private endpoints, private DNS and runner/client network reachability.
- AKS is configured as a private cluster in the module. A GitHub-hosted runner cannot reach its private Kubernetes API without a suitable network path.
- Review NSG rules, route tables, firewall policy, DNS, diagnostic settings and cost before enabling optional services.
