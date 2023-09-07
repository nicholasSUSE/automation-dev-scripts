#!/bin/bash
set -e
sudo echo -e "Sudo permissions acquired"
# Compatibility Matrix
CERT_MANAGER_VERSION="1.10.2"
RANCHER_VERSION="2.5.8"
K3S_VERSION="v1.20.6+k3s1"
#-----------------------------
RANCHER_IMAGES_TXT_URL="https://github.com/rancher/rancher/releases/download/v${RANCHER_VERSION}/rancher-images.txt"
RANCHER_LOAD_IMAGES_URL="https://github.com/rancher/rancher/releases/download/v${RANCHER_VERSION}/rancher-load-images.sh"
RANCHER_SAVE_IMAGES_URL="https://github.com/rancher/rancher/releases/download/v${RANCHER_VERSION}/rancher-save-images.sh"
#-------------------------
HOSTNAME="workstation"
ARCH="amd64"
#-------------------------
DOCKER_CONTAINER_NAME="localregistry"
DOCKER_IMAGE="registry:2"
DOCKER_REGISTRY_HOST_PORT="workstation:5000" # <REGISTRY.YOURDOMAIN.COM:PORT>
DOCKER_CERTS_PATH="/etc/docker/certs.d/"
#-------------------------
K3S_BIN_PATH="/usr/local/bin/"
K3S_IMAGES="/var/lib/rancher/k3s/agent/images/"
K3S_CERT_PATH="/etc/rancher/k3s/ssl/certs/"
K3S_REGISTRY="/etc/rancher/k3s/registries.yaml"
K3S_REG_YAML="
mirrors:
  $DOCKER_REGISTRY_HOST_PORT:
    endpoint:
      - https://$DOCKER_REGISTRY_HOST_PORT
configs:
  $DOCKER_REGISTRY_HOST_PORT:
    tls:
      ca_file: ${K3S_CERT_PATH}ca.crt
"

#----------------------------------------------------------------------------------------------------------------------
# STEPS - FUNCTIONS
# Define a function to display a menu and handle user input
menu_function() {
    clear
    echo "Select an option:"
    echo "____________________________________________________________________________________________________________________________________"
    select choice in "Soft Reset" "Hard Reset" "Continue..."; do
        case $choice in
            "Soft Reset")
                helm_reset || true
                /usr/local/bin/k3s-killall.sh || true
                ./scripts/clear_docker.sh || true
                ./scripts/clear_files.sh || true
                break
                ;;
            "Hard Reset")
                helm_reset
                /usr/local/bin/k3s-uninstall.sh || true
                ./scripts/clear_docker.sh || true
                docker rmi -f $(docker images -q) || true 
                ./scripts/clear_files.sh || true
                break
                ;;
            "Continue...")
                # Just proceed with the script
                helm_reset || true
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
    echo "____________________________________________________________________________________________________________________________________"
    sudo systemctl restart docker.service
}

