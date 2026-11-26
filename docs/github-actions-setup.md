# GitHub Actions and Azure OIDC setup

Terraform workflows use GitHub OIDC. Do not add a client secret. Configure each Entra federated credential with audience `api://AzureADTokenExchange` and the exact subject shown below.

## Configure the repository

1. In GitHub, open **Settings → Environments** and create `dev`, `dev-bootstrap`, and `dev-destroy`. Add required reviewers and restrict deployment branches; limit bootstrap/destroy approvals to administrators.
2. Under **Settings → Secrets and variables → Actions → Variables**, add repository variables `PLAN_ARM_CLIENT_ID`, `PLAN_ARM_TENANT_ID`, `PLAN_ARM_SUBSCRIPTION_ID`, and `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_STORAGE_ACCOUNT`, `TF_BACKEND_CONTAINER` for the dev state backend. Set the three `PLAN_ARM_*` values to the separate PR-plan app; the backend values point at the same dev backend used by Terraform.
3. Add the table's environment-specific variables under each environment. `dev` uses `ARM_*`; `dev-bootstrap` uses `BOOTSTRAP_ARM_*`; and `dev-destroy` uses `DESTROY_ARM_*`. Repeat the `TF_BACKEND_*` values in all three environments. If PostgreSQL is enabled, add `POSTGRES_ADMIN_PASSWORD` as an environment secret in all three.
4. In Microsoft Entra admin center, add a federated credential to each app registration: **App registrations → [app] → Certificates & secrets → Federated credentials → Add credential → GitHub Actions deploying Azure**. Choose the repository and the matching Environment name (`dev`, `dev-bootstrap`, or `dev-destroy`); use `pull_request` for the plan identity. Set audience to `api://AzureADTokenExchange`. Do not create client secrets.
5. Assign the Azure roles listed below to each app's service principal. For every app, use its application/client ID in GitHub variables and its service principal object ID where Terraform expects an object ID.

After setup, push the configuration changes, open **Actions**, run **Terraform Plan**, inspect the plan, then run **Terraform Apply** and approve the `dev` environment. Use **Terraform RBAC Bootstrap** first for the initial constrained role grants. Use **Terraform Destroy (manual)** only for teardown; its second job waits for approval in `dev-destroy`.

## Deployment identity and GitHub Environments

Create a deployment app/service principal for normal Plan/Apply and ACR image pushes. `ARM_CLIENT_ID` is its application/client ID; `deployment_principal_object_id` in dev tfvars is its service principal object ID. They are different IDs. Set up GitHub Environments under **Repository Settings → Environments**:

| Environment | Variables | OIDC subject |
| --- | --- | --- |
| `dev` | `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_STORAGE_ACCOUNT`, `TF_BACKEND_CONTAINER` | `repo:<OWNER>/<REPOSITORY>:environment:dev` |
| `dev-bootstrap` | `BOOTSTRAP_ARM_CLIENT_ID`, `BOOTSTRAP_ARM_TENANT_ID`, `BOOTSTRAP_ARM_SUBSCRIPTION_ID`, plus the three `TF_BACKEND_*` variables | `repo:<OWNER>/<REPOSITORY>:environment:dev-bootstrap` |
| `dev-destroy` | `DESTROY_ARM_CLIENT_ID`, `DESTROY_ARM_TENANT_ID`, `DESTROY_ARM_SUBSCRIPTION_ID`, plus the three `TF_BACKEND_*` variables | `repo:<OWNER>/<REPOSITORY>:environment:dev-destroy` |

Require reviewer approval and restrict deployment branches on all three environments; restrict `dev-bootstrap` and `dev-destroy` to a small admin group. Add the secret `POSTGRES_ADMIN_PASSWORD` to each of the three environments only if PostgreSQL is enabled. The workflows map it to Terraform as `TF_VAR_postgres_admin_password`; never store it in tfvars.

