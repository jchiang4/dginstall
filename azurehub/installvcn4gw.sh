#!/bin/sh

# Ask user to enter values for script or pass as params.
if [ $# == 0 ]; then
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

# Location of the Docgility production images
# MODIFY if needed, depending on where the images are stored.
# ALSO NEED TO MODIFY PULLING LOCATION FROM HELM SCRIPT
azureimagesloc='docgimages'
azuredockerserver='https://docgimages.azurecr.io/'

# App gateway constants
ipname="ip"
subnetname="vnet"
subnetname2="vnet2"
gatewayname="gw"
vnetpeering="vnetpeering"
clustersubnetname="subnet"
ingressappgw="ingress-appgw"

addresspoolname="addresspool"
httpsettingsname="httpsettings"
settings='settings'
backendrule='docgvcnrule'
backendlistener='docgvcnlistener'
frontendportname="frontendport"

frontendport=80
backendport=8000


echo '---> Docgility starting to configure network and application gateway'

# create a net
echo ' '
echo '---> Configuring Network - Creating Subnet'
az network vnet create -n $subnetname -g $resourcegroup --address-prefix 10.0.0.0/16 --subnet-name $clustersubnetname --subnet-prefix 10.0.0.0/24
sleep 5

# create an application gateway
echo ' '
echo '---> Configuring Network - Creating Application Gateway'
az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10
sleep 5


# echo ' '
# echo '---> Configuring Network - Creating Application Gateway Settings' 
# az network application-gateway settings create --gateway-name $gatewayname -n settings -g $resourcegroup --port 80 --timeout 120
                
# Getting environment
appgwId=$(az network application-gateway show -n $gatewayname -g $resourcegroup -o tsv --query "id")

# enable gateway on the cluster
echo ' '
echo '---> Configuring Network - Enabling Application Gateway'
az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId
sleep 5

# Getting environment
nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")

# echo $nodeResourceGroup
# echo $aksVnetName
# echo $aksVnetId

echo ' '
echo '---> Configuring Network - Creating Network Peering'
az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access
sleep 5

# Getting environment
appGWVnetId=$(az network vnet show -n $subnetname -g $resourcegroup -o tsv --query "id")

echo ' '
echo '---> Configuring Network - Activating Network Peering'
az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access
sleep 5


echo ' '
echo '---> Configuring Network - Modify auto-created Port to listen to another port.'
az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010
sleep 5

# create frontend port for 80
echo ' '
echo '---> Configuring Network - Creating Server Processing Ports'
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $frontendportname --port 80
sleep 5

# Create http settings
echo ' '
echo '---> Configuring Network - Creating HTTP Settings'
az network application-gateway http-settings create --gateway-name $gatewayname --name $httpsettingsname --port $backendport -g $resourcegroup
sleep 5

echo ' '
echo '---> Configuring Network - Creating Application Listeners for Server Processing'
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backendlistener
sleep 5

# Getting environment
docvcnpodname=$(kubectl get pod -o jsonpath="{.items[0].metadata.name}")
podhostip=$(kubectl get pod $docvcnpodname --template={{.status.podIP}})

echo ' '
echo '---> Configuring Network - Creating Address Pools for Backend IP'
az network application-gateway address-pool create --gateway-name $gatewayname --name $addresspoolname -g $resourcegroup --servers $podhostip
sleep 5

echo ' '
echo '---> Configuring Network - Creating Application Rules for Server Processing'
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $addresspoolname --http-settings $httpsettingsname --priority 2000
sleep 5

echo ' '
echo 'Completed Network Configuration to Allow Access to Application'
sleep 2


