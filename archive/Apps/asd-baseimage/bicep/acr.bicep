targetScope = 'resourceGroup'
param acrName string
param location string
param skuName string = 'Basic'
param adminUserEnabled bool = false

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  
  name: acrName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
  }
}
