#!/bin/sh

# Ask user to enter values for script.
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

# Location of the Docgility production images
# MODIFY if needed, depending on where the images are stored.
# ALSO NEED TO MODIFY PULLING LOCATION FROM HELM SCRIPT
azureimagesloc='mleimages'
azuredockerserver='https://mleimages.azurecr.io/'

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
backendport='docg_be_port'
backendaiport='docg_beai_port'
helmscriptfile="docbe-3.1.0.tgz"

# Starting Installation Script
echo ' '
echo '---> Starting Installation Script for Docgility 3.1 for Microsoft Azure'

# Connect to Cluster 
echo ' '
echo '---> Connect to Cluster - Initialization'
az aks get-credentials --resource-group $resourcegroup --name $clustername
sleep 2

# Delete previous application gateway (if any)
az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup > 0011.txt 2> 0001.txt

# Check current cluster status
echo '---> Checking Current Cluster Status - list of pods currently running ...'
kubectl get pods
sleep 2

# Enables the cluster to be able to pull from $azureimagesloc
echo ' '
echo '---> Allowing Cluster to Access Docgility Containerized Images...'
sleep 2
az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc > 00021.txt 2> 00022.txt


# Create regcred for pulling docker images
echo ' '
echo '---> Creating Credentials for Cluster to Pull Images ...'
sleep 2
kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword  > 00031.txt 2> 00032.txt


# Create storage classes used for persistent data storage.
# MODIFY BELOW IF NEEDED FOR CLIENT PRODUCTION ENVIRONMENT
echo ' '
echo '---> Adding Storage Configuration to Cluster ...'
sleep 2
kubectl apply -f storageclass.yml > 00041.txt
kubectl apply -f storageclassfs.yml > 00042.txt


# add azure networking through the application gateway
# create an network ip
echo ' '
echo '---> Configuring Network - IP Address'
sleep 2
az network public-ip create -n $ipname -g $resourcegroup --allocation-method Static --sku Standard > 00051.txt 2> 00052.txt
# store the created ip address
createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)
urladdressname="http://${createdIP}"
echo "Configuring application for: $urladdressname - can convert to a URL later."

# deploy the helm script (convert to helm zip file later)
echo ' '
echo '---> Starting Docgility Software Installation - this will take approximately 10 minutes'
sleep 2

# modify helm script execution to add the variables from the RC installation.

helm install -f config.yml deploy $helmscriptfile --set global.urladdressname=$urladdressname > 0006.txt

# check on progress
echo ' '
echo '---> Check that Docgility Software is Deployed on Cluster'
sleep 10
kubectl get pods

sleep 600
# check that it's running.
echo ' '
echo '---> Docgility is Successfully Running on Cluster'
kubectl get pods

# create a net
echo ' '
echo '---> Configuring Network - Creating Subnet'
az network vnet create -n $subnetname -g $resourcegroup --address-prefix 10.0.0.0/16 --subnet-name $clustersubnetname --subnet-prefix 10.0.0.0/24 > 0007.txt

# create an application gateway
echo ' '
echo '---> Configuring Network - Creating Application Gateway'
# az network application-gateway create -n $gatewayname -l westus3 -g $resourcegroup --sku Standard_v2 --public-ip-address docgtest1_ip --vnet-name $subnetname --subnet $clustersubnetname --priority 10 > 0008.txt
# deleted the location, hopefully it defaults to the resource group
az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10 > 0009.txt


appgwId=$(az network application-gateway show -n $gatewayname -g $resourcegroup -o tsv --query "id")

# enable gateway on the cluster
echo ' '
echo '---> Configuring Network - Enabling Application Gateway'
az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId > 00101.txt 2>00102.txt


nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")
# set up bidirectional peering
echo ' '
echo '---> Configuring Network - Creating Network Peering'
az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access > 0011.txt

appGWVnetId=$(az network vnet show -n $subnetname -g $resourcegroup -o tsv --query "id")
# set up the other way
echo ' '
echo '---> Configuring Network - Activating Network Peering'
az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access > 0012.txt

# add frontend ports
echo ' '
echo '---> Configuring Network - Creating Server Processing Ports'
# az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port 8000 --no-wait 0
# az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port 8001



az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port 8000 > 00131.txt
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port 8001 > 00132.txt
# extra wait time 
sleep 20

# add listener's for backend ports
echo ' '
echo '---> Configuring Network - Creating Application Listeners for Server Processing'
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendport -n be-listener > 00141.txt
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendaiport -n beai-listener > 00142.txt
# extra wait time 
sleep 20
# create new rules to route the backend traffic - try to see if this works.
echo ' '
echo '---> Configuring Network - Creating Application Rules for Server Processing'
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener be-listener --rule-type Basic --address-pool pool-default-docbe-8000-bp-8000 --http-settings bp-default-docbe-8000-8000-docbe --priority 2000 > 00151.txt
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener beai-listener --rule-type Basic --address-pool pool-default-docbeai-8001-bp-8000 --http-settings bp-default-docbeai-8001-8000-docbeai --priority 2010 > 00152.txt

echo ' '
echo 'Completed Network Configuration to Allow Access to Application'
sleep 2

echo ' '
echo "Docgility successfully deployed - access ${urladdressname} for application."
sleep 2
