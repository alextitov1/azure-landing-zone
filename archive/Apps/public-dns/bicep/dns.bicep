param dnsZoneName object
param defaultTtl string = '3600'

resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: dnsZoneName.key
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}

resource aRecord 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = [
  for record in items(dnsZoneName.value.?aRecords ?? {}): {
    name: record.key
    parent: dnsZone
    properties: {
      TTL: record.value.?ttl ?? defaultTtl
      ARecords: [
        for ip in record.value.ipv4: {
          ipv4Address: ip
        }
      ]
    }
  }
]

resource mxRecord 'Microsoft.Network/dnsZones/MX@2023-07-01-preview' = [
  for record in items(dnsZoneName.value.?mxRecords ?? {}): {
    name: record.key
    parent: dnsZone
    properties: {
      TTL: record.value.?ttl ?? defaultTtl
      MXRecords: [
        for mx in record.value.mx: {
          preference: mx.preference
          exchange: mx.exchange
        }
      ]
    }
  }
]

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2023-07-01-preview' = [
  for record in items(dnsZoneName.value.?cnameRecords ?? {}): {
    name: record.key
    parent: dnsZone
    properties: {
      TTL: record.value.?ttl ?? defaultTtl
      CNAMERecord: {
        cname: record.value.cname
      }
    }
  }
]

resource txtRecord 'Microsoft.Network/dnsZones/TXT@2023-07-01-preview' = [
  for record in items(dnsZoneName.value.?txtRecords ?? {}): {
    name: record.key
    parent: dnsZone
    properties: {
      TTL: record.value.?ttl ?? defaultTtl
      TXTRecords: [
        for txt in record.value.txt: {
          value: [txt]
        }
      ]
    }
  }
]

resource aaaaRecord 'Microsoft.Network/dnsZones/AAAA@2023-07-01-preview' = [
  for record in items(dnsZoneName.value.?aaaaRecords ?? {}): {
    name: record.key
    parent: dnsZone
    properties: {
      TTL: record.value.?ttl ?? defaultTtl
      AAAARecords: [
        for ip in record.value.ipv6: {
          ipv6Address: ip
        }
      ]
    }
  }
]

