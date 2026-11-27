# Kubernetes deployment

The manifests are split by purpose:

- `dev/` contains the application namespace, ConfigMap, Deployment, and internal Service.
- `arc/` contains the runner service-account RBAC and Helm values for the Actions Runner Controller (ARC) scale set. ARC creates short-lived runner pods from these values; the runner pod itself is not a long-lived Deployment manifest.

## Deployment flow

1. Run **Bootstrap ARC runners in AKS (dev)** from GitHub-hosted `ubuntu-latest`. The dev AKS API endpoint is public. The workflow creates the namespaces and runner secret, applies the RBAC, and installs the pinned ARC controller and scale set.
2. Run **Build and Deploy NGINX to AKS (dev)** or push a change matching its configured paths. The `build` job builds and pushes the image to ACR from `ubuntu-latest`.
3. The dependent `deploy` job is scheduled on the `arc-aks-dev` scale set. The ephemeral pod uses its namespaced service account to apply the `dev/` manifests, update the image, and wait for rollout.

The management VM is disabled. Normal application deployments run inside AKS through ARC and do not require AKS admin credentials. The public AKS API endpoint is internet-reachable; configure authorized IP ranges if access should be limited.
