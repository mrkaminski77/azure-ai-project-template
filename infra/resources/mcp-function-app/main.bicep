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
    storageBlobDataReaders: funcConfig.?storageBlobDataReaders ?? []
    storageBlobDataContributors: funcConfig.?storageBlobDataContributors ?? []
    containers: funcConfig.?containers ?? []
  }
}

