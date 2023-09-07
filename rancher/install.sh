#!/bin/bash
set -e

CERT_MANAGER_VERSION="v1.10.0"
RANCHER_VERSION="2.5.17"

clear

echo "Checking local kubernetes cluster..."
kubectl cluster-info 

echo "Adding rancher helm repo..."
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable || true

echo "Creating namespace..."
kubectl create namespace cattle-system || true

echo "Applying cert-manager CRDs..."
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.crds.yaml


echo "Adding jetstack helm repo..."
helm repo add jetstack https://charts.jetstack.io || true

echo "Updating repositories"
helm repo update

echo "Installing Cert Manager..."
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version $CERT_MANAGER_VERSION \
  --debug

echo "Installing Rancher..."
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=localhost \
  --version $RANCHER_VERSION \
  --debug


clear

echo "Waiting for deployment to finish"
kubectl -n cattle-system rollout status deploy/rancher 

echo "Port-forwarding...https://localhost:8443 should be available"
kubectl -n cattle-system port-forward svc/rancher 8443:443