helm_reset() {
    helm uninstall cert-manager -n cert-manager || true
    helm uninstall rancher -n cattle-system || true
    helm uninstall traefik -n kube-system || true 
}
step_0() {

    echo "Beginning necessary downlaod with appropriate versions...."
    ENCODED_K3S_VERSION=${K3S_VERSION//+/%2B}
    echo "...Downloading k3s binary for K3s version: ${K3S_VERSION}"
    K3S_BIN_URL="https://github.com/k3s-io/k3s/releases/download/${ENCODED_K3S_VERSION}/k3s"
    curl -L "$K3S_BIN_URL" -o "./build/k3s"

    echo "...Downloading k3s airgap images tar for K3s version: ${K3S_VERSION}"
    K3S_AIRGAP_URL="https://github.com/k3s-io/k3s/releases/download/${ENCODED_K3S_VERSION}/k3s-airgap-images-${ARCH}.tar"
    curl -L "$K3S_AIRGAP_URL" -o "./build/k3s-airgap-images-${ARCH}.tar"

    echo -e ".......Downloading rancher-images.txt for Rancher version: ${RANCHER_VERSION}"
    curl -L "$RANCHER_IMAGES_TXT_URL" -o "rancher-images.txt"
    
    echo -e ".......Downloading rancher-load-images.sh for Rancher version: ${RANCHER_VERSION}"
    curl -L "$RANCHER_LOAD_IMAGES_URL" -o "rancher-load-images.sh"
    sudo chmod +x rancher-load-images.sh
    echo -e ".......Downloading rancher-save-images.sh for Rancher version: ${RANCHER_VERSION}"
    curl -L "$RANCHER_SAVE_IMAGES_URL" -o "rancher-save-images.sh"
    sudo chmod +x rancher-save-images.sh

    # sleep 300
}
#-------------------------
step_1() {
    echo -e "Step 1 - Configure Private Registry Container..."    
    # Check if the Docker image exists
    if ! docker images -q $DOCKER_IMAGE > /dev/null; then
        echo -e "....docker image '$DOCKER_IMAGE' does not exist. Pulling it..."        
        docker pull $DOCKER_IMAGE
    fi

    # Check if the Docker container exists and get its current state
    if container_status=$(docker inspect --format '{{.State.Status}}' $DOCKER_CONTAINER_NAME 2>/dev/null); then
        case "$container_status" in
            "running" | "paused" | "exited" | * )
            echo -e "....container is in the state: $container_status. Restarting..."            
            docker stop $DOCKER_CONTAINER_NAME
            docker rm $DOCKER_CONTAINER_NAME
            ;;
        esac
    else
        echo -e "....docker container '$DOCKER_CONTAINER_NAME' does not exist."        
    fi
}
#-------------------------
gen_self_signed_certificate() {
    if [[ -f build/ca.key && -f build/ca.crt ]]; then
        ls -lah
        echo -e "....certificates already exist. Skipping generation..."        
    else
        echo -e "....creating certificates..."        
        openssl req -newkey rsa:4096 \
        -nodes -sha256 -keyout ca.key -x509 -days 99 -out ca.crt \
        -subj "/C=US/ST=Utah/L=Provo/O=SUSE/OU=Mapps/CN=$HOSTNAME" \
        -extensions SAN -config <(echo -e "[req]\ndistinguished_name=req\n[SAN]\nsubjectAltName=IP:192.168.1.10,DNS:workstation")
        # -extensions SAN -config <(echo "[req]"; echo distinguished_name=req; echo "[SAN]"; echo subjectAltName=IP:127.0.0.1)

        # Check the exit status of the openssl command
        if [ $? -ne 0 ]; then
            echo -e "Error generating certificates. Exiting..."            
            exit 1
        fi
        echo -e "....certificates creation successful..."        
        ls -lah ca*
    fi

    mv ca.crt build 
    mv ca.key build
}

