## ═══════════════════════════════════════════════════════════════════════════════
## ASRD SRCDS GUARDIAN PS7+
## Alien Swarm Reactive Drop
## Dedicated Server Guardian
## ═══════════════════════════════════════════════════════════════════════════════

## ═══════════════════════════════════════════════════════════════════════════════
## USER SETTINGS
## ═══════════════════════════════════════════════════════════════════════════════

$hostname		= ">>> GrimCore: Veterans [HoIAF]"
$port			= "27050"
$threads		= "16"
$maxplayers		= "16"
$login			= "anonymous"

$force_install_dir = '582400'

## Validation mode: 0 - Disabled | 1 - After apps update only | 2 - Initial run only | 3 - Every server restart
$validationMode = 1

$rd_server_api_key = ""


## ═══════════════════════════════════════════════════════════════════════════════
##  RUNTIME BOOTSTRAP
## ═══════════════════════════════════════════════════════════════════════════════

#_________________________________________________
# PS version validation

$v=$PSVersionTable.PSVersion.Major -ge 7;

$p=if($v){("$PSHOME\pwsh.exe")}else{(gcm pwsh.exe -ea 0).Source}

if(!$v -and !$p){
	Write-Host "`n[!] Your powershell reeks of piss and old people." -f Red
	Write-Host "[!] Get a newer version (7+):" -f Yellow
	Write-Host "[URL] https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell" -f White
	Write-Host "[*] There is nothing more" -f Cyan -NoNewline
	Write-Host " - press any key to close..." -f White
	[void][System.Console]::ReadKey($true)
	exit
}

#_________________________________________________
# Environment & Privilege arbitration

# $inWT=if($env:WT_SESSION){$true}else{try{(Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$pid").ParentProcessId -ea Stop).ProcessName -eq 'WindowsTerminal'}catch{$false}}
$inWT=try{(Get-Process -Id (Get-CimInstance Win32_Process -Filter "ProcessId=$pid").ParentProcessId -ea Stop).ProcessName -eq 'WindowsTerminal'}catch{$false}

$wtPath=if(gcm wt.exe -ea 0){(gcm wt.exe).Source}else{gci ($env:PATH -split ';'|?{$_ -like '*\WindowsApps\*'}) -Filter wt.exe -ea 0|% FullName|select -First 1}

