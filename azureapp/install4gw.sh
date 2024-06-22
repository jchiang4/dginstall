# ./install4gw.sh x23 x23g no

if [ $# == 0 ]; then
    # Ask user to enter values for script.
    echo ' '
    echo "Enter the name of the Azure cluster:"
    read clustername
    echo ' '
    echo "Enter the name of the resource group for the cluster:"
    read resourcegroup
    echo ' '
    echo "Output log files to disk for troubleshooting (yes or no):"
    read outputtofile

else
    clustername="$1"
    resourcegroup="$2"
    outputtofile="$3"
fi

# App gateway constants
ipname="ip"
subnetname="vnet"
subnetname2="vnet2"
gatewayname="gw"
vnetpeering="vnetpeering"
clustersubnetname="subnet"
ingressappgw="ingress"


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

echo '---> Docgility starting to configure network and application gateway'

# create a net
echo ' '
echo '---> Configuring Network - Creating Subnet'
# if [ $outputtofile == 'yes' ]; then
#     az network vnet create -n $subnetname -g $resourcegroup --address-prefix 10.0.0.0/16 --subnet-name $clustersubnetname --subnet-prefix 10.0.0.0/24 > 00071.txt
# else
az network vnet create -n $subnetname -g $resourcegroup --address-prefix 10.0.0.0/16 --subnet-name $clustersubnetname --subnet-prefix 10.0.0.0/24
# fi

sleep 5

# create an application gateway
# added setting to create app gateway with 120 request timeout, hopefully that fixes the 
# echo ' '
# echo '---> Configuring Network - Creating Application Gateway'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10 --timeout 120
# > 00091.txt
# else
az network application-gateway create -n $gatewayname -g $resourcegroup --sku Standard_v2 --public-ip-address $ipname --vnet-name $subnetname --subnet $clustersubnetname --priority 10
# fi

sleep 5

settings='settings'
# add settings - try this.
az network application-gateway settings create --gateway-name $gatewayname -n settings -g $resourcegroup --port 80 --timeout 120
                                           

appgwId=$(az network application-gateway show -n $gatewayname -g $resourcegroup -o tsv --query "id")

# enable gateway on the cluster
# echo ' '
# echo '---> Configuring Network - Enabling Application Gateway'
# if [ $outputtofile == 'yes' ]; then
#     az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId > 00101.txt 2>00102.txt
# else
az aks enable-addons -n $clustername -g $resourcegroup -a $ingressappgw --appgw-id $appgwId
# fi

sleep 5

# Getting environment
nodeResourceGroup=$(az aks show -n $clustername -g $resourcegroup -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list -g $nodeResourceGroup -o tsv --query "[0].name")
aksVnetId=$(az network vnet show -n $aksVnetName -g $nodeResourceGroup -o tsv --query "id")

echo ' '
echo '---> Configuring Network - Creating Network Peering'
# if [ $outputtofile == 'yes' ]; then
#     az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access > 00111.txt
# else
az network vnet peering create -n $vnetpeering -g $resourcegroup --vnet-name $subnetname --remote-vnet $aksVnetId --allow-vnet-access
# fi

sleep 5

# Getting environment
appGWVnetId=$(az network vnet show -n $subnetname -g $resourcegroup -o tsv --query "id")

echo ' '
echo '---> Configuring Network - Activating Network Peering'
# if [ $outputtofile == 'yes' ]; then
#     az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access > 00121.txt
# else
az network vnet peering create -n $subnetname2 -g $nodeResourceGroup --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access
# fi

sleep 5

echo ' '
echo '---> Configuring Network - Creating Server Processing Ports'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port 8000 > 00131.txt
#     az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port 8001 > 00132.txt
# else
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendport --port $befrontendport
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $backendaiport --port $beaifrontendport
# fi

sleep 5

# Added section to redo the frontend-port as needed

echo ' '
echo '---> Configuring Network - Modify auto-created Port to listen to another port.'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010 > 0013A1.txt
# else
az network application-gateway frontend-port update -g $resourcegroup --gateway-name $gatewayname --name appGatewayFrontendPort --port 8010
# fi

sleep 5

# create frontend port for 80
echo ' '
echo '---> Configuring Network - Creating Server Processing Ports'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $frontendportname --port 80 > 0013B1.txt
# else
az network application-gateway frontend-port create  -g $resourcegroup --gateway-name $gatewayname -n $frontendportname --port 80
# fi

sleep 5

# Create http settings   
# if [ $outputtofile == 'yes' ]; then   
#     az network application-gateway http-settings create --gateway-name $gatewayname --name $behttpsettingsname --port $bebackendport -g $resourcegroup > 0014A1.txt
#     az network application-gateway http-settings create --gateway-name $gatewayname --name $beaihttpsettingsname --port $beaibackendport -g $resourcegroup > 0014A2.txt

#     az network application-gateway http-settings create --gateway-name $gatewayname --name $uxhttpsettingsname --port $uxbackendport -g $resourcegroup > 0014A3.txt
# else
az network application-gateway http-settings create --gateway-name $gatewayname --name $behttpsettingsname --port $bebackendport -g $resourcegroup
az network application-gateway http-settings create --gateway-name $gatewayname --name $beaihttpsettingsname --port $beaibackendport -g $resourcegroup

az network application-gateway http-settings create --gateway-name $gatewayname --name $uxhttpsettingsname --port $uxbackendport -g $resourcegroup
# fi

sleep 5

# add listener's for backend ports
echo ' '
echo '---> Configuring Network - Creating Application Listeners for Server Processing'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendport -n $backendlistener > 00141.txt
#     az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendaiport -n $backendailistener > 00142.txt

#     az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backenduxlistener > 00143.txt
# else
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendport -n $backendlistener
az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $backendaiport -n $backendailistener

az network application-gateway http-listener create -g $resourcegroup --gateway-name $gatewayname --frontend-port $frontendportname -n $backenduxlistener
# fi

sleep 5

# create new rules to route the backend traffic
# note that below references pool-default-docbe-8000-bp-8000 and pool-default-docbeai-8001-bp-8000 that should be auto-created
# when the application gateway is created and ingress is set.  Below references those names, but if you configure application gateway
# with other settings, you would need to change as appropriate.

# Getting environment
bepodname=$(kubectl get pod -o jsonpath="{.items[0].metadata.name}")
bepodhostip=$(kubectl get pod $bepodname --template={{.status.podIP}})

beaipodname=$(kubectl get pod -o jsonpath="{.items[1].metadata.name}")
beaipodhostip=$(kubectl get pod $beaipodname --template={{.status.podIP}})

uxpodname=$(kubectl get pod -o jsonpath="{.items[2].metadata.name}")
uxpodhostip=$(kubectl get pod $uxpodname --template={{.status.podIP}})


echo ' '
echo '---> Configuring Network - Creating Address Pools for Backend IP'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway address-pool create --gateway-name $gatewayname --name $beaddresspoolname -g $resourcegroup --servers $bepodhostip > 0015A1.txt
#     az network application-gateway address-pool create --gateway-name $gatewayname --name $beaiaddresspoolname -g $resourcegroup --servers $beaipodhostip > 0015A2.txt

#     az network application-gateway address-pool create --gateway-name $gatewayname --name $uxaddresspoolname -g $resourcegroup --servers $uxpodhostip > 0015A3.txt
# else
az network application-gateway address-pool create --gateway-name $gatewayname --name $beaddresspoolname -g $resourcegroup --servers $bepodhostip
az network application-gateway address-pool create --gateway-name $gatewayname --name $beaiaddresspoolname -g $resourcegroup --servers $beaipodhostip

az network application-gateway address-pool create --gateway-name $gatewayname --name $uxaddresspoolname -g $resourcegroup --servers $uxpodhostip
# fi

sleep 5

# echo ' '
# echo '---> Configuring Network - Creating Application Rules for Server Processing'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool pool-default-docbe-8000-bp-8000 --http-settings bp-default-docbe-8000-8000-docbe --priority 2000 > 00151.txt
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool pool-default-docbeai-8001-bp-8000 --http-settings bp-default-docbeai-8001-8000-docbeai --priority 2010 > 00152.txt
# else
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool pool-default-docbe-8000-bp-8000 --http-settings bp-default-docbe-8000-8000-docbe --priority 2000
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool pool-default-docbeai-8001-bp-8000 --http-settings bp-default-docbeai-8001-8000-docbeai --priority 2010
# fi

echo ' '
echo '---> Configuring Network - Creating Application Rules for Server Processing'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $beaddresspoolname --http-settings $behttpsettingsname --priority 2000 > 00151.txt
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool $beaiaddresspoolname --http-settings $beaihttpsettingsname --priority 2010 > 00152.txt

#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backenduxrule --http-listener $backenduxlistener --rule-type Basic --address-pool $uxaddresspoolname --http-settings $uxhttpsettingsname --priority 1000 > 00153.txt
# else
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $beaddresspoolname --http-settings $behttpsettingsname --priority 2000
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool $beaiaddresspoolname --http-settings $beaihttpsettingsname --priority 2010
az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backenduxrule --http-listener $backenduxlistener --rule-type Basic --address-pool $uxaddresspoolname --http-settings $uxhttpsettingsname --priority 1000
# fi

echo ' '
echo '---> Configuring Network - Creating Backend Probes for Server Health'
# if [ $outputtofile == 'yes' ]; then
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendrule --http-listener $backendlistener --rule-type Basic --address-pool $beaddresspoolname --http-settings $behttpsettingsname --priority 2000 > 00151.txt
#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backendairule --http-listener $backendailistener --rule-type Basic --address-pool $beaiaddresspoolname --http-settings $beaihttpsettingsname --priority 2010 > 00152.txt

#     az network application-gateway rule create -g $resourcegroup --gateway-name $gatewayname -n $backenduxrule --http-listener $backenduxlistener --rule-type Basic --address-pool $uxaddresspoolname --http-settings $uxhttpsettingsname --priority 1000 > 00153.txt
# else

az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backendprobe --port $befrontendport --host 127.0.0.1 --path / 
az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backendaiprobe --port $beaifrontendport --host 127.0.0.1 --path / 
az network application-gateway probe create -g $resourcegroup --gateway-name $gatewayname -n $backenduxprobe --host 127.0.0.1 --path / 
# fi



echo ' '
echo 'Completed Network Configuration to Allow Access to Application'
sleep 2

createdIP=$(az network public-ip list --resource-group $resourcegroup --query [0].ipAddress --output tsv)

appurl="http://${createdIP}"


echo ' '
echo "Docgility successfully deployed - access ${appurl} for application."
sleep 2
