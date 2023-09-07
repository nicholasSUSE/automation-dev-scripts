#!/bin/bash

echo "Warning!!!" 
echo "This script will seek for any Kubernetes resource with the given name and DESTROY IT!"
echo "Before running this script in a live environment, make sure you have understood its implications."
echo "Ensure backups are taken, and be aware of potential disruptions or issues that might arise from removing the detected resources."

# Ask the user if they want to proceed
read -p "Do you wish to continue? [y/N] " user_continue
if [[ $user_continue == "y" || $user_continue == "Y" ]]; then
    echo "Starting SEEK and DESTROY"
    # Ask the user to provide the TARGET resource name
    read -p "Enter the name of the Kubernetes resource you wish to seek (e.g. 'datadog'): " TARGET
else
    echo "Exiting."
    exit 0
fi

# Directory for the targeted backup
BACKUP_DIR="backup-target"
mkdir -p $BACKUP_DIR

# Array to save matched resources
declare -A TARGET_NATIVE_RESOURCES
declare -A TARGET_RESOURCES

resources_found=false  # Flag to track if any resources were found


# Function to identify and handle the resources
identify_resources() {

    echo -n "Scanning native resources: "
    for resource in "${NATIVE_RESOURCES[@]}"; do
        NATIVE_RESULTS=$(kubectl get "$resource" --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name 2>/dev/null | grep $TARGET)
        if [[ -n "$NATIVE_RESULTS" ]]; then
            resources_found=true
            echo -ne "$resource..."
            while IFS= read -r line; do
                namespace=$(echo $line | awk '{print $1}')
                name=$(echo $line | awk '{print $2}')
                echo
                echo "$resource | $namespace | $name (native)"
                TARGET_NATIVE_RESOURCES["$resource|$namespace|$name"]=1
            done <<< "$NATIVE_RESULTS"
        fi
    done
    
    echo -n "Scanning custom resources: "
    for crd in "${CRDS[@]}"; do
        CRD_RESULTS=$(kubectl get "$crd" --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name 2>/dev/null | grep $TARGET)
        if [[ -n "$CRD_RESULTS" ]]; then
            resources_found=true
            echo -ne "$crd..."
            while IFS= read -r line; do
                namespace=$(echo $line | awk '{print $1}')
                name=$(echo $line | awk '{print $2}')
                echo
                echo "$crd | $namespace | $name (CRD)"
                TARGET_RESOURCES["$crd|$namespace|$name"]=1
            done <<< "$CRD_RESULTS"
        fi
    done
}


perform_native_delete() {
    echo "Deleting native resources..."
    for key in "${!TARGET_NATIVE_RESOURCES[@]}"; do
        IFS="|" read -ra RESOURCE_DATA <<< "$key"
        resource=${RESOURCE_DATA[0]}
        namespace=${RESOURCE_DATA[1]}
        name=${RESOURCE_DATA[2]}

        echo "kubectl delete $resource $name -n $namespace"
        kubectl delete $resource $name -n $namespace
    done
}

perform_delete() {
    echo "Deleting all resources..."
    for key in "${!TARGET_RESOURCES[@]}"; do
        IFS="|" read -ra RESOURCE_DATA <<< "$key"
        resource=${RESOURCE_DATA[0]}
        namespace=${RESOURCE_DATA[1]}
        name=${RESOURCE_DATA[2]}

        echo "kubectl delete $resource $name -n $namespace"
        kubectl delete $resource $name -n $namespace
    done
}

perform_native_backup_and_delete() {
    for key in "${!TARGET_NATIVE_RESOURCES[@]}"; do
        IFS="|" read -ra RESOURCE_DATA <<< "$key"
        resource=${RESOURCE_DATA[0]}
        namespace=${RESOURCE_DATA[1]}
        name=${RESOURCE_DATA[2]}

        kubectl get $resource $name -n $namespace -o yaml > "${BACKUP_DIR}/${resource}_${namespace}_${name}.yaml"
        echo "kubectl delete $resource $name -n $namespace"
        kubectl delete $resource $name -n $namespace
    done
}

