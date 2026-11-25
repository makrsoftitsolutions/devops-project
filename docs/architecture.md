# Dev architecture

## Logical topology

- Hub resource group and hub VNet for shared connectivity.
- Spoke resource group and spoke VNet for application workloads.
- Bidirectional VNet peering.
- One NSG associated with each VNet's subnets.
- Optional modules for Firewall, Bastion, Application Gateway, ACR, AKS, Key Vault and Log Analytics.

## Address plan

| Network | CIDR |
|---|---|
| Hub VNet | 10.0.0.0/16 |
| AzureFirewallSubnet | 10.0.1.0/26 |
| AzureBastionSubnet | 10.0.2.0/26 |
| Spoke VNet | 10.1.0.0/16 |
| AKS subnet | 10.1.0.0/22 |
| Application Gateway subnet | 10.1.4.0/24 |
| Private endpoint subnet | 10.1.5.0/24 |
| Workloads subnet | 10.1.6.0/24 |

Ensure these ranges do not overlap with VPN, on-premises or existing peered networks. VNet peering does not automatically route traffic through Azure Firewall.
