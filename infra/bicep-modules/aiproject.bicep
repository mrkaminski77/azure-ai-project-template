param foundryResourceName string 
param projectName string
param orchestratorPrincipalId string

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2026-05-01' = {
  name: '${foundryResourceName}/${projectName}'
  location: 'australiaeast'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Default project created with the resource'
    displayName: projectName
  }
}

var foundryUserRoleId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'

resource orchestratorFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryProject.id, orchestratorPrincipalId, foundryUserRoleId)
  scope: foundryProject
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleId)
    principalId: orchestratorPrincipalId
    principalType: 'ServicePrincipal'
  }
}

