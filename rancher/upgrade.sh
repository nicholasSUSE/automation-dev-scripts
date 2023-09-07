#!/bin/bash
set -e

RANCHER_VERSION="2.6.13"

clear 

echo "Checking local kubernetes cluster..."
kubectl cluster-info 

echo "Upgrading Rancher..."
helm get values rancher -n cattle-system -o yaml > values.yaml

  # --set useBundledSystemChart=true \
  # --set hostname=localhost \
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  -f values.yaml \
  --version $RANCHER_VERSION \
  --debug

echo "Waiting for deployment to finish"
kubectl -n cattle-system rollout status deploy/rancher 

echo "Port-forwarding...https://localhost:8443 should be available"
kubectl -n cattle-system port-forward svc/rancher 8443:443