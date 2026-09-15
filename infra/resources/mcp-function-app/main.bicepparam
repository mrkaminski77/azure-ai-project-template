using 'main.bicep'


param envConfig = loadYamlContent('../../env-config.yml')[environment]
param projectConfig = loadYamlContent('../../project-config.yml')
param funcConfig = loadYamlContent('func-config.yml')
param environment = readEnvironmentVariable('ENVIRONMENT', 'dev')



