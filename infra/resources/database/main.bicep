param environment string
param dbConfig object
param envConfig object
param projectConfig object

module database '../../bicep-modules/database.bicep' = {
  name: 'database'
  params: {
    serverName: envConfig.sqlServerName
    databaseName: '${projectConfig.sqlDatabaseName}-${environment}'
    location: envConfig.location
    sku: dbConfig.sku
    maxSizeBytes: dbConfig.maxSizeBytes
    autoPauseDelay: dbConfig.autoPauseDelay
    minCapacity: dbConfig.minCapacity
    requestedBackupStorageRedundancy: dbConfig.requestedBackupStorageRedundancy
    useFreeLimit: dbConfig.useFreeLimit
  }
}
