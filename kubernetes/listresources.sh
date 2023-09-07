#!/bin/bash

echo "List Kubernetes Native Resources..." 
kubectl api-resources -o name 

echo "List Kubernetes Custom Resources (CRDs)..." 
kubectl get crd -o name 