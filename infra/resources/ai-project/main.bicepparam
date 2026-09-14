using 'main.bicep'


param envConfig = loadYamlContent('../../env-config.yml')[environment]
param projectConfig = loadYamlContent('../../project-config.yml')
param aiConfig = loadYamlContent('ai-config.yml')
param environment = readEnvironmentVariable('ENVIRONMENT', 'dev')