step_2() {
    echo -e "_____________________________________________________________________________________________"    
    echo -e "Step 2 - K3s Private Registry Self-Signed Certificate and Docker Infrastructure"    

    echo -e "....create/download/copy/extract k3s-airgap-images-$ARCH.tar at: $K3S_IMAGES..."    
    if [ ! -d "$K3S_IMAGES" ]; then
        sudo mkdir -p "$K3S_IMAGES"
    fi

    sudo cp -f ./build/k3s-airgap-images-$ARCH.tar $K3S_IMAGES
    sudo cp -f ./build/k3s $K3S_BIN_PATH
    sudo chmod +x $K3S_BIN_PATH/k3s
    echo -e "OK"    

    echo -e "Step 2.1 - Self-signed Certificate...."    
    echo -e "....creating self-signed certificates"    
    gen_self_signed_certificate
    echo -e "OK"    


    echo -e "Step 2.2 - creating certs.d and copying self-signed certificates to Docker-Certs-Path: ${DOCKER_CERTS_PATH}${DOCKER_REGISTRY_HOST_PORT}"    
    echo -e "....check if the directory exists; if not, create it."    
    if [ ! -d "${DOCKER_CERTS_PATH}${DOCKER_REGISTRY_HOST_PORT}" ]; then
        echo -e "....directory doesn't exist. Creating it..."        
        sudo mkdir -p "${DOCKER_CERTS_PATH}${DOCKER_REGISTRY_HOST_PORT}"
    else
        echo -e "....directory already exists. Proceeding..."        
    fi
    echo -e "OK"    
    echo -e "....copy the certificate"    
    sudo cp -f build/ca.crt "${DOCKER_CERTS_PATH}${DOCKER_REGISTRY_HOST_PORT}/"
    echo -e "....certificates copied successfully."    

    echo -e "Step 2.3 - K3s should be configured to trust the self-signed certificate to communicate with the private registry."    
    echo -e "Checking and creating the directory if it doesn't exist"    
    if [ ! -d "$K3S_CERT_PATH" ]; then
        sudo mkdir -p "$K3S_CERT_PATH"
    fi
    echo -e "OK"    
    echo -e "....copying certificate to: $K3S_CERT_PATH ..."    
    if ! sudo cp build/ca.crt $K3S_CERT_PATH; then
        echo -e "Error: Failed to copy certificate to $K3S_CERT_PATH."        
        exit 1
    fi
    echo -e "OK"    
    echo -e "....updating registry.yaml file at: $K3S_REGISTRY ..."    
    if ! echo -e "$K3S_REG_YAML" | sudo tee $K3S_REGISTRY > /dev/null; then    
        echo -e "Error: Failed to create or update $K3S_REGISTRY."        
        exit 1
    fi
    sudo cat ${K3S_REGISTRY}
    echo -e "....updated registry.yaml file successfully!"    
    echo -e "K3s Self-Signed Certificate Configuration complete."    
}
#-------------------------
step_3() {
    echo -e "_____________________________________________________________________________________________"    
    echo -e "Step 3 - Starting K3s and Local Docker Container Private Registry"    

    echo "restarting docker.service"
    sudo systemctl restart docker.service
    
    echo -e "Step 3.1 -  $DOCKER_CONTAINER_NAME container, running it with self-signed certificate..."    
    run_container_registry
    container_status
    check_container_status

    echo -e "Step 3.2 - Installing K3S..."    
    
    INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_VERSION=$K3S_VERSION ./scripts/install_k3s.sh && \
    echo -e "install_k3s.sh executed successfully." || \
    (echo "Error executing install_k3s.sh." && exit 1)

    sudo systemctl enable k3s.service 
    sudo systemctl start k3s.service

    echo -e "....updating kubeconfig..."    
    sudo cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config && \
    echo -e "updated kubeconfig succesfully..." || \
    (echo "Error updating kubeconfig..." && exit 1)

    echo -e "Cluster-Info"    
    kubectl cluster-info

    # # Wait until the CoreDNS ConfigMap is available
    # until kubectl -n kube-system get configmap coredns; do
    # sleep 5
    # done

    # # Update the CoreDNS ConfigMap to add the custom DNS entry
    # kubectl -n kube-system get configmap coredns -o yaml | sed '/forward . \/etc\/resolv.conf/a \\n    workstation:53 {\n        hosts {\n            192.168.1.10 workstation\n        }\n    }' | kubectl apply -f -

    # # Restart the CoreDNS pods to pick up the changes
    # kubectl -n kube-system delete pod -l k8s-app=kube-dns
}
#-------------------------
step_4() {
    echo -e "_____________________________________________________________________________________________"    
    echo -e "Step 4 - Collecting, Saving and Loading Private Registry"    

    echo -e "....Check if the Docker container is running"    
    if ! docker ps | grep -q $DOCKER_CONTAINER_NAME; then
        echo "$DOCKER_CONTAINER_NAME is not running!"
        exit 1
    fi
    echo -e "....Check if the registry endpoint is accessible"    
    if ! curl -k -s https://${HOSTNAME}:5000/v2/ > /dev/null; then
        echo "Unable to reach registry endpoint!"
        exit 1
    fi

    echo -e "....fetch the chart and list the images which will go to the private repository..."    
    build_cert_manager_template

    echo -e "....remove the chart image names that are not extremely necessary from rancher-images.txt...."
    compact_rancher_images_txt

    echo -e "....sort and unique the images list to remove any overlap between the sources..."    
    sort -u rancher-images.txt -o rancher-images.txt

    echo -e "....run rancher-save-images.sh with the rancher-images.txt image list to create a tarball of all the required images..."    
    ./rancher-save-images.sh --image-list ./rancher-images.txt

    echo -e "....use rancher-load-images.sh to extract, tag and push rancher-images.txt and rancher-images.tar.gz to your private registry:"    
    ./rancher-load-images.sh --image-list ./rancher-images.txt --registry $DOCKER_REGISTRY_HOST_PORT
    
    mv rancher-images.tar.gz build
}

