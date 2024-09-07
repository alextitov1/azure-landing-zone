targetScope = 'subscription'

param resourceGroupName string = 'rg-public-dns-01'
param dnsZones object


param location string // = 'Australia East'
// param dnsZoneName string = '4esnok.su'


resource resourceGroup 'Microsoft.Resources/resourceGroups@2018-05-01' = {
  name: resourceGroupName
  location: location
}

module dns './dns.bicep' = [ for dnsZone in items(dnsZones) : {
  name: 'dnszone-${dnsZone.key}'
  scope: az.resourceGroup(resourceGroup.name)
  params:{
    dnsZoneName: dnsZone
  }
}]

// output testOutPut array = dns[0].outputs.txtRecords 