$a=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if(($wtPath -and !$inWT) -or !$v -or !$a){
	Write-Host "[*] Ascending..." -f Cyan
	# Logic for re-launching the process in the correct context
	# Switch runtime to PowerShell 7+ with Admin Privileges
	try {
		if ($wtPath) {
			# Run PowerShell in Windows Terminal
			$wtWindowName = 'ASRD'
			$tabTitle = "ASRD-$port"
			$proc = Start-Process $wtPath `
				-Verb RunAs `
				-ArgumentList @(
					'--window', $wtWindowName,
					'new-tab',
					'--title', $tabTitle,
					'--profile', 'PowerShell',
					$p,
					'-NoProfile',
					'-ExecutionPolicy', 'Bypass',
					'-File', $PSCommandPath
				) `
				-PassThru `
				-ErrorAction Stop
		} else {
			$proc = Start-Process $p -Verb RunAs -Args "-NoP -Ep Bypass -F `"$PSCommandPath`"" -PassThru -ErrorAction Stop
		}
		exit
	}
	catch {
		$proc = $null
		Write-Host "[!] The ascent was denied. The Guardian requires absolute authority." -f Red
		Write-Host "[*] There is nothing more" -f Cyan -NoNewline
		Write-Host " - press any key to close..." -f White
		[void][System.Console]::ReadKey($true)
		exit
	}
}
Write-Host "[Server] Your presence has been acknowledged." -f Green

# Post-bootstrap configuration
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8


## ═══════════════════════════════════════════════════════════════════════════════
##	SETTINGS
## ═══════════════════════════════════════════════════════════════════════════════

# pathes
$appIdASRD_DS		= 582400
$appIdASRD			= 563560
$pathSteamcmdDir	= Join-Path $PSScriptRoot 'steamcmd'
$pathTempZIP		= Join-Path $PSScriptRoot 'steamcmd.zip'
$pathSteamcmdEXE	= Join-Path $pathSteamcmdDir 'steamcmd.exe'
$pathAppDir			= Join-Path $pathSteamcmdDir "$force_install_dir"
$pathSrcdsEXE		= Join-Path $pathAppDir 'srcds.exe' # _console.exe'
$pathAppACF			= Join-Path $pathAppDir "steamapps\appmanifest_$($appIdASRD_DS).acf"
$pathWorkshopDir	= Join-Path $pathAppDir "reactivedrop\workshop"
$pathWorkshopACF	= Join-Path $pathWorkshopDir "appworkshop_$($appIdASRD).acf"
$urlSteamcmd		= 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'


$steamCmdCommLine = {
	[ordered]@{
		FilePath	 = $pathSteamcmdEXE
		ArgumentList = @(
			"+@ShutdownOnFailedCommand 1",
			"+developer 0",
			"+force_install_dir", $force_install_dir,
			"+login", $login,
			"+app_update", $appIdASRD_DS, $validate,
			"+quit"
		)
		NoNewWindow = $true
		PassThru = $true
		RedirectStandardOutput = "NUL"
	}
}

$tickrate	= 60
$heapsize	= 1048576
$num_edicts = 1024

$srcdsCommLine = [ordered]@{
	FilePath	 = $($pathSrcdsEXE)
	ArgumentList = @(
		"-console",
		"-high",
		"-threads", $($threads),
		"-dedicated",
		"-nodev",
		"-limitvsconst",
		"-noshaderapi",
		"-nobackground",
		"-nosound",
		"-nohltv",
		"-tvdisable",
		"-nojoy",
		"-nocrashdialog",
		"-nomessagebox",
		"-hushasserts",
		"-nominidumps",
		"-game", "reactivedrop",
		"-ip", "0.0.0.0",
		"-port", $($port),
		"-tickrate", $($tickrate),
		"-heapsize", $($heapsize),
		"-num_edicts", $($num_edicts),
		"-maxplayers", $($maxplayers),
		"+rd_server_api_key", $rd_server_api_key,
		"+log off",
		"+hostname", "`"$($hostname)`"",
		"+execifexists server.cfg",
		"+map lobby"
	)
	PassThru	 = $true
	# NoNewWindow  = $true
	WindowStyle  = "Minimized"
}


## ═══════════════════════════════════════════════════════════════════════════════
## GLOBAL STATE
## ═══════════════════════════════════════════════════════════════════════════════

$isFirstRun = $true


## ═══════════════════════════════════════════════════════════════════════════════
## FUNCTION: Log
## ═══════════════════════════════════════════════════════════════════════════════

function Log {
	param(
		[Parameter(Mandatory=$true)][ValidateSet("INFO","EXEC","DONE","FAIL","WARN","SKIP")][string]$Level,
		[Parameter(Mandatory=$true)][string]$Component,
		[string]$Message = "",
		[string]$ForegroundColor = $null
	)
	$icons	= @{ "INFO" = "[ i ]"; "EXEC" = "[...]"; "DONE" = "[OKE]"; "FAIL" = "[ERR]"; "WARN" = "[ ! ]"; "SKIP" = "[---]" }
	$colors = @{ "INFO" = "Gray"; "EXEC" = "Cyan"; "DONE" = "Green"; "FAIL" = "Red"; "WARN" = "Yellow"; "SKIP" = "DarkGray" }
	$timestamp = Get-Date -Format "HH:mm:ss"
	Write-Host ("$timestamp ") -NoNewline -ForegroundColor DarkGray
	Write-Host ("{0,-8}" -f $icons[$Level]) -NoNewline -ForegroundColor $colors[$Level]
	Write-Host ("{0,-10} | " -f $Component) -NoNewline -ForegroundColor DarkCyan
	if (-not $ForegroundColor) {
		$ForegroundColor = $colors[$Level]
	}
	Write-Host $Message -ForegroundColor $ForegroundColor
}


## ═══════════════════════════════════════════════════════════════════════════════
## HTTP CLIENT
## ═══════════════════════════════════════════════════════════════════════════════

Add-Type -AssemblyName System.Net.Http
if (-not $httpClient) {
	$handler = New-Object System.Net.Http.HttpClientHandler
	$handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
	$handler.AllowAutoRedirect = $true
	$handler.MaxAutomaticRedirections = 5

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	[System.Net.ServicePointManager]::DefaultConnectionLimit = 10
	[System.Net.ServicePointManager]::Expect100Continue = $false
	[System.Net.ServicePointManager]::MaxServicePointIdleTime = 5000

	$httpClient = New-Object System.Net.Http.HttpClient($handler)
	$httpClient.DefaultRequestHeaders.Add("Accept", "application/json")
	$httpClient.DefaultRequestHeaders.Add("User-Agent", "GrimCore ASRD SRCDS Guardian")
	$httpClient.Timeout = [TimeSpan]::FromSeconds(30)
	$httpClient.DefaultRequestHeaders.ConnectionClose = $true
}


## ═══════════════════════════════════════════════════════════════════════════════
##	FUNCTION: Invoke-WithRetry
## ═══════════════════════════════════════════════════════════════════════════════

function Invoke-WithRetry {
	param(
		[Parameter(Mandatory=$true)]
		[ScriptBlock]$ScriptBlock,

		[Parameter(Mandatory=$true)]
		[string]$OperationName,

		[int]$MaxRetries = 5,
		[int]$BaseDelaySeconds = 1,
		[int]$ExponentDelay = 2,
		[int]$MaxDelaySeconds = 10
	)

	$retryCount = 0
	$delay = $BaseDelaySeconds

	while ($retryCount -lt $MaxRetries) {
		try {
			$retryCount++

			if ($retryCount -gt 1) {
				Log "WARN" $OperationName "Attempt $retryCount/$MaxRetries (retrying in ${delay}s...)"
				Start-Sleep -Seconds $delay
				$delay = [Math]::Min($delay * $ExponentDelay, $MaxDelaySeconds)	 # Exponential backoff with limit
			}

			$result = & $ScriptBlock

			if ($retryCount -gt 1) {
				Log "INFO" $OperationName "Succeeded on attempt $retryCount"
			}

			return $result
		}
		catch {
			$errorMsg = $_.Exception.Message

			$isTransient = (($errorMsg -match "timeout|connection|network|429|503|unable to connect|operation canceled|socket") `
							-or ($_.Exception.InnerException -and ($_.Exception.InnerException.Message -match "timeout|connection")))

			if (($retryCount -ge $MaxRetries) -or (-not $isTransient)) {
				Log "FAIL" $OperationName "Failed after $retryCount attempt(s): $errorMsg"
				throw
			}

			Log "WARN" $OperationName "Transient error: $errorMsg"
		}
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
## FUNCTION: Apply-QosPolicy
## ═══════════════════════════════════════════════════════════════════════════════

function Apply-QosPolicy {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)] [string]$PolicyName,
		[Parameter(Mandatory = $true)] [string]$AppPath,
		[Parameter(Mandatory = $true)] [int]$Port,
		[Parameter(Mandatory = $true)] [int]$DSCP,
		[Parameter(Mandatory = $true)] [ValidateSet("UDP", "TCP", "Any")] [string]$Protocol
	)

	process {
		Log "EXEC" "Network" "Checking QoS Policy: [$PolicyName]..."

		if (-not (Get-NetQosPolicy -Name $PolicyName -ErrorAction SilentlyContinue)) {
			try {
				New-NetQosPolicy -Name $PolicyName `
								 -AppPathName $AppPath `
								 -IPProtocol $Protocol `
								 -IPPort $Port `
								 -DSCPValue $DSCP `
								 -ErrorAction Stop | Out-Null

				Log "DONE" "Network" "QoS Policy created: [$PolicyName] (DSCP $DSCP, Port $Port, $Protocol)."
			} catch {
				Log "WARN" "Network" "Failed to apply QoS: $($_.Exception.Message)"
				# throw $_
			}
		} else {
			Log "DONE" "Network" "QoS Policy already exists: [$PolicyName]."
		}
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
## function ConvertFrom-VDF
## ═══════════════════════════════════════════════════════════════════════════════

function ConvertFrom-VDF {
	param([string]$s)
	if([string]::IsNullOrWhiteSpace($s)){return $null}
	
	$root = @{}
	$stack = [System.Collections.Generic.Stack[hashtable]]::new()
	$stack.Push($root)
	
	$len = $s.Length
	$i = 0
	
	while($i -lt $len){
		$c = $s[$i]
		
		# fast skipping white signs (ASCII <= 32)
		if([int]$c -le 32){
			$i++
			continue
		}
		
		# comments //
		if($c -eq '/' -and $i+1 -lt $len -and $s[$i+1] -eq '/'){
			while($i -lt $len -and $s[$i] -ne "`n"){ $i++ }
			continue
		}
		
		# brackets
		if($c -eq '{'){ $i++; continue }
		if($c -eq '}'){
			if($stack.Count -gt 1){ [void]$stack.Pop() }
			$i++
			continue
		}
		
		if($c -ne '"'){ $i++; continue }
		
		# Parse KEY
		$kStart = ++$i
		while($i -lt $len -and $s[$i] -ne '"'){
			if($s[$i] -eq '\' -and $i+1 -lt $len -and $s[$i+1] -eq '"'){ $i++ }
			$i++
		}
		$key = $s.Substring($kStart, $i - $kStart)
		$i++
		
		# Search for a value or section
		while($i -lt $len -and [int]$s[$i] -le 32){ $i++ }
		
		if($i -lt $len -and $s[$i] -eq '"'){
			# Parse VALUE
			$vStart = ++$i
			while($i -lt $len -and $s[$i] -ne '"'){
				if($s[$i] -eq '\' -and $i+1 -lt $len -and $s[$i+1] -eq '"'){ $i++ }
				$i++
			}
			$val = $s.Substring($vStart, $i - $vStart)
			$stack.Peek()[$key] = $val
			$i++
		}
		else{
			# New section
			$newSec = @{}
			$stack.Peek()[$key] = $newSec
			$stack.Push($newSec)
		}
	}
	return $root
}


## ═══════════════════════════════════════════════════════════════════════════════
## function ConvertTo-VDF
## ═══════════════════════════════════════════════════════════════════════════════

function ConvertTo-VDF {
	param(
		[Parameter(Mandatory)] $InputObject,
		[switch]$Compress
	)

	$sb = [System.Text.StringBuilder]::new(8192)
	
	# Pre-generacja wcięć
	$paddings = [string[]]::new(16)
	if (-not $Compress) {
		$paddings[0] = ""
		for ($i = 1; $i -le 15; $i++) { $paddings[$i] = $paddings[$i-1] + "`t" }
		$nl = "`r`n"; $sp = "`t"
	} else {
		for ($i = 0; $i -le 15; $i++) { $paddings[$i] = "" }
		$nl = ""; $sp = " "
	}

	$inner = {
		param($obj, $depth)
		$padding = $paddings[$depth]
		
		if ($obj -is [System.Collections.IDictionary]) {
			# path for hashtable
			$enum = $obj.GetEnumerator()
			while ($enum.MoveNext()) {
				$e = $enum.Current
				$k = [string]$e.Key
				if ($k.IndexOf('"') -ne -1) { $k = $k.Replace('"', '\"') }
				
				[void]$sb.Append($padding).Append('"').Append($k).Append('"')
				
				$v = $e.Value
				if ($v -is [System.Collections.IDictionary]) {
					[void]$sb.Append($nl).Append($padding).Append('{').Append($nl)
					&$inner $v ($depth + 1)
					[void]$sb.Append($padding).Append('}').Append($nl)
				} else {
					$vs = [string]$v
					if ($vs.IndexOf('"') -ne -1) { $vs = $vs.Replace('"', '\"') }
					[void]$sb.Append($sp).Append('"').Append($vs).Append('"').Append($nl)
				}
			}
		} else {
			# path for PSCustomObject
			$enum = $obj.PSObject.Properties.GetEnumerator()
			while ($enum.MoveNext()) {
				$e = $enum.Current
				$k = [string]$e.Name
				if ($k.IndexOf('"') -ne -1) { $k = $k.Replace('"', '\"') }
				
				[void]$sb.Append($padding).Append('"').Append($k).Append('"')
				
				$v = $e.Value
				if ($v -is [System.Collections.IDictionary]) {
					[void]$sb.Append($nl).Append($padding).Append('{').Append($nl)
					&$inner $v ($depth + 1)
					[void]$sb.Append($padding).Append('}').Append($nl)
				} else {
					$vs = [string]$v
					if ($vs.IndexOf('"') -ne -1) { $vs = $vs.Replace('"', '\"') }
					[void]$sb.Append($sp).Append('"').Append($vs).Append('"').Append($nl)
				}
			}
		}
	}

	&$inner $InputObject 0
	return $sb.ToString()
}


## ═══════════════════════════════════════════════════════════════════════════════
##	FUNCTION: Update-SteamCMD
## ═══════════════════════════════════════════════════════════════════════════════

function Update-SteamCMD {
	if (-not (Test-Path $pathSteamcmdEXE)) {
		Log "INFO" "SteamCMD" "Not found. Initializing..."
		try {

			$bytes = Invoke-WithRetry -OperationName "Download SteamCMD" -MaxRetries 5 -BaseDelaySeconds 2 -ScriptBlock {
				$cancellationTokenSource = New-Object System.Threading.CancellationTokenSource
				$cancellationTokenSource.CancelAfter([TimeSpan]::FromSeconds(60))

				# Create the Request
				$request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $urlSteamcmd)

				# Send the Request with the Token
				$response = $script:httpClient.SendAsync($request, $cancellationTokenSource.Token).Result

				# Ensure success and return bytes
				$response.EnsureSuccessStatusCode() | Out-Null
				return $response.Content.ReadAsByteArrayAsync().Result
			}

			[System.IO.File]::WriteAllBytes($pathTempZIP, $bytes)

			if (-not (Test-Path $pathSteamcmdDir)) {
				New-Item -ItemType Directory -Path $pathSteamcmdDir -Force | Out-Null
			}

			Add-Type -AssemblyName System.IO.Compression.FileSystem
			[System.IO.Compression.ZipFile]::ExtractToDirectory($pathTempZIP, $pathSteamcmdDir)
			Remove-Item $pathTempZIP -Force -ErrorAction SilentlyContinue

			# Init SteamCMD
			& $pathSteamcmdEXE "+quit" | Out-Null
			Log "DONE" "SteamCMD" "Installed successfully."

		} catch {
			$line = $_.InvocationInfo.ScriptLineNumber
			Log "FAIL" "SteamCMD" "Installation failed(Line $line): $($_.Exception.Message)"
			exit 1
		}
	} else {
		Log "EXEC" "SteamCMD" "Checking for self-updates..."
		& $pathSteamcmdEXE "+quit" | Out-Null
		Log "DONE" "SteamCMD" "Ready."
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
##	FUNCTION: Update-Apps
## ═══════════════════════════════════════════════════════════════════════════════

function Update-Apps {

	Log "EXEC" "Apps" "Checking for application updates..."
	$validate = ""
	$needsSteamRun = $false

	if ( (($validationMode -eq 2) -and ($script:isFirstRun)) -or ($validationMode -eq 3)) {
		$validate = "validate";
		$needsSteamRun = $true
	}

	if ((Test-Path $pathAppACF) -and ($validate -eq "")) {
		try {
			$localBuild = (Get-Content $pathAppACF | Select-String '"buildid"\s+"(\d+)"').Matches.Groups[1].Value
			$uri = "https://api.steamcmd.net/v1/info/$($appIdASRD_DS)"
			$jsonRaw = Invoke-WithRetry -OperationName "Steam API" -ScriptBlock {
				$cts = New-Object System.Threading.CancellationTokenSource
				$cts.CancelAfter([TimeSpan]::FromSeconds(15))

				$request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $uri)
				$response = $script:httpClient.SendAsync($request, $cts.Token).Result

				$response.EnsureSuccessStatusCode() | Out-Null
				return $response.Content.ReadAsStringAsync().Result
			}

			$resp = $jsonRaw | ConvertFrom-Json
			$steamBuild = $resp.data.$appIdASRD_DS.depots.branches.public.buildid

			if ($resp -and -not ($localBuild -eq $steamBuild)) {
				Log "INFO" "Apps" "SteamAPI: ASRD update detected (Local build: $localBuild, Steam Build: $steamBuild)."
				if ($validationMode -eq 1) {
					$validate = "validate";
				}
				$needsSteamRun = $true
			}
		} catch {
			Log "WARN" "Apps" "SteamAPI: Check failed. Forcing SteamCMD check."
			$needsSteamRun = $true
		}
	} elseif (-not (Test-Path $pathAppACF)) {
		$needsSteamRun = $true
	}

	if ($needsSteamRun) {
		try {
			Update-SteamCMD

			$valStatus = if ($validate -eq "validate") { "with validation" } else { "without validation" }

			Log "INFO" "Apps" "SteamCMD: Apps update $valStatus..."

			$params = & $steamCmdCommLine
			$script:process = Start-Process @params
			$script:process.WaitForExit()

			if ($script:process.ExitCode -ne 0) {
				Log "WARN" "Apps" "SteamCMD: Update finished with ExitCode: $($script:process.ExitCode)"
			} else {
				Log "DONE" "Apps" "SteamCMD: Apps update $($valStatus) finished."
			}
		}
		catch {
			$line = $_.InvocationInfo.ScriptLineNumber
			Log "FAIL" "Apps" "Exception during update(line $line): $($_.Exception.Message)"
		}
	} else {
		Log "DONE" "Apps" "Apps up to date."
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
##	FUNCTION: Update-Addons
## ═══════════════════════════════════════════════════════════════════════════════

function Update-Addons {
	if (-not (Test-Path $pathWorkshopACF)) {
		Log "SKIP" "Addons" "Workshop manifest not found. Skipping check."
		return
	}

	Log "EXEC" "Addons" "Scanning Workshop for updates..."

	try {
		$acfRaw = Get-Content $pathWorkshopACF -Raw
		$acfObj = ConvertFrom-VDF $acfRaw
		
		$installedBase = $acfObj.AppWorkshop.WorkshopItemsInstalled
		$detailsBase = $acfObj.AppWorkshop.WorkshopItemDetails
		if ($null -eq $installedBase) {
			Log "SKIP" "Addons" "No addons found in Workshop manifest structure."
			return
		}

		# Getting ID of all addons from an object (keys in Hashtable)
		$allAddonIDs = $installedBase.Keys
		if ($allAddonIDs.Count -eq 0) {
			Log "SKIP" "Addons" "Workshop manifest is empty."
			return
		}

		$sb = [System.Text.StringBuilder]::new()
		[void]$sb.Append("itemcount=$($allAddonIDs.Count)")
		$idx = 0
		$enum = $allAddonIDs.GetEnumerator()
		while ($enum.MoveNext()) {
			$id = $enum.Current
			[void]$sb.Append("&publishedfileids[$idx]=$id")
			$idx++
		}
		$apiRaw = Invoke-WithRetry -OperationName "Steam API" -ScriptBlock {
			$cts = [System.Threading.CancellationTokenSource]::new()
			$cts.CancelAfter([TimeSpan]::FromSeconds(30))
			$payload = [System.Net.Http.StringContent]::new($sb.ToString(), [System.Text.Encoding]::UTF8, "application/x-www-form-urlencoded")
			$response = $script:httpClient.PostAsync("https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/", $payload, $cts.Token).Result
			$response.EnsureSuccessStatusCode() | Out-Null
			return $response.Content.ReadAsStringAsync().Result
		}
		$apiResponse = $apiRaw | ConvertFrom-Json

		# 3. Analysis and Execution (Single-Pass)
		$workshopContentPath = Join-Path $pathWorkshopDir "content\$($appIdASRD)"
		$changed = $false

		$enum = $apiResponse.response.publishedfiledetails.GetEnumerator()
		while ($enum.MoveNext()) {
			$details = $enum.Current
			$id = $details.publishedfileid
			$localItem = $installedBase[$id]

			if ($null -ne $localItem) {
				$serverTime = [int64]$details.time_updated
				$localTime = [int64]$localItem.timeupdated
				
				if ($serverTime -gt $localTime) {
					if (-not $changed) {
						Log "WARN" "Addons" "Found outdated addons. Starting purge..."
						$changed = $true
					}
					# 1. Removing from an object in memory (reference to $acfObj)
					[void]$installedBase.Remove($id)
					[void]$detailsBase.Remove($id)
					# 2. Deleting files from disk
					$modFolder = Join-Path $workshopContentPath $id
					if (Test-Path $modFolder) { 
						Remove-Item $modFolder -Recurse -Force -ErrorAction SilentlyContinue 
					}
					Log "INFO" "Addons" "Addon $id -> PURGED (Server: $serverTime > Local: $localTime)"
				}
			}
		}
		# 4. Finalizacja zapisu
		if ($changed) {
			$newAcfContent = ConvertTo-VDF $acfObj
			Set-Content $pathWorkshopACF $newAcfContent -Encoding UTF8
			Log "DONE" "Addons" "Manifest updated. Server will download updated addons on startup."
		} else {
			Log "DONE" "Addons" "All addons are up to date."
		}
	} catch {
		$line = $_.InvocationInfo.ScriptLineNumber
		Log "FAIL" "Addons" "CRITICAL ERROR (Line $line): $($_.Exception.Message)"
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
##	FUNCTION: Cleanup-Server
## ═══════════════════════════════════════════════════════════════════════════════

function Cleanup-Server {
	Log "EXEC" "Cleanup" "Purging files..."

	$targets = @(
		(Join-Path $pathSteamcmdDir "logs\*"),
		(Join-Path $pathAppDir "logs\*"),
		(Join-Path $pathAppDir "tilegen_log.txt"),
		(Join-Path $pathSteamcmdDir "*.mdmp"),
		(Join-Path $pathSteamcmdDir "*.tmp"),
		(Join-Path $pathSteamcmdDir "*.cachedmsg"),
		(Join-Path $pathSteamcmdDir "depotcache\*"),
		(Join-Path $pathAppDir "depotcache\*"),
		(Join-Path $pathSteamcmdDir "userdata\*"),
		(Join-Path $pathAppDir "userdata\*"),
		(Join-Path $pathAppDir "reactivedrop\save\*.campaignsave")
	)

	$deletedTotal = 0

	foreach ($pattern in $targets) {
		try {
			# $filesToDelete = Get-ChildItem -Path $pattern -File -Recurse -ErrorAction SilentlyContinue
			$filesToDelete = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue
			if ($filesToDelete) {
				$currentCount = @($filesToDelete).Count

				$filesToDelete | Remove-Item -Force -ErrorAction SilentlyContinue

				$deletedTotal += $currentCount
				# $patternName = Split-Path $pattern -Leaf
				# Log "INFO" "Cleanup" "Pattern cleared: $patternName. Removed $currentCount files."
			}
		} catch {
			$line = $_.InvocationInfo.ScriptLineNumber
			Log "FAIL" "Cleanup" "CRITICAL ERROR (Line $line): $($_.Exception.Message)"
		}
	}

	if ($deletedTotal -gt 0) {
		Log "DONE" "Cleanup" "Purge complete. Total files removed: $deletedTotal"
	} else {
		Log "INFO" "Cleanup" "Nothing to delete. System is clean."
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
##	FUNCTION: CloseServer
## ═══════════════════════════════════════════════════════════════════════════════

function CloseServer {

	if ($script:isClosing) { return }
	$script:isClosing = $true

	Write-Host
	# 1. Terminacja procesu SRCDS
	if ($script:process -and -not $script:process.HasExited) {
		Log "EXEC" "Guardian" "Killing SRCDS process (PID: $($script:process.Id))..."
		try {
			$script:process.Kill()
			Log "DONE" "Server" "Process terminated."
		} catch {
			Log "FAIL" "Server" "Could not kill process: $($_.Exception.Message)"
		}
	}

	# 2. Usuwanie polisy QoS
	if (Get-NetQosPolicy -Name $script:policyName -ErrorAction SilentlyContinue) {
		Log "EXEC" "Cleanup" "Removing QoS Policy ($policyName)..."
		try {
			Remove-NetQosPolicy -Name $script:policyName -Confirm:$false -ErrorAction Stop
			Log "DONE" "Cleanup" "QoS Policy removed successfully."
		} catch {
			Log "WARN" "Cleanup" "Failed to remove QoS Policy: $($_.Exception.Message)"
		}
	}

	# 3. Zwalnianie zasobów .NET
	if ($script:httpClient) {
		Log "EXEC" "Cleanup" "Disposing HTTP Client..."
		try {
			$script:httpClient.Dispose()
			$script:httpClient = $null
			Log "DONE" "Cleanup" "HTTP Client disposed."
		} catch {
			Log "WARN" "Cleanup" "Failed to dispose HTTP Client: $($_.Exception.Message)"
		}
	}

	Log "EXEC" "Cleanup" "Releasing system memory (GC)..."
	try {
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		Log "DONE" "Cleanup" "Memory released."
	} catch {
		Log "SKIP" "Cleanup" "GC was busy, memory will be freed by OS later."
	}

	Write-Host
	Log "DONE" "Guardian" "Guardian safely stopped. System clean."
	Write-Host

	while ($true) {
		Write-Host "[*] Press " -ForegroundColor Cyan -NoNewline
		Write-Host "Y" -ForegroundColor Green -NoNewline
		Write-Host " to restart the Guardian or " -ForegroundColor White -NoNewline
		Write-Host "N" -ForegroundColor Red -NoNewline
		Write-Host " to close the program." -ForegroundColor White

		$key = [System.Console]::ReadKey($true)

		switch ($key.Key) {
			'Y' {
				Write-Host
				Log "INFO" "Guardian" "Restart requested by operator."

				Start-Process $script:p -ArgumentList @(
					'-NoProfile',
					'-ExecutionPolicy', 'Bypass',
					'-File', $PSCommandPath
				)

				exit
			}

			'N' {
				Write-Host
				Log "INFO" "Guardian" "Shutdown requested by operator."
				exit
			}
		}
	}
}


## ═══════════════════════════════════════════════════════════════════════════════
##	GUARDIAN LOOP
## ═══════════════════════════════════════════════════════════════════════════════

$policyName = "ASRD_SRCDS_$port"

$timeToRestart = 1

# Konfiguracja UI i Monitoringu

$gracePeriodSec = 15

$uiBoxWidth		 = 65
$uiColorMain	 = "DarkCyan"
$uiColorStat	 = "Gray"
$uiBgColor		 = $Host.UI.RawUI.BackgroundColor
$lineChar		 = "═"
$separator		 = $lineChar * $uiBoxWidth

$avgRangeMinutes = 5
$sleepMs		 = 1000
$samplesPerSec	 = 1000 / $sleepMs
$historyLimit	 = [int]($avgRangeMinutes * 60 * $samplesPerSec)


$script:cpuHistory	  = [System.Collections.Generic.Queue[int]]::new($historyLimit)
$script:ramHistory	  = [System.Collections.Generic.Queue[int]]::new($historyLimit)
$script:cpuHistorySum = 0
$script:ramHistorySum = 0
$script:cpuPeak		  = 0
$script:ramPeak		  = 0
$scriptStartedTime	  = [DateTime]::UtcNow

[Console]::TreatControlCAsInput = $false

# Register the cleanup function to fire when console is closed (X button)
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { CloseServer } | Out-Null
[Console]::CancelKeyPress += {
    param($sender, $eventArgs)
    $eventArgs.Cancel = $true
    CloseServer
    exit
}

try {
	while ($true) {
		Clear-Host
		Write-Host $separator -ForegroundColor $uiColorMain
		$headerLines = @(
			"  Script:    SRCDS GUARDIAN",
			"  Game:      Alien Swarm: Reactive Drop",
			$separator
		)
		foreach ($line in $headerLines) {
			Write-Host $line.PadRight($uiBoxWidth) -ForegroundColor $uiColorMain -BackgroundColor $uiBgColor
		}
		$headerLines = @(
			"  Hostname:  $hostname",
			"  Port:      $port",
			$separator,
			"  PID:  WAITING",
			"  CPU:  WAITING",
			"  RAM:  WAITING"
		)
		foreach ($line in $headerLines) {
			Write-Host $line.PadRight($uiBoxWidth) -ForegroundColor Black -BackgroundColor $uiColorMain
		}
		Write-Host $separator.PadRight($uiBoxWidth) -ForegroundColor $uiColorMain -BackgroundColor $uiBgColor
		Write-Host

		Cleanup-Server
		Update-Apps
		Update-Addons
		Apply-QosPolicy -PolicyName $policyName -AppPath $pathSrcdsEXE -Port $port -DSCP 46 -Protocol "UDP"

		$script:monitoringStartTime = ([DateTime]::UtcNow).AddSeconds($gracePeriodSec)
		$isReady = $false

		$script:process = Start-Process @srcdsCommLine -PassThru

		try {
			$script:process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
		} catch {}

		try {
			$script:process.MaxWorkingSet = [IntPtr]::new(2048MB)
			$script:process.MinWorkingSet = [IntPtr]::new(1024MB)
		} catch {}

		Write-Host
		Log "INFO" "Guardian" "Starting SRCDS..."
		Log "DONE" "Server" "SERVER ONLINE (PID: $($script:process.Id))"
		Log "INFO" "Guardian" "Server autorestart enabled."
		Log "INFO" "Guardian" "To shut down the server, press Ctrl+C." "Magenta"
		$script:isFirstRun = $false

		while (-not $script:process.HasExited) {
			try {
				if ($null -eq $Host.UI.RawUI) {
					continue
				}

				$script:process.Refresh()
				$startCpu = $script:process.TotalProcessorTime.TotalMilliseconds
				$startTime = [DateTime]::UtcNow

				Start-Sleep -Milliseconds $sleepMs

				$script:process.Refresh()
				$endCpu = $script:process.TotalProcessorTime.TotalMilliseconds
				$timeDelta = ([DateTime]::UtcNow - $startTime).TotalMilliseconds

				# Obliczanie CPU
				$curCpu = if ($timeDelta -gt 0) {
					[int]((($endCpu - $startCpu) / $timeDelta) * 100)
				} else { 0 }
				$curRam = [int]($script:process.WorkingSet64 / 1MB)

				if ($isReady) {
					# Aktualizacja historii z sumą kroczącą
					if ($curCpu -gt $script:cpuPeak) { $script:cpuPeak = $curCpu }
					$script:cpuHistorySum += $curCpu
					$script:cpuHistory.Enqueue($curCpu)

					if ($curRam -gt $script:ramPeak) { $script:ramPeak = $curRam }
					$script:ramHistorySum += $curRam
					$script:ramHistory.Enqueue($curRam)

					# Usuwanie starych elementów (O(1) z Queue)
					if ($script:cpuHistory.Count -gt $historyLimit) {
						$script:cpuHistorySum -= $script:cpuHistory.Dequeue()
					}
					if ($script:ramHistory.Count -gt $historyLimit) {
						$script:ramHistorySum -= $script:ramHistory.Dequeue()
					}

					# Średnie z sumy kroczącej (O(1))
					$cpuAvg = [int]($script:cpuHistorySum / $script:cpuHistory.Count)
					$ramAvg = [int]($script:ramHistorySum / $script:ramHistory.Count)

					$rowPid = "  PID: {0,8} | STATUS: RUNNING" -f $script:process.Id
					$rowCpu = "  CPU:  {0,4} %  | Avg {1,1} m: {2,4} %  | Peak: {3,4} % " -f $curCpu, $avgRangeMinutes, $cpuAvg, $script:cpuPeak
					$rowRam = "  RAM:  {0,4} MB | Avg {1,1} m: {2,4} MB | Peak: {3,4} MB" -f $curRam, $avgRangeMinutes, $ramAvg, $script:ramPeak
				} else {
					$isReady = [DateTime]::UtcNow -gt $script:monitoringStartTime

					$rowPid = "  PID: {0,8} | STATUS: RUNNING" -f $script:process.Id
					$rowCpu = "  CPU:  {0,4} %  | Avg {1,1} m: pending  | Peak: pending " -f $curCpu, $avgRangeMinutes
					$rowRam = "  RAM:  {0,4} MB | Avg {1,1} m: pending  | Peak: pending " -f $curRam, $avgRangeMinutes
				}

				# Rysowanie UI
				$originalX = [Console]::CursorLeft
				$originalY = [Console]::CursorTop
				$Host.UI.RawUI.CursorSize = $false
				[Console]::SetCursorPosition(0, 7)
				Write-Host $rowPid.PadRight($uiBoxWidth) -ForegroundColor Black -BackgroundColor $uiColorMain
				Write-Host $rowCpu.PadRight($uiBoxWidth) -ForegroundColor Black -BackgroundColor $uiColorMain
				Write-Host $rowRam.PadRight($uiBoxWidth) -ForegroundColor Black -BackgroundColor $uiColorMain

				[Console]::SetCursorPosition($originalX, $originalY)
				$Host.UI.RawUI.CursorSize = $true

			} catch {
				$line = $_.InvocationInfo.ScriptLineNumber
				Log "FAIL" "Guardian" "CRITICAL ERROR (Line $line): $($_.Exception.Message)"
			}
		}

		Log "WARN" "Guardian" "Server closed (Code: $($script:process.ExitCode))"
		for ($i = $timeToRestart; $i -gt 0; $i--) {
			Write-Host "Restarting in $i... `r" -NoNewline
			Start-Sleep -Seconds 1
		}
	}
}
catch {
	$line = $_.InvocationInfo.ScriptLineNumber
	Log "FAIL" "Guardian" "CRITICAL ERROR (Line $line): $($_.Exception.Message)"
}
finally {
	CloseServer 
}
