# GitHub Actions and Azure OIDC setup

Terraform workflows use GitHub OIDC. Do not add a client secret. Configure each Entra federated credential with audience `api://AzureADTokenExchange` and the exact subject shown below.

## Configure the repository

1. In GitHub, open **Settings → Environments**. Create `dev`, `dev-bootstrap`, and `dev-destroy`. Require reviewers on bootstrap and destroy. Currently only `dev` has Terraform configuration; create matching `qa`, `uat`, or `prod` files and environments before selecting those options.
2. Under **Settings → Secrets and variables → Actions → Variables**, set repository-level `ARM_CLIENT_ID`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` for the shared app used by dev, bootstrap, destroy, and the ACR workflow. Set repository-level `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_STORAGE_ACCOUNT`, and `TF_BACKEND_CONTAINER` for the dev state backend.
3. If PostgreSQL is enabled, add `POSTGRES_ADMIN_PASSWORD` as a secret to the selected environment and its protected bootstrap/destroy environments.
4. In Microsoft Entra admin center, add federated credentials in the appropriate app registrations: **App registrations → [app] → Certificates & secrets → Federated credentials → Add credential → GitHub Actions deploying Azure**. The shared ARM app needs the `dev`, `dev-bootstrap`, and `dev-destroy` subjects. Match issuer, subject, and audience exactly to **Federated token details** in the workflow log. Use issuer `https://token.actions.githubusercontent.com` and audience `api://AzureADTokenExchange`. Do not create client secrets or add pull-request subjects to the privileged app.
5. Assign the Azure roles listed below to each app's service principal. For every app, use its application/client ID in GitHub variables and its service principal object ID where Terraform expects an object ID.

After setup, open **Actions** and manually run Plan, Apply, RBAC Bootstrap, or Destroy for the target environment. Inspect plans and approve the matching protected environment. Bootstrap uses `<env>-bootstrap`; destroy uses `<env>-destroy`.

## Deployment identity and GitHub Environments

The current setup uses one repository-level ARM app for normal Plan/Apply, RBAC bootstrap, destroy, and ACR image pushes. `ARM_CLIENT_ID` is its application/client ID; `deployment_principal_object_id` in dev tfvars is its service principal object ID. They are different IDs.

| Environment pattern | Variables | OIDC subject pattern |
| --- | --- | --- |
| `<env>` | Repository-level `ARM_*` (shared app) | `repo:makrsoftitsolutions@348376686/devops-project@1468388333:environment:<env>` |
| `<env>-bootstrap` | Repository-level `ARM_*` (shared app) | `repo:makrsoftitsolutions@348376686/devops-project@1468388333:environment:<env>-bootstrap` |
| `<env>-destroy` | Repository-level `ARM_*` (shared app) | `repo:makrsoftitsolutions@348376686/devops-project@1468388333:environment:<env>-destroy` |

This shared identity is a deliberate exception to least privilege. The app currently has `Contributor` and `User Access Administrator` at subscription scope, plus state access. Every workflow that can obtain a token for any federated subject on this app receives those same Azure permissions; GitHub Environment approvals do not restrict Azure roles after authentication. Prefer separate deployment, bootstrap, and destroy app registrations for production.

Require reviewer approval and restrict deployment branches on each environment; restrict `<env>-bootstrap` and `<env>-destroy` to a small admin group. Add the secret `POSTGRES_ADMIN_PASSWORD` to each environment only if PostgreSQL is enabled. The workflows map it to Terraform as `TF_VAR_postgres_admin_password`; never store it in tfvars.

| Identity | Required Azure roles |
| --- | --- |
| Shared ARM identity (current dev setup) | `Contributor` and `User Access Administrator` at subscription scope, plus `Storage Blob Data Contributor` on the state container. These permissions are shared by Plan, Apply, Bootstrap, Destroy, and ACR workflows. |

The shared ARM identity's `User Access Administrator` grant is broader than the conditional role-assignment delegation managed by Terraform. Anyone able to run a workflow with a matching OIDC subject can exercise the app's full subscription-level permissions. Optional app data roles use `storage_blob_role_assignments`, `event_hubs_role_assignments`, and `service_bus_role_assignments` with principal object IDs in tfvars.

## One-time RBAC bootstrap

The current shared ARM app already has subscription-level `User Access Administrator`, so the targeted bootstrap workflow can create the configured grants. This also means the normal deployment and destroy workflows have that broad permission. The separate-identity setup below is the recommended least-privilege alternative; do not use it alongside the shared repository ARM values unless you intentionally want the bootstrap environment to override them.

With the current shared app, the targeted bootstrap plan may create the spoke resource group, ACR, and the AKS control-plane, AKS kubelet, and management-VM user-assigned identities as prerequisites. It must not create VNets, the AKS cluster, or the management VM; a plan-scope check fails the job if unexpected resources or deletes appear. The Cloud Shell example below is only for switching to a separate, least-privilege bootstrap app; it is not required by the current shared-app setup. Protect the `dev-bootstrap` GitHub Environment with required reviewers.

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

printf 'ARM_CLIENT_ID=%s\nARM_TENANT_ID=%s\nARM_SUBSCRIPTION_ID=%s\n' \
  "$bootstrap_client_id" \
  "$(az account show --query tenantId -o tsv)" \
  "$subscription_id"
```

To use this alternative, add the printed values as environment-level `ARM_CLIENT_ID`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` in `dev-bootstrap`; these override the repository variables for that job. Run **Actions → Terraform RBAC Bootstrap**, select `dev`, enter `BOOTSTRAP`, and review the targeted plan before the protected apply job. The bootstrap apply creates only the two constrained deployment role grants and their listed prerequisites; the regular Apply workflow provisions the network, AKS cluster, and management VM.

For the separate-identity alternative, after the first bootstrap succeeds, reduce the bootstrap identity's scope: grant it `Reader` and `User Access Administrator` on `rg-platform-dev`, then remove its subscription-level `Contributor` and `User Access Administrator` assignments. Keep `Storage Blob Data Contributor` on the state storage account. This leaves it able to read state and manage the delegated RBAC grants within dev for future bootstrap runs. An Owner or User Access Administrator must perform this initial authorization; Terraform cannot create the permission that authorizes its own first role assignment.

## Destroy workflow and sequence

The current destroy workflow uses the shared repository-level ARM app, so its broad subscription permissions are also available to the other workflows using that app. The `dev-destroy` environment still requires reviewer approval and the workflow requires typing `DESTROY`, but these gates do not provide identity-level permission separation. For isolation, use a separate destroy app with `Contributor` and `User Access Administrator` at subscription scope plus state-container `Storage Blob Data Contributor`, configured as environment-level `ARM_*` overrides.

1. Run **Actions → Terraform Plan**, select `<env>`, and inspect the plan.
2. Run **Actions → Terraform Apply**, select `<env>`, then approve the protected environment. Apply creates a fresh plan and applies it.
3. For the initial role grants or a changed ABAC condition, run **Terraform RBAC Bootstrap** for `<env>` before the full apply.
4. Run **Terraform Destroy (manual)** only when intentionally removing the environment; inspect its destroy plan and approve `<env>-destroy`.
5. The NGINX image workflow remains configured for dev; configure a corresponding identity and ACR name before using it for another environment.
