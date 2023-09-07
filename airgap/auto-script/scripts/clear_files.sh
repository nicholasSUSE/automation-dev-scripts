echo "Cleansing things"
sudo echo "Sudo permissions acquired"

echo "Remove all built files..."
sudo rm -Rf build/*

echo "Check and remove /var/lib/rancher/k3s/agent/images/rm"
if [ -e /var/lib/rancher/k3s/agent/images/rm ]; then
    sudo rm /var/lib/rancher/k3s/agent/images/rm
else
    echo "Directory /var/lib/rancher/k3s/agent/images/rm not found."
fi

echo "Check and remove temp.txt"
if [ -e temp.txt ]; then
    sudo rm temp.txt
else
    echo "Directory temp.txt not found."
fi

echo "Check and remove rancher-images.txt"
if [ -e rancher-images.txt ]; then
    sudo rm rancher-images.txt
else
    echo "Directory rancher-images.txt not found."
fi

echo "Check and remove rancher-load-images.sh"
if [ -e rancher-load-images.sh ]; then
    sudo rm rancher-load-images.sh
else
    echo "Directory rancher-load-images.sh not found."
fi

echo "Check and remove rancher-save-images.sh"
if [ -e rancher-save-images.sh ]; then
    sudo rm rancher-save-images.sh
else
    echo "Directory rancher-save-images.sh not found."
fi