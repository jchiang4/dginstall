# install2getIP.sh x25g no

if [ $# == 0 ]; then
    # Ask user to enter values for script.
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
    echo ' '
    echo "Output log files to disk for troubleshooting (yes or no):"
    read outputtofile
else
    resourcegroup="$1"
    outputtofile="$2"
fi

# App gateway constants
ipname="ip"

echo ' '
echo '---> Delete previous IP (if any)'
if [ $outputtofile == 'yes' ]; then
    az network public-ip delete -n $ipname -g $resourcegroup > 00017.txt 2> 00018.txt
else
    az network public-ip delete -n $ipname -g $resourcegroup
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