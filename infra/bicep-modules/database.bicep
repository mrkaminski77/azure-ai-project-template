param serverName string
param databaseName string
param location string
param sku object = {
  name: 'GP_S_Gen5_2'
  tier: 'GeneralPurpose'
  family: 'Gen5'
  capacity: 2
}
param maxSizeBytes int = 34359738368
param autoPauseDelay int = 60
// serverless min vCore capacity supports fractional values, so it's passed as a string and coerced via json()
param minCapacity string = '0.5'
param requestedBackupStorageRedundancy string = 'Local'
param useFreeLimit bool = true

resource database 'Microsoft.Sql/servers/databases@2025-02-01-preview' = {
  name: '${serverName}/${databaseName}'
  location: location
  sku: sku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: maxSizeBytes
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: autoPauseDelay
    requestedBackupStorageRedundancy: requestedBackupStorageRedundancy
    minCapacity: json(minCapacity)
    maintenanceConfigurationId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_Default'
    isLedgerOn: false
    useFreeLimit: useFreeLimit
    freeLimitExhaustionBehavior: 'AutoPause'
    availabilityZone: 'NoPreference'
  }
}
