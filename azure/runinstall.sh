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
echo ' '
echo "Automatically configure network and create application gateway (yes or no):"
read autocreateappgateway
echo ' '
echo "Output log files to disk for troubleshooting (yes or no):"
read outputtofile

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

backendlistener='docg_be_listener'
backendailistener='docg_beai_listener'

helmscriptfile="docbe-3.1.1.tgz"

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
    kubectl delete pvc data-mysql-0 > 000191.txt
    
else
    helm uninstall deploy
    kubectl delete pvc data-mysql-0
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
    kubectl apply -f storageclassfs.yml > 00042.txt
else
    kubectl apply -f storageclass.yml
    kubectl apply -f storageclassfs.yml
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
beurl="http://${createdIP}:8000"
beaiurl="http://${createdIP}:8001"
appurl="http://${createdIP}"

echo "Configuring application for: $appurl - can convert to a URL later."

# deploy the helm script (convert to helm zip file later)
echo ' '
echo '---> Starting Docgility Software Installation - this will take approximately 10 minutes'
sleep 2

# modify helm script execution to add the variables from the RC installation.
if [ $outputtofile == 'yes' ]; then
    helm install -f config.yml deploy $helmscriptfile --set global.appurl=$appurl --set global.beurl=$beurl --set global.beaiurl=$beaiurl > 00061.txt
else
    helm install -f config.yml deploy $helmscriptfile --set global.appurl=$appurl --set global.beurl=$beurl --set global.beaiurl=$beaiurl
fi
# check on progress
echo ' '
echo '---> Check that Docgility Software is Deployed on Cluster'
sleep 10
kubectl get pods

sleep 540
# restart docbe due to race conditions for slow MySQL initialization.
echo ' '
echo '---> Restarting Docbe pod in Cluster for initialization'
docbepod=$(kubectl get pod -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $docbepod
sleep 60

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
    # create an application gateway
    # echo ' '
    # echo '---> Configuring Network - Deleting Application Gateway (if previously created)'
    # az aks disable-addons -a ingress-appgw -n dgtest13 -g dgtest13g - do I need to do this to reinitialize
    # az network application-gateway delete -n $gatewayname -g $resourcegroup > 00081.txt
    # sleep 10

    # create an application gateway
    echo ' '
    echo '---> Configuring Network - Creating Application Gateway'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10 > 00091.txt
    else
        az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10
    fi

    appgwId=$(az network application-gateway show -n $gatewayname -g $resourcegroup -o tsv --query "id")

    # enable gateway on the cluster
    echo ' '
    echo '---> Configuring Network - Enabling Application Gateway'
    if [ $outputtofile == 'yes' ]; then
        az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId > 00101.txt 2>00102.txt
    else
        az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId
    fi

    nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
    aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
    aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")
    # set up bidirectional peering
    echo ' '
    echo '---> Configuring Network - Creating Network Peering'
    if [ $outputtofile == 'yes' ]; then
        az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access > 00111.txt
    else
        az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access
    fi
    appGWVnetId=$(az network vnet show -n $subnetname -g $resourcegroup -o tsv --query "id")
    # set up the other way
    echo ' '
    echo '---> Configuring Network - Activating Network Peering'
    if [ $outputtofile == 'yes' ]; then
        az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access > 00121.txt
    else
        az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access
    fi
    # NOTE: Sometimes Azure scripts do not sequentially execute correctly.  May need to execute these application gateway calls sequentially.


    # add frontend ports
    echo ' '
    echo '---> Configuring Network - Creating Server Processing Ports'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port 8000 > 00131.txt
        az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port 8001 > 00132.txt
    else
        az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port 8000
        az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port 8001
    fi
    # extra wait time 
    sleep 40

    # add listener's for backend ports
    echo ' '
    echo '---> Configuring Network - Creating Application Listeners for Server Processing'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendport -n $backendlistener > 00141.txt
        az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendaiport -n $backendailistener > 00142.txt
    else
        az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendport -n $backendlistener
        az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendaiport -n $backendailistener
    fi
    # extra wait time 
    sleep 40

    # create new rules to route the backend traffic
    # note that below references pool-default-docbe-8000-bp-8000 and pool-default-docbeai-8001-bp-8000 that should be auto-created
    # when the application gateway is created and ingress is set.  Below references those names, but if you configure application gateway
    # with other settings, you would need to change as appropriate.
    echo ' '
    echo '---> Configuring Network - Creating Application Rules for Server Processing'
    if [ $outputtofile == 'yes' ]; then
        az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool pool-default-docbe-8000-bp-8000 --http-settings bp-default-docbe-8000-8000-docbe --priority 2000 > 00151.txt
        az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool pool-default-docbeai-8001-bp-8000 --http-settings bp-default-docbeai-8001-8000-docbeai --priority 2010 > 00152.txt
    else
        az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool pool-default-docbe-8000-bp-8000 --http-settings bp-default-docbe-8000-8000-docbe --priority 2000
        az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool pool-default-docbeai-8001-bp-8000 --http-settings bp-default-docbeai-8001-8000-docbeai --priority 2010
    fi

    echo ' '
    echo 'Completed Network Configuration to Allow Access to Application'
    sleep 2

    echo ' '
    echo "Docgility successfully deployed - access ${appurl} for application."
    sleep 2

fi