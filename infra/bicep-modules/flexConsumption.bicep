param functionAppName string 
param location string
// When provided, the Function App is injected into this subnet for outbound traffic.
param outboundSubnetId string = ''
param publicNetworkAccess string = 'Disabled'
param logAnalyticsWorkspaceId string
param keyVaultName string
// Key Vault may live in a different resource group than this module is deployed into.
param keyVaultResourceGroupName string
// When supplied ({ entraClientId, secretName, tenantId }), wires up App Service
// authentication (Easy Auth v2) with Entra ID. Omit to leave auth disabled.
param easyAuthConfig object = {}
// Extra app settings merged in at creation time (e.g. Key Vault secret references) so callers
// never need to read-modify-write appsettings via listAppSettings() after this module runs.
param additionalAppSettings object = {}
var deploymentStorageAccountName = 'stg${uniqueString(functionAppName)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: 'asp${uniqueString(functionAppName)}'
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: deploymentStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2026-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2026-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2026-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2026-04-01' = {
  parent: blobService
  name: 'deployment'
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: '${deploymentStorageAccountName}-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// Built-in roles, bound here to the Function App's current system-assigned identity so they
// never go stale if the identity is ever recreated. Storage Blob Data Owner is the minimum role
// documented for the host-required AzureWebJobsStorage connection (superset of Data Contributor,
// so it also covers deployment package uploads to this same storage account); Table Data
// Contributor is required for Functions host diagnostic events.
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageTableDataContributorRoleId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

resource storageBlobOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Role assignment names must be GUIDs; guid(...) keeps this deterministic per storage
  // account so redeploys always target the same object. Requires deleting any pre-existing
  // manually-created assignment for this principal+role+scope first (Azure disallows two
  // assignments for the same combo even under different names).
  name: guid(storageAccount.id, functionApp.id, storageBlobDataOwnerRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageTableContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic name - see comment above.
  name: guid(storageAccount.id, functionApp.id, storageTableDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorRoleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageQueueContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic name - see comment above.
  name: guid(storageAccount.id, functionApp.id, storageQueueDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Referencing appServicePlan.id (not a constructed string) so Bicep infers the dependency and
    // waits for the plan to finish provisioning before creating the site.
    serverFarmId: appServicePlan.id
    reserved: true
    // Only injected into the subnet (and routed) when a subnet is actually supplied.
    virtualNetworkSubnetId: empty(outboundSubnetId) ? null : outboundSubnetId
    outboundVnetRouting: empty(outboundSubnetId) ? null : {
      allTraffic: true
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: 'https://${deploymentStorageAccountName}.blob.${environment().suffixes.storage}/deployment'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
    }
    publicNetworkAccess: publicNetworkAccess
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource swiftConnection 'Microsoft.Web/sites/virtualNetworkConnections@2024-11-01' = if (!empty(outboundSubnetId)) {
  parent: functionApp
  name: 'swift'
  properties: {
    vnetResourceId: outboundSubnetId
    isSwift: true
  }
}

module keyVaultSecretsUserRoleAssignment 'keyVaultRoleAssignment.bicep' = {
  name: 'keyVaultSecretsUser-${functionAppName}'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    keyVaultName: keyVaultName
    principalId: functionApp.identity.principalId
  }
}

resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: '${functionAppName}-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource appSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: union(union({
    // Host-required storage connection. Key-based (not identity-based) since mixing both causes
    // the platform to inconsistently fall back to the connection string anyway. Without this the
    // Functions host can't start, so the zip-deploy step fails to fetch host keys.
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${deploymentStorageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }, empty(easyAuthConfig) ? {} : {
    MICROSOFT_PROVIDER_AUTHENTICATION_SECRET: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${easyAuthConfig.secretName})'
  }), additionalAppSettings)
}

resource authSettings 'Microsoft.Web/sites/config@2024-11-01' = if (!empty(easyAuthConfig)) {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: easyAuthConfig.entraClientId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
          openIdIssuer: 'https://sts.windows.net/${easyAuthConfig.tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${easyAuthConfig.entraClientId}'
            easyAuthConfig.entraClientId
          ]
        }        
      }
    }
  }
}
