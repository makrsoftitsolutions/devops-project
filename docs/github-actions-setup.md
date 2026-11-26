# GitHub Actions and Azure OIDC setup

Terraform workflows use GitHub OIDC. Do not add a client secret. Configure each Entra federated credential with audience `api://AzureADTokenExchange` and the exact subject shown below.

## Configure the repository

1. In GitHub, open **Settings → Environments**. For each configured Terraform environment `<env>`, create `<env>`, `<env>-bootstrap`, and `<env>-destroy`. Currently only `dev` has Terraform configuration; create the matching `qa`, `uat`, or `prod` files before selecting those options. Add required reviewers and restrict deployment branches; limit bootstrap/destroy approvals to administrators.
2. Under **Settings → Secrets and variables → Actions → Variables**, add repository variables `PLAN_ARM_CLIENT_ID`, `PLAN_ARM_TENANT_ID`, `PLAN_ARM_SUBSCRIPTION_ID`, and `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_STORAGE_ACCOUNT`, `TF_BACKEND_CONTAINER` for the dev state backend. Set the three `PLAN_ARM_*` values to the separate PR-plan app; the backend values point at the same dev backend used by Terraform.
3. Add each environment's identity variables: `<env>` uses `ARM_*`; `<env>-bootstrap` uses `BOOTSTRAP_ARM_*`; and `<env>-destroy` uses `DESTROY_ARM_*`. Repository-level `TF_BACKEND_*` variables can be reused by all workflows; environment-level values override repository values when present. If PostgreSQL is enabled, add `POSTGRES_ADMIN_PASSWORD` as an environment secret for that environment and its protected bootstrap/destroy environments.
4. In Microsoft Entra admin center, add a federated credential to each app registration: **App registrations → [app] → Certificates & secrets → Federated credentials → Add credential → GitHub Actions deploying Azure**. Set the subject to `repo:<OWNER>/<REPOSITORY>:environment:<env>`, `repo:<OWNER>/<REPOSITORY>:environment:<env>-bootstrap`, or `repo:<OWNER>/<REPOSITORY>:environment:<env>-destroy`, matching the GitHub Environment. Use `repo:<OWNER>/<REPOSITORY>:pull_request` for the PR plan identity. Set audience to `api://AzureADTokenExchange`. Do not create client secrets.
5. Assign the Azure roles listed below to each app's service principal. For every app, use its application/client ID in GitHub variables and its service principal object ID where Terraform expects an object ID.

After setup, open **Actions** and select the target environment in Plan, Apply, RBAC Bootstrap, or Destroy. Inspect plans and approve the matching protected environment. Bootstrap uses `<env>-bootstrap`; destroy uses `<env>-destroy`.

## Deployment identity and GitHub Environments

Create a deployment app/service principal for normal Plan/Apply and ACR image pushes. `ARM_CLIENT_ID` is its application/client ID; `deployment_principal_object_id` in dev tfvars is its service principal object ID. They are different IDs. Set up GitHub Environments under **Repository Settings → Environments**:

| Environment pattern | Variables | OIDC subject pattern |
| --- | --- | --- |
| `<env>` | `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` | `repo:<OWNER>/<REPOSITORY>:environment:<env>` |
| `<env>-bootstrap` | `BOOTSTRAP_ARM_CLIENT_ID`, `BOOTSTRAP_ARM_TENANT_ID`, `BOOTSTRAP_ARM_SUBSCRIPTION_ID` | `repo:<OWNER>/<REPOSITORY>:environment:<env>-bootstrap` |
| `<env>-destroy` | `DESTROY_ARM_CLIENT_ID`, `DESTROY_ARM_TENANT_ID`, `DESTROY_ARM_SUBSCRIPTION_ID` | `repo:<OWNER>/<REPOSITORY>:environment:<env>-destroy` |

The `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_STORAGE_ACCOUNT`, and `TF_BACKEND_CONTAINER` values may be repository variables shared by these environments. Set environment-level values only when an environment uses a different state backend.

Require reviewer approval and restrict deployment branches on each environment; restrict `<env>-bootstrap` and `<env>-destroy` to a small admin group. Add the secret `POSTGRES_ADMIN_PASSWORD` to each environment only if PostgreSQL is enabled. The workflows map it to Terraform as `TF_VAR_postgres_admin_password`; never store it in tfvars.

| Identity | Required Azure roles |
| --- | --- |
| Normal `<env>` deploy identity | `Contributor` at subscription, `Storage Blob Data Contributor` on the state container. Terraform-managed conditional RBAC grants allow only the configured role/principal pairs. |
| `<env>-bootstrap` identity | `Reader` and `User Access Administrator` on `rg-platform-<env>`, plus `Storage Blob Data Contributor` on the state container. |
| `<env>-destroy` identity | `Contributor` and `User Access Administrator` at subscription scope, plus `Storage Blob Data Contributor` on the state container. Keep this identity protected for teardown. |
| PR plan identity | `Reader` on the subscription and `Storage Blob Data Contributor` on the state container; no role assignment write permission. |

