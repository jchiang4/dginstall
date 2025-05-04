#!/bin/sh

# Installation script for docvcn
# ./installvcn.sh clustername resourcegroup dockerusername dockerpassword 
# yes yes yes yes no = to install new instance from scratch
# yes no no yes no = reinstall gw, but not new IP, not reinstall nodes.

# Ask user to enter values for script or pass as params.
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
    echo "Delete previous gateway (yes or no):"
    read deletenetworkandgateway
    echo ' '
    echo "Get a new IP (yes or no):"
    read getnewip
    echo ' '
    echo "install new helm charts (yes or no):"
    read installhelmchart
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
    deletenetworkandgateway="$5"
    getnewip="$6"
    installhelmchart="$7"
    autocreateappgateway="$8"
    outputtofile="$9"
fi

echo "STARTING INSTALLATION ON:"
echo $clustername
echo $resourcegroup
echo ''

# Starting Installation Script
echo ' '
echo '---> Starting Installation Script for Docgility VCN 4.0.1 for Microsoft Azure'

# Connect to Cluster 
echo ' '
echo '---> Connect to Cluster - Initialization'
az aks get-credentials --resource-group $resourcegroup --name $clustername --overwrite-existing
sleep 2

if [ $deletenetworkandgateway == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installvcn1deletenet.sh $clustername $resourcegroup > installvcn1deletenet.txt
    else
        ./installvcn1deletenet.sh $clustername $resourcegroup
    fi
fi

# get new IP
if [ $getnewip == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installvcn2getIP.sh $resourcegroup > installvcn2getIP.txt
    else
        ./installvcn2getIP.sh $resourcegroup
    fi
fi

# install new helm charts
if [ $installhelmchart == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installvcn3installhelm.sh $clustername $resourcegroup $configfile $dockerusername $dockerpassword > installvcn3installhelm.txt
    else
        ./installvcn3installhelm.sh $clustername $resourcegroup $configfile $dockerusername $dockerpassword
    fi
fi

# install the gateway
if [ $autocreateappgateway == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installvcn4gw.sh $clustername $resourcegroup > installvcn4gw.txt
    else
        ./installvcn4gw.sh $clustername $resourcegroup
    fi
fi

createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)

appurl="http://${createdIP}"

echo ' '
echo "Docgility VCN successfully deployed - access ${appurl} for application."
sleep 2