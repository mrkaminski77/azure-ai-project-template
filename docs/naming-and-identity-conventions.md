# Naming Conventions and System-Assigned Identity Pattern

This document describes the architectural pattern and conventions for naming Azure resources and managing system-assigned managed identities across environments.

---

## 1. The Core Principles

1. **Environment Isolation for Identities**: Any Azure resource that utilizes a System-Assigned Managed Identity (e.g. Azure Functions, Azure AI Foundry Projects) must be strictly isolated per environment. A `dev` service principal must never be granted access in `prod` or vice versa.
2. **Environment-Agnostic Configurations**: Configuration files (`func-config.yml`, `project-config.yml`, `ai-config.yml`) define base resource names without environment designators. This keeps configuration files portable and reusable across deployment stages.
3. **Deterministic Derivation**: Environment designator suffixes (e.g. `-dev`, `-test`, `-prod`) are applied programmatically by Bicep templates during deployment.

---

## 2. Resource Creation Pattern

When creating any resource that possesses or can possess a **System-Assigned Identity**:
- The created Azure resource name **must always be suffixed** with the environment designator:
  $$\text{Resource Name} = \text{baseName} + \text{"-"} + \text{environment}$$

### Examples

| Resource Type | Base Name (in YAML config) | Environment | Azure Resource Name |
| :--- | :--- | :--- | :--- |
| Function App (`Microsoft.Web/sites`) | `orch-function-app` | `dev` | `orch-function-app-dev` |
| Function App (`Microsoft.Web/sites`) | `mcp-function-app` | `dev` | `mcp-function-app-dev` |
| AI Foundry Project (`Microsoft.CognitiveServices/accounts/projects`) | `BidSentinel` | `dev` | `BidSentinel-dev` |

### Implementation in Bicep
Modules that create resources with identities enforce this suffix:
```bicep
var fullFunctionAppName = endsWith(functionAppName, '-${environment}') ? functionAppName : '${functionAppName}-${environment}'

resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: fullFunctionAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  ...
}
```

---

## 3. Storage Account Access & RBAC Grant Pattern

When granting permissions (such as **Storage Blob Data Contributor** or **Storage Blob Data Reader**) on storage accounts to external resources:

1. **Unsuffixed Input**: The role assignment inputs (`storageBlobDataContributors`, `storageBlobDataReaders`) expect the **base name without suffix**.
   ```yaml
   # func-config.yml
   storageBlobDataContributors:
     - mcp-function-app
   ```

2. **Automatic Suffixing**: The RBAC Bicep template appends the environment designator when looking up the `existing` resource to obtain its `principalId`:
   ```bicep
   resource storageBlobDataContributorSites 'Microsoft.Web/sites@2024-11-01' existing = [for name in storageBlobDataContributors: {
     name: endsWith(name, '-${environment}') ? name : '${name}-${environment}'
   }]

   resource storageBlobDataContributorRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (name, i) in storageBlobDataContributors: {
     name: guid(storageAccount.id, storageBlobDataContributorSites[i].id, storageBlobDataContributorRoleId)
     scope: storageAccount
     properties: {
       roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
       principalId: storageBlobDataContributorSites[i].identity.principalId
       principalType: 'ServicePrincipal'
     }
   }]
   ```

3. **Target Storage Account Derivation**: The storage account itself derives its unique name deterministically from the suffixed host function app name:
   ```bicep
   var fullFunctionAppName = endsWith(functionAppName, '-${environment}') ? functionAppName : '${functionAppName}-${environment}'
   var deploymentStorageAccountName = 'stg${uniqueString(fullFunctionAppName)}'
   ```
   Both the base deployment (`flexConsumption.bicep`) and the cross-app RBAC deployment (`storage-rbac.bicep`) use the identical formula, guaranteeing that the role assignments attach to the intended storage account.

---

## 4. Summary Matrix

| Context | Where Specified | Suffix Expectation | Handled By |
| :--- | :--- | :--- | :--- |
| Function App definition | `func-config.yml` (`functionAppName`) | **No suffix** (e.g. `orch-function-app`) | Bicep adds `-${environment}` |
| Cross-app storage permissions | `func-config.yml` (`storageBlobDataContributors`) | **No suffix** (e.g. `mcp-function-app`) | Bicep adds `-${environment}` |
| AI Project name | `project-config.yml` (`aiProjectName`) | **No suffix** (e.g. `BidSentinel`) | Bicep adds `-${environment}` |
| Existing identity lookup in Bicep | `main.bicep` or `storage-rbac.bicep` | **Expects base name**, adds suffix | Bicep (`${name}-${environment}`) |
