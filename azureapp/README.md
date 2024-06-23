# Installation Script for Docgility on Azure Kubernetes

This README file is intended to describe Docgility and the process for installing Docgility into a client Azure private cloud environment.  This script is intended to quickly install Docgility as well as for the cloud engineer to use as a basis for deploying in the client environment.

## Description of Docgility Components

There are 3 main types of components in Docgility

## Data Services

Data Services - The storage and maintenance of data is critical for maintainting the state of the application.  Data Services are used by the backend application services to store data related to users, documents, and file storage.  Data Services include MySQL, MongoDB, and Minio (interface for file storage).  For each of the data services, the script deploys open source images for the data services components as a default, but if the organization uses managed services for these data services, Docgility can be modified to access and use the client's managed services instead.

IMPORTANT: When Docgiliy is deployed in the production, the cloud engineer should ensure that data services are backed up periodically as part of routine application maintenance.

MySQL - MySQL is used for the registration and authentication of users.  Clients using SSO/SAML Single Sign-on do not use MySQL services, but the application still requires access to MySQL.

MongoDB - MongoDB is used to the storing of document related data, including comments, document edits, risk labels, metadata, document history, collaboration activities, user logs, etc.

Minio - Minio provides an interface to file storage systems in Azure and other common Cloud Storage systems.  Minio is used to store raw contract files, signed contract files, and other raw document files.

## Backend Application Services

Backend Application Services are dependent on Data Services for maintaining the application state.  Backend application services MUST be exposed to the user's application environment.

BE - Backend component that enables online application services for the front end application.  This component provides access to collaboration services, access to document metadata, transaction services, etc.

BEAI - Backend artificial intelligence component that enables submitted new documents to be processed using artificial intelligence methods to classify contract text, OCR processing of PDF documents, machine translation services, etc.  This component requires larger memory footprint (at least 16GB, 32GB preferred) due to the nature and size of AI components.

## Frontend Services

Frontend Services provides the serving of user interface and application.  Frontend services MUST be exposed to user's application environment and must reference the backend application services.

The frontend is facilitated by a SPA "single page application" framework and provides for rich application interace.

## Known Issues

1 - MySQL vs. BE/BEAI initial installation racing condition - When the application script is first run, there may be a racing condition in which MySQL takes much longer to initialize and the BE and BEAI components start but are not able to connect to MySQL.  Checking the logs of BE will confirm if this condition is present.  Remedy - Restart the BE and BEAI components after MySQL is available.  Only applicable for the initial install.

2 - Redeployment requires removing the MySQL pvc component - When making changes, it's often common to install and uninstall as you make changes.  When MySQL is installed, a pvc is created that is persistent.  When a helm install is performed, it will try to regenerate a new random MySQL admin password and connect to the MySQL instance.  With a MySQL pvc already present, the MySQL redeployment will fail and backend services will not be able to access MySQL.  Remedy - Delete the pvc for MySQL before reinstalling the helm chart.

## Suggest Changes to Default Deployment (Depends on your client environment)

This is a demo script.  It is expected that the user may want to modify this script according to the specific client environment.

This is presented to demonstrate how to quickly bring all the components for Docgility to run in a very quick time.  Some of the considerations - 

1 - Changing Images to Local Container Store.  - You may want to pull the Docgility images into your local container store to stage them in order to install the software without further access to external resources.  
  --> Pull the images and store in your environment.  tar -xvf docbe-3.1.0.tgz to extract the helm chart and change the locations of the container images.  You should be careful to maintain the image version numbers to be the same in your environment.

2 - HTTPS and TLS certificates - To enable HTTPS in your environment, you may want to generate TLS certificates to secure the communications between web browser and application services.
  --> Generate TLS keys and add them to the helm chart to secure the communications.

3 - Application Gateway Changes - In this script, the backend application services are exposed via a port through the application gateway.  The user may change how the application gateway exposes these endpoints.
  --> Change your application gateway to use the new endpoints.  Then, change the variables passed to the UX service to reference the application services. These settings are available as VUE_APP_BACKENDSERVERENV and VUE_APP_AIBACKENDSERVERENV in the docux/templates/_helpers.tpl file.

    Note: All three services, including the UX, need to be exposed in the client environment for the proper execution of the environment. 
    Note: Client should not use path-based routing, since the path exposed to the backend service calls.  If path-based routing is used, the routing would need to strip the path to enable the original API call to backend services.

4 - Managed Services (within client environment) - Currently, data services are provided by MySQL, MongoDB, and Minio (for interfaces to file storage services).  If these services are available within the organization, you may want to change the helm script to reference these managed services.
  --> MySQL - In the helm chart, change the connection settings (including password) in docbe.mysql.env in templates/_helpers.tpl file.  Also, disable the creation of the minio image in values file under the mysql section.
  --> MongoDB - In the helm chart, change the connection settings (including password) in docbe.mongodb.env in templates/_helpers.tpl file.  Also, disable the creation of the minio image in values file under the mongodb section.
  --> Minio - In the helm chart, change the connection settings (including password) in docbe.minio.env in templates/_helpers.tpl file.  Also, disable the creation of the minio image in values file under the minio section.

5 - Using config.yml file to store your settings - The config.yml file is a template file that can be used to override the values settings in the helm chart.  It is provided for the 
Use the config.yml file to store the organization secrets.  You can modify the config.yml file to override the default settings in the configuration.  You can then change the runinstall script to use the config.yml file.  Settings include settings for SSO/SAML (for single signon in the application), SMTP (for sending emails from the application).

6 - certs in helm script with secret to address very issue.

## Configurations Needed

In the configuration file, the user may choose to turn on the different settings to enable single sign-on and outbound email generation.  These settings below can be included in the config.yml file to enable the service. 

1 - SAML/SSO - Single Sign-on Services enable the application to trust authentication services to verify the identity of the user and automatically log in the user.  If the user is not logged in, SSO will automatically redirect the user to the client environment's login page.  The following values are required:

    SAML_IDP_ENTITYID, SAML_IDP_SINGLESIGNONSERVICE_URL, SAML_SP_X509CERT

2 - SMTP - SMTP is used to generate outbound emails for user registration (if client is not using SAML/SSO) for user authentication of email identity and for product alerts.

    NOTIFICATIONORIGEMAIL, NOTIFICATIONORIGFROMEMAIL, NOTIFICATIONORIGPW, EMAILSMTPHOST, EMAILSMTPPORT

## Instructions for Product Deployment

The following values are required for the script execution:

Azure Kubernetes Cluster Name
Azure Kubernetes Resource Group 
Docker User Name (provided by Docgility)
Docker Password (provided by Docgility)

1 - Create an Azure Kubernetes Cluster.  For node pools, select VMs with at least 16GB Memory (32 GB is preferred).  Note the cluster name and resource group to enter into the script.

2 - Run ./installapp.sh and enter the information above.

3 - As the script executes, it should do the following:
    Connect to the Cluster
    Connect Cluster to Docgility Image Repository
    Create credentials to access Image Repository
    Define storage classes in cluster.
    Create IP address
    Install helm script with container images
    Wait until script completes and containers are up and running.
    Configure network environment
    Configure Application Gateway

4 - If the install fails, you can try delete the install by running ./installapp.sh again.  This script will attempt to delete the previously allocated resources and reinstall the environment from scratch.  If there's any issues with deleting previous resources, the script will give errors.  You should then try to start a new kubernetes cluster and try again with this script.  Also, in some instances, running the script sequentially causes azure cli errors, especially with the configuration of the Azure application gateway.  You may also want to try running each command separately and waiting for azure to return when the resource is available.

