// Standalone Bicep for cross-app storage RBAC assignments.
//
// This template is deployed in a separate pipeline stage from the function app
// itself so that the main deployment never depends on other apps existing yet.
// The function app's own self-RBAC (Blob Owner, Queue/Table Contributor) stays
// in flexConsumption.bicep because the storage account is always co-deployed there.
//
// If a referenced app has not been deployed yet this deployment will fail.
// Re-run the pipeline with the 'runRbacOnly' parameter set to true once all
// referenced apps are deployed.

param functionAppName string
param environment string
param storageBlobDataContributors array = []
param storageBlobDataReaders array = []

// Per project naming conventions (docs/naming-and-identity-conventions.md):
// Resources with system identities are named with an environment suffix: <name>-<environment>.
// When granting storage account access, inputs are expected without the suffix and the
// environment suffix is appended programmatically.
var fullFunctionAppName = endsWith(functionAppName, '-${environment}') ? functionAppName : '${functionAppName}-${environment}'

// Derive the storage account name using the same formula as flexConsumption.bicep
// so this template always targets the correct account without needing it passed in.
var deploymentStorageAccountName = 'stg${uniqueString(fullFunctionAppName)}'

var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageAccount 'Microsoft.Storage/storageAccounts@2026-04-01' existing = {
  name: deploymentStorageAccountName
}

// --- Blob Data Contributor assignments ---

resource storageBlobDataContributorSites 'Microsoft.Web/sites@2024-11-01' existing = [for name in storageBlobDataContributors: {
  name: endsWith(name, '-${environment}') ? name : '${name}-${environment}'
}]

resource storageBlobDataContributorRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (name, i) in storageBlobDataContributors: {
  // Deterministic GUID keeps redeploys idempotent (same combo → same assignment name).
  name: guid(storageAccount.id, storageBlobDataContributorSites[i].id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: storageBlobDataContributorSites[i].identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

// --- Blob Data Reader assignments ---

resource storageBlobDataReaderSites 'Microsoft.Web/sites@2024-11-01' existing = [for name in storageBlobDataReaders: {
  name: endsWith(name, '-${environment}') ? name : '${name}-${environment}'
}]

resource storageBlobDataReaderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (name, i) in storageBlobDataReaders: {
  // Deterministic GUID - see comment above.
  name: guid(storageAccount.id, storageBlobDataReaderSites[i].id, storageBlobDataReaderRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: storageBlobDataReaderSites[i].identity.principalId
    principalType: 'ServicePrincipal'
  }
}]
