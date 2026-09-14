param foundryProjectName string
param mcpFunctionAppName string
param mcpToolName string
param audienceClientId string

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2026-05-01' existing = {
  name: foundryProjectName
}

resource mcpTool 'Microsoft.CognitiveServices/accounts/projects/connections@2026-05-01' = {
  parent: aiProject
  name: mcpToolName
  properties: {
    category: 'RemoteTool'
    target: 'https://${mcpFunctionAppName}.azurewebsites.net/mcp'
    // RemoteTool connections only allow a specific authType set (None, CustomKeys,
    // ProjectManagedIdentity, OAuth2, DeveloperConnection, UserEntraToken, AgentUserImpersonation,
    // AgenticIdentityToken, AgenticUser, UserTokenAndProjectManagedIdentity) - 'ManagedIdentity'
    // isn't one of them. ProjectManagedIdentity is the project's own system-assigned identity;
    // AgenticIdentityToken is the per-agent identity, which is what we want here.
    authType: 'ProjectManagedIdentity'
    useWorkspaceManagedIdentity: false
    isSharedToAll: false
    sharedUserList: []
    peRequirement: 'Required'
    peStatus: 'Active'
    // audience is a top-level property, not a metadata field - nesting it under metadata
    // silently no-ops (confirmed live: properties.audience stayed null, only metadata.audience was set).
    audience: 'api://${audienceClientId}'
    metadata: {
      type: 'custom_MCP'
    }
  }
}
