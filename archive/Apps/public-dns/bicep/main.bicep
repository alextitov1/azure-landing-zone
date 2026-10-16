// targetScope = 'subscription'

// param resourceGroupName string = 'rg-public-dns-01'
param dnsZones object


// param location string // = 'Australia East'


// resource resourceGroup 'Microsoft.Resources/resourceGroups@2018-05-01' = {
//   name: resourceGroupName
//   location: location
// }

module dns './dns.bicep' = [ for dnsZone in items(dnsZones) : {
  name: 'dnszone-${dnsZone.key}'
  // scope: az.resourceGroup(resourceGroup.name)
  scope: az.resourceGroup()
  params:{
    dnsZoneName: dnsZone
  }
}]
