param dnsZoneName object



resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: dnsZoneName.key
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}
