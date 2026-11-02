# Run in an elevated PowerShell and configure the service account before starting it.
$service = 'XERJ'
$nssm = (Get-Command nssm -ErrorAction Stop).Source
$exe = "$env:USERPROFILE/.local/bin/xerj.exe"
$directory = "$env:LOCALAPPDATA/xerj"
$config = "$directory/config.toml"

& $nssm install $service $exe --insecure --config "`"$config`""
if (-not (Get-Service -Name $service -ErrorAction SilentlyContinue)) { throw 'NSSM service installation failed. Run PowerShell as administrator.' }
& $nssm set $service Description 'XERJ local search and indexing service.'
& $nssm set $service Start SERVICE_DELAYED_AUTO_START
& $nssm set $service AppDirectory $directory
& $nssm edit $service