#-------------------------
step_5() {
    echo -e "_____________________________________________________________________________________________"    
    echo -e "Step 5 - Installing Rancher With Private Registries in Airgap Mode..."    

    echo -e "....Checking local kubernetes cluster..."    
    kubectl cluster-info 

    render_template_cert_manager
    install_cert_manager

    build_rancher_helm_repo
    render_template_rancher 
    install_rancher 
}
#----------------------------------------------------------------------------------------------------------------------
run_container_registry() {
    docker run -d -p 5000:5000 --name $DOCKER_CONTAINER_NAME --restart=always -v \
        $(pwd)/build/ca.crt:/certs/ca.crt -v \
        $(pwd)/build/ca.key:/certs/ca.key \
        -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/ca.crt \
        -e REGISTRY_HTTP_TLS_KEY=/certs/ca.key $DOCKER_IMAGE
}
#-------------------------
compact_rancher_images_txt() {
    # awk '
    # NR==FNR {
    #     split($1, arr, ":")
    #     images[arr[1]] = (length(arr) > 1) ? arr[2] : "";
    #     next
    # }
    # {
    #     for (image in images) {
    #         if ($1 ~ image) {
    #             if (images[image] != "") {
    #                 # Replace the version in the rancher image with the desired one
    #                 split($1, parts, ":")
    #                 $1 = parts[1] ":" images[image]
    #             }
    #             print $0
    #         }
    #     }
    # }
    # ' desired-images.txt rancher-images.txt > temp.txt

    # cp -f temp.txt rancher-images.txt

    awk 'NR==FNR {images[$1]++; next} 
    {
        for (image in images) {
            if ($1 ~ image) {
                print $0
            }
        }
    }' desired-images.txt rancher-images.txt > temp.txt

    cp -f temp.txt rancher-images.txt

}

