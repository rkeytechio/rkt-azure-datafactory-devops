/*
------------------------------------------------
Parameters
------------------------------------------------
*/

@description('Required. Environment short name.')
param environmentShortName string

@description('Optional. Location of the data factory. Default: Resource group location')
param location string = resourceGroup().location

@description('Optional. Company short name. Default: rkt')
param companyShortName string = 'rkt'

@description('Optional. Project short name. Default: data')
param departmentShortName string = 'data'

/*
------------------------------------------------
Variables
------------------------------------------------
*/
var appRandomiseName = substring(uniqueString(subscription().id, resourceGroup().id, companyShortName, departmentShortName), 0, 4)
var dataLakeStorageAccountName = '${companyShortName}${departmentShortName}dls${appRandomiseName}'
var dataFactoryName = '${companyShortName}-${departmentShortName}-adf-${appRandomiseName}'

var storageContainerNames = [
  'source'
  'raw'
  'staging'
  'processed'
  'curated'
]

/*
------------------------------------------------
External References
------------------------------------------------
*/


/*
------------------------------------------------
Storage Account Azure Data Lake Gen2
------------------------------------------------
*/
resource dataLakeStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: dataLakeStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_0'
    allowBlobPublicAccess: true
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  
  // Blob Service
  resource blobService 'blobServices' = {
    name: 'default'
    properties: {}

    // Blob Containers
    resource storageContainers 'containers' = [for containerName in storageContainerNames: {
      name: containerName
    }]
  }
}

/*
------------------------------------------------
Azure Data Factory + Git Configuration
------------------------------------------------
*/
var gitHubRepoConfiguration = {
  accountName: 'rkeytechio'
  repositoryName: 'rkt-azure-datafactory-devops'
  collaborationBranch: 'main'
  rootFolder: '/src/adf'  
  type: 'FactoryGitHubConfiguration'
}


resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  properties: {
    repoConfiguration: (environmentShortName == 'dev') ? gitHubRepoConfiguration : null
  }
  identity: {
    type: 'SystemAssigned'
  }
}

/*
------------------------------------------------
Data Factory RBAC Roles
------------------------------------------------
*/
var storageBlobDataContributorRoleDefinitionId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var roleDefinitionBlobDataContributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleDefinitionId)
resource dataFactoryStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(dataLakeStorageAccount.id, dataFactory.id)
  scope: dataLakeStorageAccount
  properties: {
    roleDefinitionId: roleDefinitionBlobDataContributor
    principalId: dataFactory.identity.principalId
  }
}

/*
-----------------------------------------------------------
Outputs
-----------------------------------------------------------
*/
output dataLakeStorageAccountName string = dataLakeStorageAccountName
output dataFactoryName string = dataFactoryName