perform_backup_and_delete() {
    for key in "${!TARGET_RESOURCES[@]}"; do
        IFS="|" read -ra RESOURCE_DATA <<< "$key"
        resource=${RESOURCE_DATA[0]}
        namespace=${RESOURCE_DATA[1]}
        name=${RESOURCE_DATA[2]}

        kubectl get $resource $name -n $namespace -o yaml > "${BACKUP_DIR}/${resource}_${namespace}_${name}.yaml"
        echo "kubectl delete $resource $name -n $namespace"
        kubectl delete $resource $name -n $namespace
    done
}

perform_restore_backup() {
    for key in "${!TARGET_RESOURCES[@]}"; do
        IFS="|" read -ra RESOURCE_DATA <<< "$key"
        resource=${RESOURCE_DATA[0]}
        namespace=${RESOURCE_DATA[1]}
        name=${RESOURCE_DATA[2]}

        # Removed the get command which was fetching and overwriting the backup.
        echo "kubectl apply -f ${BACKUP_DIR}/${resource}_${namespace}_${name}.yaml"
        kubectl apply -f ${BACKUP_DIR}/${resource}_${namespace}_${name}.yaml
    done
}

action_menu() {
    # Present the user with processing options
    echo "How do you wish to proceed?"
    echo "[1] Quit"
    echo "[2] Destroy Native Resources"
    echo "[3] Destroy All Resources"
    echo "[4] Backup and Destroy Native Resources"
    echo "[5] Backup and Destroy All Resources"
    read -p "Select an option (1/2/3/4/5): " action_choice

    case $action_choice in
        1) echo "Quitting."
        exit 0
        ;;
        2) echo "Destroying Native Resources!"
        perform_native_delete 
        ;;
        3) echo "Destroying All Resources!"
        perform_delete 
        ;;
        4) echo "Backing up and Destroying Native Resources!"
        perform_native_backup_and_delete 
        echo "Check if your kubernetes cluster is operating regularly..." 
            read -p "Do you wish to restore the backup?[Y/n] " yes_no
            if [[ $yes_no == "y" || $yes_no == "Y" ]]; then
                echo "Restoring backup, better luck next time... "
                perform_restore_backup
            else
                echo "It was an honor working with you!"
            fi
        ;;
        5) echo "Backing up and Destroying All Resources!"
        perform_backup_and_delete 
        echo "Check if your kubernetes cluster is operating regularly..." 
            read -p "Do you wish to restore the backup?[Y/n] " yes_no
            if [[ $yes_no == "y" || $yes_no == "Y" ]]; then
                echo "Restoring backup, better luck next time... "
                perform_restore_backup
            else
                echo "It was an honor working with you!"
            fi
        ;;
        *) echo "Invalid choice! Exiting."
        exit 1
        ;;
    esac
}


delete_target_namespace() {
    echo "Scanning for namespace..."
    # Search for namespaces that contain the string from TARGET
    TARGET_NAMESPACE=$(kubectl get namespaces --no-headers | awk '{print $1}' | grep "${TARGET}")

    # If a matching namespace is found, prompt the user for deletion
    if [[ ! -z $TARGET_NAMESPACE ]]; then
        echo "Found namespace: $TARGET_NAMESPACE that matches the target string."
        read -p "Do you wish to delete the namespace $TARGET_NAMESPACE? [y/N] " user_ns_choice

        if [[ $user_ns_choice == "y" || $user_ns_choice == "Y" ]]; then
            echo "Deleting namespace: $TARGET_NAMESPACE..."
            kubectl delete namespace $TARGET_NAMESPACE
        fi
    else 
        echo "No namespace found, Success!"
        exit 0
    fi
}

NATIVE_RESOURCES=$(kubectl api-resources -o name)
CRDS=$(kubectl get crd -o custom-columns=NAME:.metadata.name --no-headers)
RESOURCE_TYPES=($NATIVE_RESOURCES $CRDS)

# List Resources
identify_resources

if [[ $resources_found == false ]]; then
    echo "No resources found with the given target name."
    delete_target_namespace
else
    action_menu
    delete_target_namespace
fi

