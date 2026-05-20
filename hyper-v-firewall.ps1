# Name of your Hyper-V VM
$vmName = "your-vms-name"

# Port settings
$listenAddress = "0.0.0.0"
$listenPort = 2222
$connectPort_nat = 2222
$connectPort = 22
$cockpitPort_nat = 9091
$cockpitPort = 9090

Write-Host "Getting IP for VM: $vmName..."

# Get VM IP (requires Integration Services / KVP enabled)
$vmIP = (Get-VM -Name $vmName | Select-Object -ExpandProperty NetworkAdapters).IPAddresses |
    Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
    Where-Object { $_ -like "172.*" } |
    Select-Object -First 1

if (-not $vmIP) {
    Write-Host "Could not find VM IP. Is the VM running?"
    exit 1
}

Write-Host "VM IP detected: $vmIP"

$existingSSH = netsh interface portproxy show v4tov4 | Select-String "$listenAddress\s+$connectPort_nat\s+$vmIP\s+$connectPort"
if (-not $existingSSH) {
    netsh interface portproxy delete v4tov4 `
        listenaddress=$listenAddress listenport=$connectPort_nat 2>$null
    netsh interface portproxy add v4tov4 `
        listenaddress=$listenAddress listenport=$connectPort_nat `
        connectaddress=$vmIP connectport=$connectPort
    Write-Host "Port forwarding updated: $listenAddress`:$connectPort_nat -> $vmIP`:$connectPort"
} else {
    Write-Host "Port forwarding already correct: $listenAddress`:$connectPort_nat -> $vmIP`:$connectPort"
}

$existingCockpit = netsh interface portproxy show v4tov4 | Select-String "$listenAddress\s+$cockpitPort_nat\s+$vmIP\s+$cockpitPort"
if (-not $existingCockpit) {
    netsh interface portproxy delete v4tov4 `
        listenaddress=$listenAddress listenport=$cockpitPort_nat 2>$null
    netsh interface portproxy add v4tov4 `
        listenaddress=$listenAddress listenport=$cockpitPort_nat `
        connectaddress=$vmIP connectport=$cockpitPort
    Write-Host "Port forwarding updated: $listenAddress`:$cockpitPort_nat -> $vmIP`:$cockpitPort"
} else {
    Write-Host "Port forwarding already correct: $listenAddress`:$cockpitPort_nat -> $vmIP`:$cockpitPort"
}

$currentTransport = (Get-VM -VMName $vmName).EnhancedSessionTransportType
if ($currentTransport -ne 'HvSocket') {
    Set-VM -VMName $vmName -EnhancedSessionTransportType HvSocket
    Write-Host "EnhancedSessionTransportType set to HvSocket"
} else {
    Write-Host "EnhancedSessionTransportType already set to HvSocket"
}


$ruleName = "Allow TCP 2222 and 9091"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort @(2222, 9091) -Action Allow -Profile Private
}
