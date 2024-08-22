targetScope = 'subscription'

param location string = 'Australia East'
param resourceGroupName string = 'asd-acr-baseimages'
param acrNames array = [
  'asdacrm01baseimages01'
  'asdacrm01quarantineimages01'
]

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module acr './acr.bicep' = [for acrName in acrNames: {
  name: 'acrName-${acrName}'
  scope: az.resourceGroup(resourceGroup.name)
  params:{
    acrName: acrName
    location: location
    skuName: 'Basic'
    adminUserEnabled: false
  }

}
]
