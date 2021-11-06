# Azure


## jump host modes

```powershell
Set-MpPreference -DisableRealtimeMonitoring $false
Uninstall-WindowsFeature Windows-Defender
```

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

```
choco install -y googlecome vscode git vagrant
```


New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 24 -InterfaceIndex 12
New-NetNat -Name MyNATnetwork -InternalIPInterfaceAddressPrefix 172.16.0.0/24




#destroy resource
```
terraform destroy -target -auto-approve azurerm_windows_virtual_machine.jumphost
```

#terraform and dsc examples

https://medium.com/modern-stack/bootstrap-a-vm-to-azure-automation-dsc-using-terraform-f2ba41d25cd2

