Application Gateway module for optional dev testing. Before enabling it, configure a
real backend target, validate subnet sizing and regional SKU availability, and add the
required NSG rules and diagnostics. The module currently creates a basic HTTP listener
with a WAF_v2 SKU; review and harden it before exposing an application publicly.
