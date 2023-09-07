#!/bin/bash

# Log function for better readability
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

# Function to check the existence of a namespace
check_namespace() {
    ns=$1
    if kubectl get namespace "$ns" &> /dev/null; then
        log "Namespace $ns exists."
    else
        log "Namespace $ns does not exist."
    fi
}

# Main script
set -e  # Exit on first error

log "Creating namespace: restricted"
echo "$(timestamp) Checking if namespace 'restricted' exists..."
if kubectl get ns restricted &> /dev/null; then
    echo "$(timestamp) Namespace 'restricted' already exists."
else
    echo "$(timestamp) Creating namespace: restricted"
    kubectl create namespace restricted
    if [ $? -ne 0 ]; then
        echo "$(timestamp) Failed to create namespace."
        exit 1
    fi
fi
check_namespace restricted

log "Applying namespace-deny-template..."
kubectl apply -f namespace-deny-template.yaml

log "Applying namespace-deny-constraint..."
kubectl apply -f namespace-deny-constraint.yaml

log "Trying to create namespace 'restricted' to test Gatekeeper..."
if kubectl create ns restricted &> /dev/null; then
    log "Namespace 'restricted' created successfully. This should not have happened. Check your Gatekeeper setup."
    exit 1
else
    log "Failed to create namespace 'restricted' as expected due to Gatekeeper constraints."
fi

log "Script completed successfully!"

kubectl delete namespace restricted

