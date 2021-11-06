## jumphost post provisioning script

# turn realtime  ativirus
Set-MpPreference -DisableRealtimeMonitoring $false

### install chocolaty
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

### install packages
choco install -y vscode git vagrant

### install Hyper-v role
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools

### disable antivirus
Uninstall-WindowsFeature Windows-Defender

### restart host
Restart-Computer