#-------------------------
container_status() {
    echo -e "________________________________________________________________________________________"    
    echo -e "Displaying selected information about the '$DOCKER_CONTAINER_NAME' container:"    
    echo -e "  Container ID: $(docker inspect --format='{{.Id}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Name: $(docker inspect --format='{{.Name}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Image: $(docker inspect --format='{{.Config.Image}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Command: $(docker inspect --format='{{.Config.Cmd}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Labels: $(docker inspect --format='{{.Config.Labels}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "  Mounts: $(docker inspect --format='{{.Mounts}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "  Ports: $(docker inspect --format='{{.NetworkSettings.Ports}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "  State: $(docker inspect --format='{{.State.Status}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Running: $(docker inspect --format='{{.State.Running}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Paused: $(docker inspect --format='{{.State.Paused}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Restarting: $(docker inspect --format='{{.State.Restarting}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      OOMKilled: $(docker inspect --format='{{.State.OOMKilled}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Dead: $(docker inspect --format='{{.State.Dead}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Pid: $(docker inspect --format='{{.State.Pid}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      ExitCode: $(docker inspect --format='{{.State.ExitCode}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      Error: $(docker inspect --format='{{.State.Error}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      StartedAt: $(docker inspect --format='{{.State.StartedAt}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "      FinishedAt: $(docker inspect --format='{{.State.FinishedAt}}' $DOCKER_CONTAINER_NAME)"    
    echo -e "________________________________________________________________________________________"    
}
#-------------------------
check_container_status() {
    local container_status=$(docker inspect --format '{{.State.Status}}' $DOCKER_CONTAINER_NAME 2>/dev/null)

    if [ "$container_status" == "running" ]; then
        echo -e "....Container is running."        
    else
        if [ -z "$container_status" ]; then
            echo -e "....Docker container '$DOCKER_CONTAINER_NAME' does not exist."            
        else
            echo -e "....Container is in the state: $container_status. Exiting..."            
        fi
        exit 1
    fi
}
#-------------------------
build_rancher_helm_repo() {
    echo -e "....Adding rancher helm repo..."    
    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable || true

    echo -e "........ fetching and downloading .tgz rancher version"
    helm fetch rancher-stable/rancher --version="v${RANCHER_VERSION}"

    ls -lah *.tgz
    echo -e "OK"

    mv rancher-${RANCHER_VERSION}.tgz build 
}
#-------------------------
build_cert_manager_template() {
    echo -e "....Adding jetstack helm repo and updating repositories..."    
    helm repo add jetstack https://charts.jetstack.io || true
    helm repo update || true

    echo -e "....fetch the chart, extract image names, save them in a file for pull/push to a private registry..."
    helm fetch jetstack/cert-manager --version "v${CERT_MANAGER_VERSION}"
    helm template cert-manager ./cert-manager-v${CERT_MANAGER_VERSION}.tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g >> ./rancher-images.txt
    
    echo -e "OK"
    mv cert-manager-v${CERT_MANAGER_VERSION}.tgz build 
}
#-------------------------
render_template_cert_manager() {
    echo -e "....Take the fetched Helm chart and render Kubernetes manifests,"
    echo -e "....but with the image sources pointed to my private registry...."
    echo -e "........Render the cert-manager template with the options you would like to use to install the chart..."     
    echo -e "........Set the image.repository option to pull the image from your private registry."    
    echo -e "........This will create a cert-manager directory with the Kubernetes manifest files"    
    helm template cert-manager ./build/cert-manager-v${CERT_MANAGER_VERSION}.tgz --output-dir build \
        --namespace cert-manager \
        --set image.repository=$DOCKER_REGISTRY_HOST_PORT/quay.io/jetstack/cert-manager-controller \
        --set webhook.image.repository=$DOCKER_REGISTRY_HOST_PORT/quay.io/jetstack/cert-manager-webhook \
        --set cainjector.image.repository=$DOCKER_REGISTRY_HOST_PORT/quay.io/jetstack/cert-manager-cainjector \
        --set startupapicheck.image.repository=$DOCKER_REGISTRY_HOST_PORT/quay.io/jetstack/cert-manager-ctl
}
#-------------------------
install_cert_manager() {
    echo -e "....Creating namespace..."    
    kubectl create namespace cert-manager || true

    echo -e "....Applying cert-manager CRDs..."    
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

    echo -e "....Installing Cert Manager from templated files..."    
    kubectl apply -f ./build/cert-manager/templates/

    echo -e "OK"
}
#-------------------------
render_template_rancher() {
    echo -e "....Creating namespace..."    
    kubectl create namespace cattle-system 

    echo -e "........Rendering Rancher Template..."    
    helm template rancher ./build/rancher-$RANCHER_VERSION.tgz --output-dir build \
        --no-hooks \
        --namespace cattle-system \
        --set hostname=$HOSTNAME \
        --set rancherImage=$DOCKER_REGISTRY_HOST_PORT/rancher/rancher \
        --set systemDefaultRegistry=$DOCKER_REGISTRY_HOST_PORT \
        --set privateCA=true \
        --set useBundledSystemChart=true \
        --set certmanager.version=$CERT_MANAGER_VERSION 
}
#-------------------------
install_rancher() {
    echo -e "Installing Rancher..."    
    kubectl apply -f ./build/rancher/templates/
}
#----------------------------------------------------------------------------------------------------------------------
menu_function
step_0 # Downloads
step_1 # Configuring Docker Container for Private Registry
step_2 # K3s Private Registry Self-Signed Certificate Infrastructure
step_3 # Starting K3s and Local Docker Container Private Registry
step_4 # Collecting, Saving and Loading Private Registry
step_5 # Installing Rancher WIth Private Registries
clear
#----------------------------------------------------------------------------------------------------------------------
# Final - Port-forward and debug
echo -e "....Waiting for deployment to finish"
kubectl -n cattle-system rollout status deploy/rancher 

echo -e "....Port-forwarding...https://${HOSTNAME}:8443 should be available"
kubectl -n cattle-system port-forward svc/rancher 8443:443

