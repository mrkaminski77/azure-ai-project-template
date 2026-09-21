$env = 'dev'
$config = "infra/env-config.yml" | ConvertFrom-Yaml
$resourceGroupName = "$($config.$env.resourceGroupName)"
$subscription = $($config.$env.subscriptionId)

$tags = @("BusinessUnit=Citizen Services", `    
"Environment=${env}", `
"CostCentre=E.007050.30.04", `
"Project=AI Platform", `
"ServiceDescription=Enabling Services", `
"Contract=Enabling Services", `
"SupportContact=david.leyden@serco-ap.com")

az group create --subscription $subscription --name "$resourceGroupName" --location "$($config.$env.location)" --tags $tags