| Identity | Required Azure roles |
| --- | --- |
| Normal `dev` deploy identity | `Contributor` at subscription, `Storage Blob Data Contributor` on the state container. Terraform-managed conditional RBAC grants allow only the configured role/principal pairs. |
| `dev-bootstrap` identity | `Reader` and `User Access Administrator` on `rg-platform-dev`, plus `Storage Blob Data Contributor` on the state container. |
| `dev-destroy` identity | `Contributor` and `User Access Administrator` at subscription scope, plus `Storage Blob Data Contributor` on the state container. Keep this identity protected for teardown. |
| PR plan identity | `Reader` on the subscription and `Storage Blob Data Contributor` on the state container; no role assignment write permission. |

The normal deployment identity needs `Contributor` on the subscription to create/manage resource groups and Azure resources, plus `Storage Blob Data Contributor` on the state container for state reads/writes and locking. The Terraform RBAC module delegates only the exact role/principal pairs it manages. The deployment identity also needs `AcrPush` on ACR for the image workflow; Terraform manages this assignment. Optional app data roles use `storage_blob_role_assignments`, `event_hubs_role_assignments`, and `service_bus_role_assignments` with principal object IDs in tfvars.

## Pull-request plan identity

Use a separate, read-only plan app. Set repository variables `PLAN_ARM_CLIENT_ID`, `PLAN_ARM_TENANT_ID`, and `PLAN_ARM_SUBSCRIPTION_ID`. Give it an OIDC federated credential with subject `repo:<OWNER>/<REPOSITORY>:pull_request`, Azure `Reader`, and `Storage Blob Data Contributor` on the state container (Terraform needs blob leases to lock state during a plan). Do not grant it role-assignment write permission. Set the repository-level `TF_BACKEND_*` variables to dev's backend so PR plans can reach dev state; environment-level values override these for manual workflows. The PR plan job skips fork-originated pull requests because remote state can contain sensitive values.

## One-time RBAC bootstrap

An identity cannot grant itself `Microsoft.Authorization/roleAssignments/write`. A separate bootstrap identity needs a federated credential for `repo:<OWNER>/<REPOSITORY>:environment:dev-bootstrap`, `Reader` and `User Access Administrator` on `rg-platform-dev`, and `Storage Blob Data Contributor` on the state container. An existing Azure Owner or User Access Administrator must grant those initial permissions once. Terraform cannot create the permission that authorizes its own first role assignment.

After configuring the bootstrap identity, run **Actions → Terraform RBAC Bootstrap**, enter `BOOTSTRAP`, inspect the targeted plan, and approve it in `dev-bootstrap`. The workflow applies the constrained ACR and resource-group delegation grants. Then run the normal full Terraform Plan and Apply workflows. This keeps the bootstrap apply in GitHub Actions instead of PowerShell. For a new environment, create its resource group first or authorize the bootstrap identity at a scope that can create it.

## Destroy identity and workflow sequence

The normal deployment identity's ABAC condition deliberately prevents it from removing or broadening its own RBAC administrator grant. `dev-destroy` therefore uses a separate identity with `Contributor` and `User Access Administrator` at subscription scope plus state-container `Storage Blob Data Contributor`. These broad permissions are only for teardown; protect its OIDC subject with required reviewers. The workflow additionally requires typing `DESTROY`.

1. Run **Actions → Terraform Plan**, select `dev`, and inspect the plan.
2. Run **Actions → Terraform Apply**, select `dev`, then approve the protected environment. Apply creates a fresh plan and applies it.
3. For the initial role grants or a changed ABAC condition, run **Terraform RBAC Bootstrap** before the full apply.
4. Run **Terraform Destroy (manual)** only when intentionally removing the environment; inspect its destroy plan and approve `dev-destroy`.
5. The NGINX workflow uses the `dev` identity and needs `AcrPush`. It runs on GitHub-hosted runners, so ACR must have a reachable public endpoint. Private ACR requires a VNet-connected self-hosted runner.
