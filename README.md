# Purpose

This repository contains a Bicep template to setup:
- 1 Azure Function
- A secondary instance

And a simple Azure Function (.NET) project with an Http Trigger.

# Deploy the infrastructure

```powershell
az login

$subscription = "Training Subscription"
az account set --subscription $subscription

$rgName = "frbar-cflb"
$envName = "sagefrlb"
$location = "West Europe"

az group create --name $rgName --location $location

# Deploy 1 instance
az deployment group create --resource-group $rgName --template-file infra.bicep --mode complete --parameters envName=$envName

# Deploy 2 instances
$secondaryLocation = "North Europe"
az deployment group create --resource-group $rgName --template-file infra.bicep --mode complete --parameters envName=$envName secondaryLocation=$secondaryLocation deploySecondaryInstance=true

$env:functionAppName = az deployment group show -g $rgName -n infra --query properties.outputs.functionAppName.value -otsv
```

# Function App
```powershell
remove-item publish -recurse -force
dotnet publish src\ -r win-x64 -c Release --self-contained -o publish
Compress-Archive publish\* publish.zip -Force
az functionapp deployment source config-zip --src .\publish.zip -n "$($env:functionAppName)-0" -g $rgName

az functionapp deployment source config-zip --src .\publish.zip -n "$($env:functionAppName)-1" -g $rgName
```

# Tear down

```powershell
az group delete --name $rgName
```