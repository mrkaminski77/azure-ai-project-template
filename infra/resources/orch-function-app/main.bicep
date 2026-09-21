param environment string
param funcConfig object
param envConfig object
param projectConfig object

var additionalAppSettings object = union(funcConfig.additionalAppSettings, {
  AZURE_AI_PROJECT_ENDPOINT: 'https://${envConfig.foundryName}.services.ai.azure.com/api/projects/${projectConfig.aiProjectName}'
  AGENT_ID: projectConfig.agentId
})



module functionApp '../../bicep-modules/flexConsumption.bicep' = {
  name: 'functionApp'
  params: {
    location: envConfig.location
    functionAppName: '${funcConfig.functionAppName}-${environment}'
    publicNetworkAccess: funcConfig.publicNetworkAccess
    logAnalyticsWorkspaceId: envConfig.logAnalyticsWorkspaceId
    keyVaultName: envConfig.keyVaultName
    keyVaultResourceGroupName: envConfig.keyVaultResourceGroupName
    easyAuthConfig: envConfig.?easyAuthConfig ?? {}
    additionalAppSettings: additionalAppSettings
    envName: environment
    containers: funcConfig.?containers ?? []
    // storageBlobDataReaders and storageBlobDataContributors are intentionally
    // omitted here. Cross-app RBAC is handled in a separate pipeline stage
    // (storage-rbac.bicep) so that this deployment does not depend on other
    // function apps existing yet. The function app's own self-RBAC (Blob Owner,
    // Queue/Table Contributor) is still applied inside flexConsumption.bicep
    // because the storage account is always co-deployed in the same template.
  }
}

