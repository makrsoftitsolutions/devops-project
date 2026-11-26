# Application Gateway module

Creates an Application Gateway, static Standard public IP, listener, routing rule, and optional backend FQDN. The caller supplies environment-specific name, resource group, subnet, zones, backend FQDN, and tags. The subnet must be dedicated to Application Gateway and appropriately sized for the selected SKU.

Public IP quotas and regional SKU availability are subscription- and region-specific. Confirm both before enabling this module.
