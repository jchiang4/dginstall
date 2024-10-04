# ./deletenet.sh x25 x25g no

# Note: noticed that this script does not successfully delete preexisting vnet - not a significant issue for now.


if [ $# == 0 ]; then
    # Ask user to enter values for script.
    echo ' '
    echo "Enter the name of the Azure cluster:"
    read clustername
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
else
    clustername="$1"
    resourcegroup="$2"
fi


# App gateway constants
ipname="ip"
subnetname="vnet"
subnetname2="vnet2"
gatewayname="gw"
vnetpeering="vnetpeering"
clustersubnetname="subnet"
ingressappgw="ingress-appgw"

# Getting Environment
nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")

# Delete previous ingress if necessary
echo ' '
echo '---> Delete previous ingress (if any)'
az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup

# Delete previous vnet peering if necessary
echo ' '
echo '---> Delete previous virtual network (if any)'
az network vnet peering delete -n $vnetpeering -g $resourcegroup --vnet-name $subnetname
az network vnet peering delete -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName

echo ' '
echo '---> Delete previous application gateway (if any)'
az network application-gateway delete -n $gatewayname -g $resourcegroup
