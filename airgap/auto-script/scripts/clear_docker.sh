echo "Cleansing things"
sudo echo "Sudo permissions acquired"

docker_cleanup() {
    # Read the image list from the file
    while IFS= read -r image; do
        # Check if image line is not empty
        if [ ! -z "$image" ]; then
            
            # Check if the image exists
            if docker inspect "$image" &>/dev/null; then

                # 1. Stop running containers using this image
                containers=$(docker ps -q -f ancestor="$image")
                if [ ! -z "$containers" ]; then
                    echo "Stopping containers using the image: $image"
                    docker stop $containers
                fi

                # 2. Remove stopped containers using this image
                containers_to_remove=$(docker ps -aq -f ancestor="$image")
                if [ ! -z "$containers_to_remove" ]; then
                    echo "Removing containers using the image: $image"
                    docker rm $containers_to_remove
                fi

                # 3. Remove the image
                # echo "Removing image: $image"
                # docker rmi "$image"
            
            else
                echo "Image $image not found."
            fi
        fi
    done < rancher-images.txt

    # 4. Remove dangling volumes
    echo "Removing dangling volumes..."
    docker volume prune -f
}

docker_cleanup