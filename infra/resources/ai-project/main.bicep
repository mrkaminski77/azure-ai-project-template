param envConfig object
param projectConfig object
param aiConfig object
param environment string

var orchestratorFunctionAppName string = '${aiConfig.orchestratorFunctionAppName}-${environment}'
var projectName string = '${projectConfig.projectName}-${environment}'

module aiproject '../../bicep-modules/aiproject.bicep' = {
  name: 'deploy-aiproject'
  scope: resourceGroup(envConfig.foundryResourceGroupName)
  params: {
    foundryResourceName: projectConfig.foundryResourceName
    projectName: projectName
    orchestratorPrincipalId: reference(resourceId('Microsoft.Web/sites', orchestratorFunctionAppName), '2022-03-01', 'Full').identity.principalId
  }
}

module mcpTools '../../bicep-modules/mcptool.bicep' = [
  for tool in items(aiConfig.mcpTools): {
    name: 'deploy-mcptool-${tool.key}'
    scope: resourceGroup(envConfig.foundryResourceGroupName)
    params: {
      foundryProjectName: '${projectConfig.foundryResourceName}/${projectName}'
      mcpToolName: tool.key
      mcpFunctionAppName: '${tool.value.mcpFunctionAppName}-${environment}'
      audienceClientId: envConfig.easyAuthConfig.entraClientId
    }
    dependsOn: [
      aiproject
    ]
  }
]

