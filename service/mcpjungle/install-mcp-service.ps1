# Run in an elevated PowerShell and configure the service account before starting it.
$service = 'MCP Jungle'
$nssm = (Get-Command nssm -ErrorAction Stop).Source
$exe = "$env:USERPROFILE/.local/bin/mcpjungle.exe"
$directory = "$env:LOCALAPPDATA/MCPJungle"
$db = "$directory/mcpjungle.db"

& $nssm install $service $exe start --host 127.0.0.1 --port 38479 --sqlite-db-path "`"$db`""
if (-not (Get-Service -Name $service -ErrorAction SilentlyContinue)) { throw 'NSSM service installation failed. Run PowerShell as administrator.' }
& $nssm set $service Description 'MCPJungle local MCP gateway and registry.'
& $nssm set $service Start SERVICE_DELAYED_AUTO_START
& $nssm set $service AppDirectory $directory
& $nssm edit $service
