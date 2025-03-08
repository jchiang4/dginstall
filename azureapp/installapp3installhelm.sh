#!/bin/sh

# Ask user to enter values for script or pass as params
if [ $# == 0 ]; then
    echo ' '
    echo "Enter the name of the Azure cluster:"
    read clustername
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
    echo ' '
    echo "Enter the name of the config file for the cluster:"
    read configfile
    echo ' '
    echo "Enter the docker username for image access:"
    read dockerusername
    echo ' '
    echo "Enter the docker password for image access:"
    read dockerpassword
else
    clustername="$1"
    resourcegroup="$2"
    configfile="$3"
    dockerusername="$4"
    dockerpassword="$5"
fi

# Location of the Docgility production images
azureimagesloc='docgimages'
azuredockerserver='https://docgimages.azurecr.io/'

# Local helm script
helmscriptfile="docbe-3.3.0.tgz"

# store the created ip address
# wait 5 seconds before accessing IP address.
sleep 5
createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)

# set the expected urls to pass to helm chart based on IP.  Should change to logical path.
# in script, using IP + ports
beurl="http://${createdIP}:8000"
beaiurl="http://${createdIP}:8001"
appurl="http://${createdIP}"

echo "Configuring application for: $appurl"

# Delete previous if any
echo ' '
echo '---> Delete previous cluster install (if any)'
helm uninstall deploy
kubectl delete pvc data-mysql-0

# adding storage configuration (if necessary)
echo ' '
echo '---> Adding Storage Configuration to Cluster ...'
kubectl apply -f storageclass.yml
kubectl apply -f storageclassfs.yml
sleep 2

# deploy the helm script (convert to helm zip file later)
echo ' '
echo '---> Starting Docgility Software Installation - this will take approximately 10 minutes'
sleep 2

# Enables the cluster to be able to pull from $azureimagesloc
echo ' '
echo '---> Allowing Cluster to Access Docgility Containerized Images...'
sleep 2
az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc


# Create regcred for pulling docker images
echo ' '
echo '---> Creating Credentials for Cluster to Pull Images ...'

kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword
sleep 2

helm install -f $configfile deploy $helmscriptfile --set global.appurl=$appurl --set global.beurl=$beurl --set global.beaiurl=$beaiurl

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

# Check current cluster status
echo ' '
echo '---> Checking Current Cluster Status - list of pods currently running ...'
kubectl get pods
sleep 2




