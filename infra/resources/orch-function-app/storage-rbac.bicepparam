using '../../bicep-modules/storage-rbac.bicep'

var funcConfig = loadYamlContent('func-config.yml')

// Pass base name without suffix; storage-rbac.bicep appends the environment suffix
// per the naming and identity convention (docs/naming-and-identity-conventions.md).
param functionAppName = funcConfig.functionAppName
param environment = readEnvironmentVariable('ENVIRONMENT', 'dev')
param storageBlobDataContributors = funcConfig.?storageBlobDataContributors ?? []
param storageBlobDataReaders = funcConfig.?storageBlobDataReaders ?? []
