#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

$Name = "%Name%"
$Description = "%Description%"

New-VM `
  -Generation 2 `
  -Name "$Name" `
  -MemoryStartupBytes 2048MB `
  -SwitchName "Default Switch" `
  -VHDPath ".\%VHDPath%"

Set-VM -Name "$Name" -Notes "$Description"
Set-VM -Name "$Name" -EnhancedSessionTransportType HVSocket
Set-VMFirmware -VMName "$Name" -EnableSecureBoot Off
Set-VMProcessor -VMName "$Name" -Count 2
Enable-VMIntegrationService -VMName "$Name" -Name "Guest Service Interface"

Write-Host ""
Write-Host "Your Kali Linux virtual machine is ready."
Write-Host "In order to use it, please start Hyper-V."
Read-Host -Prompt "Press Enter to close this screen"
