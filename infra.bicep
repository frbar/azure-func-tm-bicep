targetScope = 'resourceGroup'

param envName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Secondary location')
param secondaryLocation string = location

@description('Deploy a 2nd function instance')
param deploySecondaryInstance bool = false

var storageAccountName = '${envName}func'
var locations = [ location, secondaryLocation ]
var n = deploySecondaryInstance ? 2 : 1

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${envName}-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// NOTE: Bicep modules would have been nicer.

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = [for i in range(0, n): {
  name: '${storageAccountName}${i}'
  location: locations[i]
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}]

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = [for i in range(0, n): {
  name: '${envName}-plan-${i}'
  location: locations[i]
  kind: 'windows'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    //reserved: true     // required for using linux
  }
}]

resource functionApp 'Microsoft.Web/sites@2018-11-01' = [for i in range(0, n): {
  name: '${envName}-func-${i}'
  location: locations[i]
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan[i].id
    siteConfig: {
      windowsFxVersion:'DOTNET|6.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount[i].name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount[i].listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount[i].name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount[i].listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${envName}-func-${i}'   
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}]

resource TrafficManager 'Microsoft.Network/trafficmanagerprofiles@2018-08-01' = if (deploySecondaryInstance) {
  name: '${envName}-tm'
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: envName
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
      intervalInSeconds: 10
      timeoutInSeconds: 9
      expectedStatusCodeRanges: [
        {
          min: 200
          max: 202
        }
        {
          min: 301
          max: 302
        }
      ]
    }
    endpoints: [for i in range(0, n): {
        type: 'Microsoft.Network/TrafficManagerProfiles/azureEndpoints'
        name: 'endpoint-${i}'
        properties: {
          targetResourceId: functionApp[i].id
          endpointStatus: 'Enabled'
          customHeaders:[
            {
              name: 'host'
              value: functionApp[i].properties.defaultHostName
            }
          ]
        }
      }]
  }
}

output storageAccountName string = storageAccountName
output functionAppName string = '${envName}-func'
