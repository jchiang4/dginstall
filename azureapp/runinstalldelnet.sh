#!/bin/sh

# OLD - use install.sh instead

# Ask user to enter values for script.
echo ' '
echo "Enter the name of the Azure cluster:"
read clustername
echo ' '
echo "Enter the name of the resource group for the cluster:"
read resourcegroup

outputtofile='no'

# Location of the Docgility production images
# MODIFY if needed, depending on where the images are stored.
# ALSO NEED TO MODIFY PULLING LOCATION FROM HELM SCRIPT
azureimagesloc='mleimages'
azuredockerserver='https://mleimages.azurecr.io/'

helmscriptfile="docbe-3.3.0.tgz"

# Constants
ipname="${clustername}_ip"
subnetname="${clustername}_vnet"
subnetname2="${clustername}_vnet2"
gatewayname="${clustername}_gw"
vnetpeering="${clustername}_vnetpeering"
clustersubnetname="${clustername}_subnet"

ingressappgw='ingress-appgw'
backendrule='docg_be_rule'
backendairule='docg_beai_rule'
backenduxrule='docg_ux_rule'

backendport='docg_be_port'
backendaiport='docg_beai_port'

backendlistener='docg_be_listener'
backendailistener='docg_beai_listener'
backenduxlistener='docg_ux_listener'

frontendportname="${clustername}_frontendport"

behttpsettingsname="${clustername}_behttpsettings"
beaihttpsettingsname="${clustername}_beaihttpsettings"
uxhttpsettingsname="${clustername}_uxhttpsettings"

bebackendport=8000
beaibackendport=8000
uxbackendport=80

beaddresspoolname="${clustername}_beaddresspool"
beaiaddresspoolname="${clustername}_beaiaddresspool"
uxaddresspoolname="${clustername}_uxaddresspool"


# Starting Installation Script
echo ' '
echo '---> Starting Installation Script for Docgility 3.1 for Microsoft Azure'

# Connect to Cluster 
echo ' '
echo '---> Connect to Cluster - Initialization'
az aks get-credentials --resource-group $resourcegroup --name $clustername
sleep 2

# Delete previous if necessary
echo ' '
echo '---> Disable previous ingress (if any)'
if [ $outputtofile == 'yes' ]; then
    az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup > 00011.txt 2> 00012.txt
else
    az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup
fi

echo ' '
echo '---> Delete previous virtual network (if any)'
# copied section from below.  Should assign variables to determine the aksVnetName
nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")
if [ $outputtofile == 'yes' ]; then
    az network vnet peering delete -n $vnetpeering -g $resourcegroup --vnet-name $subnetname > 00013.txt 2> 00014.txt
    az network vnet peering delete -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName > 000131.txt 2> 000141.txt
else
    az network vnet peering delete -n $vnetpeering -g $resourcegroup --vnet-name $subnetname
    az network vnet peering delete -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName
fi

echo ' '
echo '---> Delete previous application gateway (if any)'
if [ $outputtofile == 'yes' ]; then
    az network application-gateway delete -n $gatewayname -g $resourcegroup > 00015.txt 2> 00016.txt
else
    az network application-gateway delete -n $gatewayname -g $resourcegroup
fi
