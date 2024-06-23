# ./deletenet.sh x25 x25g no


if [ $# == 0 ]; then
    # Ask user to enter values for script.
    echo ' '
    echo "Enter the name of the Azure cluster:"
    read clustername
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
    echo ' '
    echo "Output log files to disk for troubleshooting (yes or no):"
    read outputtofile
else
    clustername="$1"
    resourcegroup="$2"
    outputtofile="$3"
fi


# App gateway constants
ipname="ip"
subnetname="vnet"
subnetname2="vnet2"
gatewayname="gw"
vnetpeering="vnetpeering"
clustersubnetname="subnet"
ingressappgw="ingress"

# Getting Environment
nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")

# Delete previous ingress if necessary
echo ' '
echo '---> Disable previous ingress (if any)'
# if [ $outputtofile == 'yes' ]; then
#     az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup > 00011.txt 2> 00012.txt
# else
az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup
# fi

# Delete previous vnet peering if necessary
echo ' '
echo '---> Delete previous virtual network (if any)'

# if [ $outputtofile == 'yes' ]; then
#     az network vnet peering delete -n $vnetpeering -g $resourcegroup --vnet-name $subnetname > 00013.txt 2> 00014.txt
#     az network vnet peering delete -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName > 000131.txt 2> 000141.txt
# else
az network vnet peering delete -n $vnetpeering -g $resourcegroup --vnet-name $subnetname
az network vnet peering delete -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName
# fi

echo ' '
echo '---> Delete previous application gateway (if any)'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway delete -n $gatewayname -g $resourcegroup > 00015.txt 2> 00016.txt
# else
az network application-gateway delete -n $gatewayname -g $resourcegroup
# fi