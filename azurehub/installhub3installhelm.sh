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
    echo "Enter the docker username for image access:"
    read dockerusername
    echo ' '
    echo "Enter the docker password for image access:"
    read dockerpassword
else
    clustername="$1"
    resourcegroup="$2"
    dockerusername="$3"
    dockerpassword="$4"
fi

# Location of the Docgility production images
# MODIFY if needed, depending on where the images are stored.
# ALSO NEED TO MODIFY PULLING LOCATION FROM HELM SCRIPT
azureimagesloc='docgimages'
azuredockerserver='https://docgimages.azurecr.io/'

# Local helm script
helmscriptfile="dochub-3.3.0.tgz"

# store the created ip address
# createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)

echo "Configuring application for: $appurl"

# Delete previous if any
echo ' '
echo '---> Delete previous cluster install (if any)'
helm uninstall deploy

# Create regcred for pulling docker images
echo ' '
echo '---> Creating Credentials for Cluster to Pull Images ...'
kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword

echo ' '
echo '---> Adding Storage Configuration to Cluster ...'
kubectl apply -f storageclass.yml

# Enables the cluster to be able to pull from $azureimagesloc
echo ' '
echo '---> Allowing Cluster to Access Docgility Containerized Images...'

# added the following calls to make sure aks-preview is up to date and available.
az extension add --name aks-preview
az extension update --name aks-preview

sleep 2
# above addresses the az cli bug to enable call below.  previously was generating 
# AttributeError: 'AKSPreviewManagedClusterContext' object has no attribute 'get_uptime_sla'
az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc


echo ' '
echo '---> Starting Docgility Software Installation - this will take approximately 10 minutes'
helm install -f config.yml deploy $helmscriptfile 
sleep 2

# check on progress
echo ' '
echo '---> Check that Docgility Software is Deployed on Cluster'
sleep 10
kubectl get pods

sleep 100
echo ' '
echo '---> Docgility is Successfully Running on Cluster'
kubectl get pods


