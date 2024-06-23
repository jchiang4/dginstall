#!/bin/sh

# ./installapp.sh clustername resourcegroup configfile dockerusername dockerpassword 
# yes yes yes yes no = to install new instance from scratch
# yes no no yes no = reinstall gw, but not new IP, not reinstall nodes.


if [ $# == 0 ]; then

    # Ask user to enter values for script.
    echo ' '
    echo "Enter the name of the Azure cluster:"
    read clustername
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup

    echo ' '
    echo "Enter the name of config file used for configuration:"
    read configfile

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
    configfile="$3"
    dockerusername="$4"
    dockerpassword="$5"
    deletenetworkandgateway="$6"
    getnewip="$7"
    installhelmchart="$8"
    autocreateappgateway="$9"
    outputtofile="$10"
    
fi

echo ''
echo "STARTING INSTALLATION ON:"
echo $clustername
echo $resourcegroup
echo ''

# Starting Installation Script
echo ' '
echo '---> Starting Installation Script for Docgility 3.3 for Microsoft Azure'
sleep 2

# Connect to Cluster 
echo ' '
echo '---> Connect to Cluster - Initialization'
az aks get-credentials --resource-group $resourcegroup --name $clustername
sleep 2

if [ $deletenetworkandgateway == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installapp1deletenet.sh $clustername $resourcegroup $outputtofile > installapp1deletenet.txt
    else
        ./installapp1deletenet.sh $clustername $resourcegroup $outputtofile
    fi
fi

# get new IP
if [ $getnewip == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installapp2getIP.sh $resourcegroup $outputtofile > installapp2getIP.txt
    else
        ./installapp2getIP.sh $resourcegroup $outputtofile
    fi
fi

# install new helm charts
if [ $installhelmchart == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installapp3installhelm.sh $clustername $resourcegroup $configfile $dockerusername $dockerpassword $outputtofile > installapp3installhelm.txt
    else
        ./installapp3installhelm.sh $clustername $resourcegroup $configfile $dockerusername $dockerpassword $outputtofile
    fi
fi

# install the gateway
if [ $autocreateappgateway == 'yes' ]; then
    if [ $outputtofile == 'yes' ]; then
        ./installapp4gw.sh $clustername $resourcegroup $outputtofile > installapp4gw.txt
    else
        ./installapp4gw.sh $clustername $resourcegroup $outputtofile
    fi
fi
