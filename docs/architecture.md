# Azure platform architecture

## Logical topology

- Environment-specific hub resource group and VNet.
- Environment-specific spoke resource group and VNet for application workloads.
- Bidirectional hub/spoke VNet peering.
- Workload NSG and route table associated with the workloads subnet.
- Optional Firewall, Bastion, Application Gateway, ACR, AKS, Key Vault, Log Analytics, PostgreSQL Flexible Server, Storage, Event Hubs, Service Bus, and Application Insights modules.
- Private DNS zones and private endpoints for Key Vault, Storage Blob, Event Hubs, Service Bus, and Azure Monitor Private Link Scope. PostgreSQL uses VNet injection with its private DNS zone. Zones are linked to hub and spoke VNets.
- Azure Monitor diagnostic settings forward supported service logs to Log Analytics.

## Dev address plan

| Network | CIDR |
|---|---|
| Hub VNet | 10.0.0.0/16 |
| AzureFirewallSubnet | 10.0.1.0/26 |
| AzureBastionSubnet | 10.0.2.0/26 |
| AzureFirewallManagementSubnet | 10.0.3.0/26 |
| Spoke VNet | 10.1.0.0/16 |
| AKS subnet | 10.1.0.0/22 |
| Application Gateway subnet | 10.1.4.0/24 |
| Private endpoint subnet | 10.1.5.0/24 |
| Workloads subnet | 10.1.6.0/24 |
| Management subnet | 10.1.7.0/24 |
| PostgreSQL delegated subnet | 10.1.8.0/24 |

The authoritative ranges are configured in `terraform/environments/<environment>/terraform.tfvars`. Choose ranges that do not overlap with VPN, on-premises, or networks that will be peered. VNet peering does not automatically route traffic through Azure Firewall.

## Provisioning dependencies

Terraform derives dependencies from resource IDs and adds explicit dependencies for service prerequisites: network permissions before AKS, peering before the management VM, delegated RBAC before management VM role grants, DNS links before private endpoints, PostgreSQL DNS/subnet before the server, and Log Analytics before Application Insights/diagnostic settings. Firewall route creation depends on the Firewall private IP. Independent resources deploy in parallel.
