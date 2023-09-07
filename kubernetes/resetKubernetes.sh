#!/bin/bash
#kubectl drain --ignore-daemonsets --delete-local-data --force --all
# kubectl delete nodes --all --force --grace-period=0
kubectl delete pods --all --all-namespaces --force --grace-period=0
kubectl delete --all --all-namespaces services --force --grace-period=0
kubectl delete --all --all-namespaces deployments --force --grace-period=0
kubectl delete --all --all-namespaces statefulsets --force --grace-period=0
kubectl delete --all --all-namespaces configmaps --force --grace-period=0
kubectl delete --all namespaces --force --grace-period=0
kubectl delete --all secrets --all-namespaces --force --grace-period=0
