#!/bin/bash

TARGET="datadog"

# Get native resources
NATIVE_RESOURCES=$(kubectl api-resources -o name)
# Get custom resources (CRDs)
CRDS=$(kubectl get crd -o custom-columns=NAME:.metadata.name --no-headers)
# Combine the two lists
RESOURCE_TYPES=($NATIVE_RESOURCES $CRDS)

# Now, loop through and search in each resource type
for resource in "${RESOURCE_TYPES[@]}"; do
    # Capture the results into a variable. Using custom-columns to fetch namespace and name.
    RESULTS=$(kubectl get "$resource" --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name 2>/dev/null | grep datadog)
    
    # If RESULTS is not empty, transform and print the resource type, namespace, and name.
    if [[ -n "$RESULTS" ]]; then
        while IFS= read -r line; do
            # Using awk to separate namespace and name and then print with the resource type.
            echo "$resource | $(echo $line | awk '{print $1 " | " $2 " |"}')"
        done <<< "$RESULTS"
    fi
done

