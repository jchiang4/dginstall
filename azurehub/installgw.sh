#!/bin/sh

# Installation script for dochub

# Verified works - May 22nd.

# example
# ./installgw.sh hubdemo hubdemo_group docgimages +q1Ly07TDh4LwE0aW0BwK2OGJ7bhbtpN yes no


# Ask user to enter values for script.
if [ $# == 0 ]; then
    echo ' '
    echo "Enter the name of the Azure cluster:"
    read clustername
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
    echo ' '
    echo "Enter the docker username for image access:"
    read dockerusername
    echo ' '
    echo "Enter the docker password for image access:"
    read dockerpassword
    echo ' '
    echo "Automatically configure network and create application gateway (yes or no):"
    read autocreateappgateway
    echo ' '
    echo "Output log files to disk for troubleshooting (yes or no):"
    read outputtofile
else
    clustername="$1"
    resourcegroup="$2"  
    dockerusername="$3"
    dockerpassword="$4"
    autocreateappgateway="$5"
    outputtofile="$6"
fi

# Location of the Docgility production images
# MODIFY if needed, depending on where the images are stored.
# ALSO NEED TO MODIFY PULLING LOCATION FROM HELM SCRIPT
azureimagesloc='docgimages'
azuredockerserver='https://docgimages.azurecr.io/'

# Constants
ipname="${clustername}_ip"
subnetname="${clustername}_vnet"
subnetname2="${clustername}_vnet2"
gatewayname="${clustername}_gw"
vnetpeering="${clustername}_vnetpeering"
clustersubnetname="${clustername}_subnet"
addresspoolname="${clustername}_addresspool"
httpsettingsname="${clustername}_httpsettings"

ingressappgw='ingress-appgw'
backendrule='docg_hub_rule'

backendlistener='docg_hub_listener'

frontendport=80
frontendportname="${clustername}_frontendport"
backendport=8000

backendprobe='backendprobe'
# backendportname='docg_hub_port'
# backendportname="${clustername}_backendport"

# Starting Installation Script
echo ' '
echo '---> Starting Installation Script for DocgilityHUB 3.3 for Microsoft Azure'

# Connect to Cluster 
echo ' '
echo '---> Connect to Cluster - Initialization'
az aks get-credentials --resource-group $resourcegroup --name $clustername --overwrite-existing
sleep 2

# Delete previous if necessary
echo ' '
echo '---> Disable previous ingress (if any)'

az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup

echo ' '
echo '---> Delete previous virtual network (if any)'
nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")

az network vnet peering delete -n $vnetpeering -g $resourcegroup --vnet-name $subnetname
az network vnet peering delete -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName

echo ' '
echo '---> Delete previous application gateway (if any)'

az network application-gateway delete -n $gatewayname -g $resourcegroup


# store the created ip address
createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)


echo "Configuring application for: $huburl - can convert to a URL later."



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

settings='settings'
# add settings - try this.
az network application-gateway settings create --gateway-name $gatewayname -n settings -g $resourcegroup --port 80 --timeout 120
                

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

# change the existing/auto created port from azure gateway that points to 80 to point to another port 8010
# az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010

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

# Changed the front-end port to 80 to listen at root.
# add listener's for backend ports
echo ' '
echo '---> Configuring Network - Creating Application Listeners for Server Processing'

az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backendlistener

sleep 5

# create new rules to route the backend traffic
# note that below references pool-default-docbe-8000-bp-8000 but creates a new one.
#  Below references those names, but if you configure application gateway
# with other settings, you would need to change as appropriate.

# Getting environment
dochubpodname=$(kubectl get pod -o jsonpath="{.items[0].metadata.name}")
podhostip=$(kubectl get pod $dochubpodname --template={{.status.podIP}})

echo ' '
echo '---> Configuring Network - Creating Address Pools for Backend IP'

az network application-gateway address-pool create --gateway-name $gatewayname --name $addresspoolname -g $resourcegroup --servers $podhostip

sleep 5

echo ' '
echo '---> Configuring Network - Creating Application Rules for Server Processing'

az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $addresspoolname --http-settings $httpsettingsname --priority 2000

echo ' '
echo '---> Configuring Network - Creating Backend Probes for Server Health'

az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backendprobe --host 127.0.0.1 --path / 


sleep 5

echo ' '
echo 'Completed Network Configuration to Allow Access to Application'
sleep 2

appurl="http://${createdIP}"

echo ' '
echo "Docgility successfully deployed - access ${appurl} for application."
sleep 2

