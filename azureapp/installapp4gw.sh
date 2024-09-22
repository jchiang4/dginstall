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

# App gateway constants
ipname="ip"
subnetname="vnet"
subnetname2="vnet2"
gatewayname="gw"
vnetpeering="vnetpeering"
clustersubnetname="subnet"
ingressappgw="ingress-appgw"


backendrule="berule"
backendairule="beairule"
backenduxrule="uxrule"
backendport='beport'
backendaiport='beaiport'
backendlistener='belistener'
backendailistener='beailistener'
backenduxlistener='uxlistener'
frontendportname="frontendport"
behttpsettingsname="be_httpsettings"
beaihttpsettingsname="beai_httpsettings"
uxhttpsettingsname="uxhttpsettings"
beaddresspoolname="beaddresspool"
beaiaddresspoolname="beaiaddresspool"
uxaddresspoolname="uxaddresspool"
bebackendport=8000
befrontendport=8000
beaibackendport=8000
beaifrontendport=8001
uxbackendport=80
backendprobe="beprobe"
backendaiprobe="beaiprobe"
backenduxprobe="uxprobe"
settings='settings'

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

echo ' '
echo '---> Configuring Network - Creating Application Gateway Settings'
az network application-gateway http-settings create --gateway-name $gatewayname -n settings -g $resourcegroup --port 80 --timeout 120
                                           
appgwId=$(az network application-gateway show -n $gatewayname -g $resourcegroup -o tsv --query "id")

echo ' '
echo '---> Configuring Network - Enabing Application Gateway add-on'
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

echo ' '
echo '---> Configuring Network - Creating Server Processing Ports'
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port $befrontendport
sleep 5
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port $beaifrontendport
sleep 5

echo ' '
echo '---> Configuring Network - Modify auto-created Port to listen to another port.'
az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010
sleep 5

echo ' '
echo '---> Configuring Network - Creating Server Processing Ports'
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $frontendportname --port 80
sleep 5

echo ' '
echo '---> Configuring Network - Creating HTTP Settings'
az network application-gateway http-settings create --gateway-name $gatewayname --name $behttpsettingsname --port $bebackendport -g $resourcegroup
sleep 5
az network application-gateway http-settings create --gateway-name $gatewayname --name $beaihttpsettingsname --port $beaibackendport -g $resourcegroup
sleep 5
az network application-gateway http-settings create --gateway-name $gatewayname --name $uxhttpsettingsname --port $uxbackendport -g $resourcegroup
sleep 5

echo ' '
echo '---> Configuring Network - Creating Application Listeners for Server Processing'
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendport -n $backendlistener
sleep 5
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendaiport -n $backendailistener
sleep 5
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backenduxlistener
sleep 5


# Getting environment
bepodname=$(kubectl get pod -o jsonpath="{.items[0].metadata.name}")
bepodhostip=$(kubectl get pod $bepodname --template={{.status.podIP}})

beaipodname=$(kubectl get pod -o jsonpath="{.items[1].metadata.name}")
beaipodhostip=$(kubectl get pod $beaipodname --template={{.status.podIP}})

uxpodname=$(kubectl get pod -o jsonpath="{.items[2].metadata.name}")
uxpodhostip=$(kubectl get pod $uxpodname --template={{.status.podIP}})


echo ' '
echo '---> Configuring Network - Creating Address Pools for Backend IP'
az network application-gateway address-pool create --gateway-name $gatewayname --name $beaddresspoolname -g $resourcegroup --servers $bepodhostip
sleep 5
az network application-gateway address-pool create --gateway-name $gatewayname --name $beaiaddresspoolname -g $resourcegroup --servers $beaipodhostip
sleep 5
az network application-gateway address-pool create --gateway-name $gatewayname --name $uxaddresspoolname -g $resourcegroup --servers $uxpodhostip
sleep 5

echo ' '
echo '---> Configuring Network - Creating Application Rules for Server Processing'
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $beaddresspoolname --http-settings $behttpsettingsname --priority 2000
sleep 5
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool $beaiaddresspoolname --http-settings $beaihttpsettingsname --priority 2010
sleep 5
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backenduxrule --http-listener $backenduxlistener --rule-type Basic --address-pool $uxaddresspoolname --http-settings $uxhttpsettingsname --priority 1000
sleep 5

echo ' '
echo '---> Configuring Network - Creating Backend Probes for Server Health'
az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backendprobe --port $befrontendport --host 127.0.0.1 --path / 
sleep 5
az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backendaiprobe --port $beaifrontendport --host 127.0.0.1 --path / 
sleep 5
az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backenduxprobe --host 127.0.0.1 --path / 

echo ' '
echo 'Completed Network Configuration to Allow Access to Application'
sleep 2


