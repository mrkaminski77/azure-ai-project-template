using 'main.bicep'

param envConfig = loadYamlContent('../../env-config.yml')[environment]
param projectConfig = loadYamlContent('../../project-config.yml')
param dbConfig = loadYamlContent('database-config.yml')
param environment = readEnvironmentVariable('ENVIRONMENT', 'dev')