The normal deployment identity needs `Contributor` on the subscription to create/manage resource groups and Azure resources, plus `Storage Blob Data Contributor` on the state container for state reads/writes and locking. The Terraform RBAC module delegates only the exact role/principal pairs it manages. The deployment identity also needs `AcrPush` on ACR for the image workflow; Terraform manages this assignment. Optional app data roles use `storage_blob_role_assignments`, `event_hubs_role_assignments`, and `service_bus_role_assignments` with principal object IDs in tfvars.

## Pull-request plan identity

Use a separate, read-only plan app. Set repository variables `PLAN_ARM_CLIENT_ID`, `PLAN_ARM_TENANT_ID`, and `PLAN_ARM_SUBSCRIPTION_ID`. Give it an OIDC federated credential with subject `repo:<OWNER>/<REPOSITORY>:pull_request`, Azure `Reader`, and `Storage Blob Data Contributor` on the state container (Terraform needs blob leases to lock state during a plan). Do not grant it role-assignment write permission. Set the repository-level `TF_BACKEND_*` variables to dev's backend so PR plans can reach dev state; environment-level values override these for manual workflows. The PR plan job skips fork-originated pull requests because remote state can contain sensitive values.

## One-time RBAC bootstrap

An identity cannot grant itself `Microsoft.Authorization/roleAssignments/write`. Use a separate app/service principal for bootstrap, with only the `<env>-bootstrap` OIDC subject. Do not add subscription-level role-assignment permissions to the normal deployment app if that app also trusts `main` or `pull_request` subjects: any workflow able to get a token for one of those subjects could use the elevated permission.

For a fresh dev deployment, the targeted bootstrap plan may also create the spoke resource group and ACR as dependencies. An existing Owner must seed the bootstrap app's initial permissions. The following Cloud Shell Bash example creates the app, service principal, and dev-bootstrap federated credential. It then grants temporary subscription-level `Contributor` and `User Access Administrator` plus state-storage access so the first targeted plan can create its dependencies and role assignments. Protect the `dev-bootstrap` GitHub Environment with required reviewers before running it.

```bash
subscription_id="aa61b080-74f9-41ed-a75f-8e60a60ccae4"
subscription_scope="/subscriptions/${subscription_id}"
state_storage_scope="${subscription_scope}/resourceGroups/rg-tfstate-devops/providers/Microsoft.Storage/storageAccounts/stmakrdevops001"

az account set --subscription "$subscription_id"

bootstrap_client_id=$(az ad app create \
  --display-name github-azure-bootstrap \
  --query appId -o tsv)
bootstrap_sp_id=$(az ad sp create \
  --id "$bootstrap_client_id" \
  --query id -o tsv)

az ad app federated-credential create \
  --id "$bootstrap_client_id" \
  --parameters "{\"name\":\"github-dev-bootstrap\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:makrsoftitsolutions@348376686/devops-project@1468388333:environment:dev-bootstrap\",\"description\":\"Terraform dev RBAC bootstrap via GitHub Actions\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

az role assignment create \
  --assignee-object-id "$bootstrap_sp_id" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "$subscription_scope"
az role assignment create \
  --assignee-object-id "$bootstrap_sp_id" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "$subscription_scope"
az role assignment create \
  --assignee-object-id "$bootstrap_sp_id" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$state_storage_scope"

printf 'BOOTSTRAP_ARM_CLIENT_ID=%s\nBOOTSTRAP_ARM_TENANT_ID=%s\nBOOTSTRAP_ARM_SUBSCRIPTION_ID=%s\n' \
  "$bootstrap_client_id" \
  "$(az account show --query tenantId -o tsv)" \
  "$subscription_id"
```

Add those three printed values as variables in GitHub Environment `dev-bootstrap`. The repository-level `TF_BACKEND_*` variables can be reused. Run **Actions → Terraform RBAC Bootstrap**, select `dev`, enter `BOOTSTRAP`, and review the targeted plan before the protected apply job.

After the first bootstrap succeeds, reduce the bootstrap identity's scope: grant it `Reader` and `User Access Administrator` on `rg-platform-dev`, then remove its subscription-level `Contributor` and `User Access Administrator` assignments. Keep `Storage Blob Data Contributor` on the state storage account. This leaves it able to read state and manage the delegated RBAC grants within dev for future bootstrap runs. Repeat with environment-specific scopes and subjects when adding qa, uat, or prod. An Owner or User Access Administrator must perform this initial authorization; Terraform cannot create the permission that authorizes its own first role assignment.

## Destroy identity and workflow sequence

The normal deployment identity's ABAC condition deliberately prevents it from removing or broadening its own RBAC administrator grant. `<env>-destroy` therefore uses a separate identity with `Contributor` and `User Access Administrator` at subscription scope plus state-container `Storage Blob Data Contributor`. These broad permissions are only for teardown; protect its OIDC subject with required reviewers. The workflow additionally requires typing `DESTROY`.

1. Run **Actions → Terraform Plan**, select `<env>`, and inspect the plan.
2. Run **Actions → Terraform Apply**, select `<env>`, then approve the protected environment. Apply creates a fresh plan and applies it.
3. For the initial role grants or a changed ABAC condition, run **Terraform RBAC Bootstrap** for `<env>` before the full apply.
4. Run **Terraform Destroy (manual)** only when intentionally removing the environment; inspect its destroy plan and approve `<env>-destroy`.
5. The NGINX image workflow remains configured for dev; configure a corresponding identity and ACR name before using it for another environment.
