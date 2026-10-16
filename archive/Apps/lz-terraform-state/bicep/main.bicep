targetScope = 'subscription'

param location string = 'Australia East'
param resourceGroupName string = 'rg-lz-mngmt-tfstate'
param storageName string = 'lzterraformstate-01'
param tags object = {
  environment: 'lz'
  deploymentType: 'bicep'
  repo: 'landing-zone'
}
param containerNameList array = [
  'lz-terraform-state-01'
  'lz-terraform-state-02'
]

param servicePlanId string = '7c8aa06c-71cb-406b-9bbc-2fa5c49437c7' //'lz-terraform-state-01'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module storage './sa.bicep' = {
  name: 'TerraformStateStorage'
  scope: az.resourceGroup(resourceGroup.name)
  params:{
    location: location
    tags: tags
    storageName: storageName
    containerNameList: containerNameList
    servicePrincipalId: servicePlanId
  }
}


