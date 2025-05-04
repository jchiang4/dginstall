# install2getIP.sh x25g no

if [ $# == 0 ]; then
    # Ask user to enter values for script.
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
else
    resourcegroup="$1"
fi

# App gateway constants
ipname="ip"

echo ' '
echo '---> Delete previous IP (if any)'
az network public-ip delete -n $ipname -g $resourcegroup

echo ' '
echo '---> Configuring Network - Creating IP Address'
sleep 2
az network public-ip create -n $ipname -g $resourcegroup --allocation-method Static --sku Standard
