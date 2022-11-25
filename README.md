# Purpose

This repository contains a Bicep template to setup:
- 1 Azure Function
- Optionally a secondary instance
- A Traffic Manager (if 2 functions are deployed)

And a simple Azure Function (.NET) project with an Http Trigger.

# Deploy the infrastructure

```powershell
az login

$subscription = "Training Subscription"
az account set --subscription $subscription

$rgName = "frbar-func-rg"
$envName = "frbarpoc"
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
remove-item publish\* -recurse -force
dotnet publish src\ -r win-x64 --self-contained -c Release -o publish
Compress-Archive publish\* publish.zip -Force
$env:functionAppName = az deployment group show -g $rgName -n infra --query properties.outputs.functionAppName.value -otsv
az functionapp deployment source config-zip --src .\publish.zip -n "$($env:functionAppName)-0" -g $rgName

az functionapp deployment source config-zip --src .\publish.zip -n "$($env:functionAppName)-1" -g $rgName
```

# Tear down

```powershell
az group delete --name $rgName
```