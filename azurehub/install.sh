#!/bin/sh

# Installation script for dochub
# example
# ./installgw.sh hubdemo hubdemo_group mleimages +q1Ly07TDh4LwE0aW0BwK2OGJ7bhbtpN yes no

# Verified works - May 22nd.

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
azureimagesloc='mleimages'
azuredockerserver='https://mleimages.azurecr.io/'

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

helmscriptfile="dochub-3.3.0.tgz"

frontendport=80
frontendportname="${clustername}_frontendport"
backendport=8000
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
if [ $outputtofile == 'yes' ]; then
    az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup  > 00011.txt 2> 00012.txt
else
    az aks disable-addons -a $ingressappgw -n $clustername -g $resourcegroup
fi

echo ' '
echo '---> Delete previous virtual network (if any)'
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

echo ' '
echo '---> Delete previous IP (if any)'
if [ $outputtofile == 'yes' ]; then
    az network public-ip delete -n $ipname -g $resourcegroup > 00017.txt 2> 00018.txt
else
    az network public-ip delete -n $ipname -g $resourcegroup
fi 

echo ' '
echo '---> Delete previous cluster install (if any)'
if [ $outputtofile == 'yes' ]; then
    helm uninstall deploy > 00019.txt
else
    helm uninstall deploy
fi 


# Check current cluster status
echo ' '
echo '---> Checking Current Cluster Status - list of pods currently running ...'
kubectl get pods
sleep 2

# Enables the cluster to be able to pull from $azureimagesloc
echo ' '
echo '---> Allowing Cluster to Access Docgility Containerized Images...'
sleep 2
if [ $outputtofile == 'yes' ]; then
    az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc > 00021.txt 2> 00022.txt
else
    az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc
fi

# Create regcred for pulling docker images
echo ' '
echo '---> Creating Credentials for Cluster to Pull Images ...'

if [ $outputtofile == 'yes' ]; then
    kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword  > 00031.txt 2> 00032.txt
else
    kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword
fi

sleep 2
# Create storage classes used for persistent data storage.
# MODIFY BELOW IF NEEDED FOR CLIENT PRODUCTION ENVIRONMENT
echo ' '
echo '---> Adding Storage Configuration to Cluster ...'
sleep 2
if [ $outputtofile == 'yes' ]; then
    kubectl apply -f storageclass.yml > 00041.txt
else
    kubectl apply -f storageclass.yml
fi

# add azure networking through the application gateway
# create an network ip
echo ' '
echo '---> Configuring Network - IP Address'
sleep 2
if [ $outputtofile == 'yes' ]; then
    az network public-ip create -n $ipname -g $resourcegroup --allocation-method Static --sku Standard > 00051.txt 2> 00052.txt
else
    az network public-ip create -n $ipname -g $resourcegroup --allocation-method Static --sku Standard
fi
# store the created ip address
createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)

# set the expected urls to pass to helm chart based on IP.  Should change to logical path.
# in script, using IP + ports
# huburl="http://${createdIP}:8000"

echo "Configuring application for: $huburl - can convert to a URL later."

# deploy the helm script (convert to helm zip file later)
echo ' '
echo '---> Starting Docgility Software Installation - this will take approximately 10 minutes'
sleep 2

# modify helm script execution to add the variables from the RC installation.
if [ $outputtofile == 'yes' ]; then
    helm install -f config.yml deploy $helmscriptfile  > 00061.txt
else
    helm install -f config.yml deploy $helmscriptfile 
fi
# check on progress
echo ' '
echo '---> Check that Docgility Software is Deployed on Cluster'
sleep 10
kubectl get pods


sleep 100
echo ' '
echo '---> Docgility is Successfully Running on Cluster'
kubectl get pods



