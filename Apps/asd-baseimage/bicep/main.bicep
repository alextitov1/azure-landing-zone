targetScope = 'subscription'

param location string = 'Australia East'
param resourceGroupName string = 'asd-acr-baseimages'
param acrNames array = [
  'asdacrm01baseimages01'
  'asbacrm01quarantineimages01'
]

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}



resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = [for acrName in acrNames]: {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}
