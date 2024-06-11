
# ./install3installhelm.sh x25 x25g configD.yml mleimages +q1Ly07TDh4LwE0aW0BwK2OGJ7bhbtpN no

if [ $# == 0 ]; then
    # Ask user to enter values for script.
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
    echo ' '
    echo "Output log files to disk for troubleshooting (yes or no):"
    read outputtofile
else
    clustername="$1"
    resourcegroup="$2"
    configfile="$3"
    dockerusername="$4"
    dockerpassword="$5"
    outputtofile="$6"
fi

# Location of the Docgility production images
azureimagesloc='mleimages'
azuredockerserver='https://mleimages.azurecr.io/'

# Local helm script
helmscriptfile="docbe-3.3.0.tgz"

# store the created ip address
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

# if [ $outputtofile == 'yes' ]; then
#     helm uninstall deploy > 00019.txt
#     kubectl delete pvc data-mysql-0 > 000191.txt
    
# else
helm uninstall deploy
kubectl delete pvc data-mysql-0
# fi 

# adding storage configuration (if necessary)
echo ' '
echo '---> Adding Storage Configuration to Cluster ...'
sleep 2
# if [ $outputtofile == 'yes' ]; then
#     kubectl apply -f storageclass.yml > 00041.txt
#     kubectl apply -f storageclassfs.yml > 00042.txt
# else
kubectl apply -f storageclass.yml
kubectl apply -f storageclassfs.yml
# fi

# deploy the helm script (convert to helm zip file later)
echo ' '
echo '---> Starting Docgility Software Installation - this will take approximately 10 minutes'
sleep 2



# modify helm script execution to add the variables from the RC installation.
# if [ $outputtofile == 'yes' ]; then
#     helm install -f $configfile deploy $helmscriptfile --set global.appurl=$appurl --set global.beurl=$beurl --set global.beaiurl=$beaiurl > 00061.txt
# else
helm install -f $configfile deploy $helmscriptfile --set global.appurl=$appurl --set global.beurl=$beurl --set global.beaiurl=$beaiurl
# fi
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

# Check current cluster status
echo ' '
echo '---> Checking Current Cluster Status - list of pods currently running ...'
kubectl get pods
sleep 2

# Enables the cluster to be able to pull from $azureimagesloc
echo ' '
echo '---> Allowing Cluster to Access Docgility Containerized Images...'
sleep 2
# if [ $outputtofile == 'yes' ]; then
#     az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc > 00021.txt 2> 00022.txt
# else
az aks update -n $clustername -g $resourcegroup --attach-acr $azureimagesloc
# fi

# Create regcred for pulling docker images
echo ' '
echo '---> Creating Credentials for Cluster to Pull Images ...'

# if [ $outputtofile == 'yes' ]; then
#     kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword  > 00031.txt 2> 00032.txt
# else
kubectl create secret docker-registry regcred --docker-server=$azuredockerserver --docker-username=$dockerusername --docker-password=$dockerpassword
# fi

sleep 2