if [ $autocreateappgateway == 'yes' ]; then
    echo '---> Docgility starting to configure network and application gateway'
 
    # create a net
    echo ' '
    echo '---> Configuring Network - Creating Subnet'
    if [ $outputtofile == 'yes' ]; then
        az network vnet create -n $subnetname -g $resourcegroup --address-prefix 10.0.0.0/16 --subnet-name $clustersubnetname --subnet-prefix 10.0.0.0/24 > 00071.txt
    else
        az network vnet create -n $subnetname -g $resourcegroup --address-prefix 10.0.0.0/16 --subnet-name $clustersubnetname --subnet-prefix 10.0.0.0/24
    fi

    sleep 5

    # create an application gateway
    echo ' '
    echo '---> Configuring Network - Creating Application Gateway'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10 > 00091.txt
    else
        az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10
    fi

    sleep 5

    settings='settings'
    # add settings - try this.
    az network application-gateway settings create --gateway-name $gatewayname -n settings -g $resourcegroup --port 80 --timeout 120
                  

    # Getting environment
    appgwId=$(az network application-gateway show -n $gatewayname -g $resourcegroup -o tsv --query "id")

    # enable gateway on the cluster
    echo ' '
    echo '---> Configuring Network - Enabling Application Gateway'
    if [ $outputtofile == 'yes' ]; then
        az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId > 00101.txt 2>00102.txt
    else
        az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId
    fi

    sleep 5

    # Getting environment
    nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
    aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
    aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")

    echo ' '
    echo '---> Configuring Network - Creating Network Peering'
    if [ $outputtofile == 'yes' ]; then
        az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access > 00111.txt
    else
        az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access
    fi

    sleep 5

    # Getting environment
    appGWVnetId=$(az network vnet show -n $subnetname -g $resourcegroup -o tsv --query "id")

    echo ' '
    echo '---> Configuring Network - Activating Network Peering'
    if [ $outputtofile == 'yes' ]; then
        az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access > 00121.txt
    else
        az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access
    fi

    sleep 5

    # change the existing/auto created port from azure gateway that points to 80 to point to another port 8010
    # az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010

    echo ' '
    echo '---> Configuring Network - Modify auto-created Port to listen to another port.'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010 > 0013A1.txt
    else
        az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010
    fi
    
    sleep 5

    # create frontend port for 80
    echo ' '
    echo '---> Configuring Network - Creating Server Processing Ports'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $frontendportname --port 80 > 00131.txt
    else
        az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $frontendportname --port 80
    fi
    
    sleep 5

    # Create http settings   
    if [ $outputtofile == 'yes' ]; then   
        az network application-gateway http-settings create --gateway-name $gatewayname --name $httpsettingsname --port $backendport -g $resourcegroup > 0015A2.txt
    else
        az network application-gateway http-settings create --gateway-name $gatewayname --name $httpsettingsname --port $backendport -g $resourcegroup
    fi

    sleep 5

    # Changed the front-end port to 80 to listen at root.
    # add listener's for backend ports
    echo ' '
    echo '---> Configuring Network - Creating Application Listeners for Server Processing'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backendlistener > 00141.txt
    else
        az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backendlistener
    fi
    
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
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway address-pool create --gateway-name $gatewayname --name $addresspoolname -g $resourcegroup --servers $podhostip > 0015A1.txt
    else
        az network application-gateway address-pool create --gateway-name $gatewayname --name $addresspoolname -g $resourcegroup --servers $podhostip
    fi

    sleep 5

    echo ' '
    echo '---> Configuring Network - Creating Application Rules for Server Processing'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $addresspoolname --http-settings $httpsettingsname --priority 2000 > 00151.txt
    else
        az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $addresspoolname --http-settings $httpsettingsname --priority 2000
    fi

    sleep 5

    echo ' '
    echo 'Completed Network Configuration to Allow Access to Application'
    sleep 2

    appurl="http://${createdIP}"

    echo ' '
    echo "Docgility successfully deployed - access ${appurl} for application."
    sleep 2

fi
