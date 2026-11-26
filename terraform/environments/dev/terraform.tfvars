subscription_id = "aa61b080-74f9-41ed-a75f-8e60a60ccae4"

location    = "centralindia"
environment = "dev"
project     = "makrsoft"

enable_log_analytics                   = true
enable_firewall                        = false
enable_workload_firewall_default_route = false
enable_bastion                         = true
enable_application_gateway             = false
application_gateway_backend_fqdn       = null
enable_acr                             = true
enable_acr_push                        = true
enable_aks                             = true
enable_aks_acr_pull                    = true
deployment_principal_object_id         = "33bf4292-01a6-45ef-a0be-8ce660ae9b53"
enable_key_vault                       = true
enable_management_vm                   = true
management_vm_size                     = "Standard_B2als_v2"
management_admin_username              = "azureadmin"
management_admin_ssh_public_key        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbJA7junOZmDFYgBAHZnRag93yNaHng3CkqWjU733WL aks-management-dev"

acr_name       = "makrsoftdevacr001"
key_vault_name = "kv-makrsoft-dev-001"

aks_admin_group_object_ids = [
  "0c0e6ddf-0da2-4d12-b4a1-038baffb01ad"
]

