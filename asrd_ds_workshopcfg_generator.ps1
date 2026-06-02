#Requires -Version 5.1
using namespace System.Collections.Generic

[CmdletBinding()]
param(
	[string]$ParamApiKey = "15BAAE322ACFADED6C8C8D0B8A32CEC6",
	[int]$ParamAppId = 563560,
	[int64]$ParamHoIAFCollection = 3009776383,
	[int[]]$ParamQueryTypes = @(0,5),
	[string[]]$ParamContent = @("Challenge","Campaign","Bonus","Deathmatch","Endless"),
	[string[]]$ParamGenre = @("Survival","Training"),
	[bool]$ParamAdminQuery = $True,
	[string]$ParamFileCFG = "workshop.cfg"
)

[string]$adminQuery = if ($ParamAdminQuery) { "true" } else { "false" }

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# # ═══════════════════════════════════════════════════════════════════════════════
# #  CONSOLE SETUP
# # ═══════════════════════════════════════════════════════════════════════════════

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# # ═══════════════════════════════════════════════════════════════════════════════
# #  HTTP CLIENT (SINGLETON)
# # ═══════════════════════════════════════════════════════════════════════════════

Add-Type -AssemblyName System.Net.Http
if (-not $script:httpClient) {
	$handler = New-Object System.Net.Http.HttpClientHandler
	$handler.AutomaticDecompression = `
		[System.Net.DecompressionMethods]::GZip -bor `
		[System.Net.DecompressionMethods]::Deflate
	$script:httpClient = New-Object System.Net.Http.HttpClient($handler)
	$script:httpClient.Timeout = [TimeSpan]::FromSeconds(30)
}

# # ═══════════════════════════════════════════════════════════════════════════════
# #  JSON SERIALIZER
# # ═══════════════════════════════════════════════════════════════════════════════

Add-Type -AssemblyName System.Web.Extensions
$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$serializer.MaxJsonLength = 50MB

# # ═══════════════════════════════════════════════════════════════════════════════
# #  STRING BUILDER
# # ═══════════════════════════════════════════════════════════════════════════════

$uriBuilder = [System.Text.StringBuilder]::new(8192)

# # ═══════════════════════════════════════════════════════════════════════════════
# #  DATA STRUCTURE
# # ═══════════════════════════════════════════════════════════════════════════════

class Addon {
	[long]$Id
	[string]$Title

	[string]$Content
	[string]$Genre

	[bool]$IsHoIAF
	[bool]$IsBlacklisted
}

$addons = [List[Addon]]::new()
$addonSet = [HashSet[long]]::new()
$addonById = [Dictionary[long,Addon]]::new()

# # ═══════════════════════════════════════════════════════════════════════════════
# #  Comparer
# # ═══════════════════════════════════════════════════════════════════════════════

class AddonTitleComparer : IComparer[Addon] {
	[int] Compare([Addon]$x, [Addon]$y) {
		return [string]::CompareOrdinal($x.Title, $y.Title)
	}
}
$comparer = [AddonTitleComparer]::new()



# # ═══════════════════════════════════════════════════════════════════════════════
# #  PHASE 1
# # ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n┌─────────────────────────────────────────────────────────────────────────────┐"   -ForegroundColor Cyan
Write-Host   "│ PHASE 1/4: PRECOMPUTING SETS                                                │"   -ForegroundColor Cyan
Write-Host   "└─────────────────────────────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
$phaseStartTime = $stopwatch.Elapsed

# # ──────────────────────────────────────────────────────────────────────────────
# #  BLACKLIST DEFINITIONS
# # ──────────────────────────────────────────────────────────────────────────────

$blacklist = [ordered]@{
	"training"	 = @{desc="Training addons";ids=@(2811295212,1489254161,915825188,2275275660,1416570964,916055799,913021935,1973725602)}
	"poor"		 = @{desc="Low quality / Poor gameplay experience"; ids=@(2836864310,2982173360,848260335,3012823362,2821100493,2966284469,1963113575)}
	"offcore"	 = @{desc="offcore, altgame, concept, experimental"; ids=@(2964924400,2647698464, 1539163254,936751209,2981587539)}
	"dev"		 = @{desc="Developer/test addons"; ids=@(3264049945,1820128803)}
	"nsfw"		 = @{desc="Inappropriate content"; ids=@()}
	"redundant1" = @{desc="Duplicates official game content"; ids=@(2091618233,2814753147,2934788251,914071790,2319526216,918258674)}
	"redundant2" = @{desc="Duplicates workshop content "; ids=@(1206252032,957780766,1287920225)}
	"conflict"	 = @{desc="Conflicts with other addons"; ids=@()}
	"crash"		 = @{desc="Causes game crashes"; ids=@(2970666444,3034646999,913650485)}
}


$totalIds = 0
foreach ($cat in $blacklist.Values) {
	$totalIds += $cat.ids.Count
}

$catCount = $blacklist.Count

$blacklistSet = [HashSet[long]]::new($totalIds)
$blacklistByCategory = [Dictionary[string, HashSet[long]]]::new($catCount, [StringComparer]::OrdinalIgnoreCase)

foreach ($cat in $blacklist.Keys) {
	$ids = $blacklist[$cat].ids
	$set = [HashSet[long]]::new($ids.Count)

	$blacklistByCategory[$cat] = $set

	foreach ($id in $ids) {
		$lid = [long]$id
		[void]$blacklistSet.Add($lid)
		[void]$set.Add($lid)
	}
}


# # ──────────────────────────────────────────────────────────────────────────────
# #  HoIAF COLLECTION FETCH
# # ──────────────────────────────────────────────────────────────────────────────

$HoIAFSet = [HashSet[long]]::new()

$uri = "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/"
$body = "collectioncount=1&publishedfileids%5B0%5D=$ParamHoIAFCollection"

$attempt = 0
$httpResponse = $null

while ($true) {
	try {
		$httpRequest = New-Object System.Net.Http.HttpRequestMessage `
			([System.Net.Http.HttpMethod]::Post, $uri)

		$httpRequest.Content = New-Object System.Net.Http.StringContent(
			$body,
			[System.Text.Encoding]::UTF8,
			"application/x-www-form-urlencoded"
		)

		$httpResponse = $script:httpClient.SendAsync($httpRequest).Result
		if (-not $httpResponse.IsSuccessStatusCode) { throw }

		$data = $httpResponse.Content.ReadAsStringAsync().Result
		$response = $serializer.DeserializeObject($data)

		break
	}
	catch {
		$attempt++
		if ($attempt -ge 4) { throw }
		Start-Sleep -Milliseconds (250 * $attempt)
	}
	finally {
		if ($httpRequest) { $httpRequest.Dispose() }
		if ($httpResponse) { $httpResponse.Dispose() }
	}
}

if ($response -and $response.response.collectiondetails[0].children) {
	foreach ($c in $response.response.collectiondetails[0].children) {
		[void]$HoIAFSet.Add([long]$c.publishedfileid)
	}
}

$elapsed = $stopwatch.Elapsed - $phaseStartTime
Write-Host "  >> Blacklisted addons  : $($blacklistSet.Count)" -ForegroundColor Green
Write-Host "  >> HoIAF collection    : $($HoIAFSet.Count) addons" -ForegroundColor Green
Write-Host "  >> Completed in        : $($elapsed.TotalSeconds.ToString('0.00')) s" -ForegroundColor Gray



# # ═══════════════════════════════════════════════════════════════════════════════
# #  PHASE 2
# # ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n┌─────────────────────────────────────────────────────────────────────────────┐"   -ForegroundColor Cyan
Write-Host   "│ PHASE 2/4: SCANNING STEAM WORKSHOP                                          │"   -ForegroundColor Cyan
Write-Host   "└─────────────────────────────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
$phaseStartTime = $stopwatch.Elapsed

$uriBuilder.Length = 0
[void]$uriBuilder.Append("https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/")
[void]$uriBuilder.Append("?key=").Append($ParamApiKey)
[void]$uriBuilder.Append("&appid=").Append($ParamAppId)
[void]$uriBuilder.Append("&admin_query=").Append($adminQuery)
[void]$uriBuilder.Append("&ids_only=true")
[void]$uriBuilder.Append("&match_all_tags=false")
[void]$uriBuilder.Append("&filetype=0")
[void]$uriBuilder.Append("&numperpage=1000")
for ($i = 0; $i -lt $ParamContent.Count; $i++) {
	$content = [string]$ParamContent[$i]
	[void]$uriBuilder.Append("&requiredtags[").Append($i).Append("]=").Append($content)
}
$baseUri = $uriBuilder.ToString()

foreach ($qt in $ParamQueryTypes) {
	$cursor = "*"
	$prevCount = 0
	$seen = $null
	$guard = 0
	$pageCount = 0

	do {
		++$pageCount
		Write-Progress -Activity "Phase 2/4: Scanning Steam Workshop" `
			-Status "QueryType $qt | Page $pageCount | Total found: $($addonSet.Count)" `
			-PercentComplete -1

		$uriBuilder.Length = 0
		[void]$uriBuilder.Append($baseUri)
		[void]$uriBuilder.Append("&query_type=").Append($qt)
		[void]$uriBuilder.Append("&cursor=").Append($cursor)
		$uri = $uriBuilder.ToString()

		$attempt = 0
		while ($true) {
			try {
				$data = $script:httpClient.GetStringAsync($uri).Result
				$response = $serializer.DeserializeObject($data)
				break
			}
			catch {
				$attempt++
				if ($attempt -ge 4) { throw }
				Start-Sleep -Milliseconds (250 * $attempt)
			}
		}

		if (-not $response) { break }

		$details = $response.response.publishedfiledetails
		if ($details) {
			foreach ($d in $details) {
				[void]$addonSet.Add([long]$d.publishedfileid)
			}
		}

		$newCursor = $response.response.next_cursor
		$data = $null
		$response = $null
		
		if (-not $newCursor -or $newCursor -eq $cursor) { break }

		$cursor = $newCursor

		if (++$guard -gt 2000) { break }

	} while ($true)
}

Write-Progress -Activity "Phase 2/4: Scanning Steam Workshop" -Completed
$elapsed = $stopwatch.Elapsed - $phaseStartTime
Write-Host "  >> Unique addon found  : $($addonSet.Count)" -ForegroundColor Green
Write-Host "  >> Completed in        : $($elapsed.TotalSeconds.ToString('0.00')) s" -ForegroundColor Gray



# # ═══════════════════════════════════════════════════════════════════════════════
# #  PHASE 3
# # ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n┌─────────────────────────────────────────────────────────────────────────────┐"   -ForegroundColor Cyan
Write-Host   "│ PHASE 3/4: FETCHING ADDON DETAILS                                           │"   -ForegroundColor Cyan
Write-Host   "└─────────────────────────────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
$phaseStartTime = $stopwatch.Elapsed

$uriBuilder.Length = 0
[void]$uriBuilder.Append("https://api.steampowered.com/IPublishedFileService/GetDetails/v1/?")
[void]$uriBuilder.Append("key=").Append($ParamApiKey)
[void]$uriBuilder.Append("&appid=").Append($ParamAppId)
[void]$uriBuilder.Append("&admin_query=").Append($adminQuery)
[void]$uriBuilder.Append("includetags=true")
[void]$uriBuilder.Append("includeadditionalpreviews=false")
[void]$uriBuilder.Append("includechildren=false")
[void]$uriBuilder.Append("includekvtags=false")
[void]$uriBuilder.Append("includevotes=false")
[void]$uriBuilder.Append("short_description=true")
[void]$uriBuilder.Append("includeforsaledata=false")
[void]$uriBuilder.Append("includemetadata=false")
[void]$uriBuilder.Append("return_playtime_stats=0")
[void]$uriBuilder.Append("strip_description_bbcode=false")
[void]$uriBuilder.Append("includereactions=false")

$baseUri = $uriBuilder.ToString()

$ids = [long[]]::new($addonSet.Count)
$addonSet.CopyTo($ids, 0)

$addons = [List[Addon]]::new($ids.Length)

$contentSet = [HashSet[string]]::new($ParamContent, [StringComparer]::OrdinalIgnoreCase)
$genreSet = [HashSet[string]]::new($ParamGenre, [StringComparer]::OrdinalIgnoreCase)

$contentMatches = [List[string]]::new($ParamContent.Count)
$genreMatches   = [List[string]]::new($ParamGenre.Count)

$empty = @()

$sizeChunk = 100
$totalChunks = [int][Math]::Ceiling($ids.Length / $sizeChunk)
$currentChunk = 0


for ($start = 0; $start -lt $ids.Length; $start += $sizeChunk) {

	++$currentChunk
	$end = [Math]::Min($start + $sizeChunk - 1, $ids.Length - 1)
	$chunkSize = $end - $start + 1

	Write-Progress -Activity "Phase 3/4: Fetching addon details" `
		-Status "Chunk $currentChunk/$totalChunks ($chunkSize addons)" `
		-PercentComplete -1

	$uriBuilder.Length = 0
	[void]$uriBuilder.Append($baseUri)
	$idx = 0
	for ($j = $start; $j -le $end; $j++) {
		$id = $ids[$j]
		[void]$uriBuilder.Append("&publishedfileids[").Append($idx).Append("]=").Append($id)
		$idx++
	}
	$uri = $uriBuilder.ToString()

	$attempt = 0
	while ($true) {
		try {
			$data = $script:httpClient.GetStringAsync($uri).Result
			$response = $serializer.DeserializeObject($data)
			break
		}
		catch {
			$attempt++
			if ($attempt -ge 4) { throw }
			Start-Sleep -Milliseconds (250 * $attempt)
		}
	}

	if (-not $response) {
		Write-Host "  [!] WARNING: Failed to fetch chunk $currentChunk/$totalChunks" -ForegroundColor Yellow
		continue
	}

	$details = $response.response.publishedfiledetails
	$data = $null
	$response = $null

	foreach ($d in $details) {

		# # ─────────────────────────────────────────────
		# # TEST RAW MULTI-CONTENT SIMULATION
		# # ─────────────────────────────────────────────

		# if ($d.publishedfileid -eq 1755027141) {

			# $d.tags = @(
				# @{ tag = "Campaign" },
				# @{ tag = "Bonus" },
				# @{ tag = "Survival" },
				# @{ tag = "Training" }
			# )

		# }

		$rawTags = if ($d.tags) { $d.tags.tag } else { $empty }

		$contentMatches.Clear()
		$genreMatches.Clear()

		foreach ($tag in $rawTags) {

			if ($contentSet.Contains($tag)) {
				$contentMatches.Add($tag)
			}

			if ($genreSet.Contains($tag)) {
				$genreMatches.Add($tag)
			}
		}

		# # ─────────────────────────────
		# # CONTENT DETECTION
		# # ─────────────────────────────
		switch ($contentMatches.Count) {
			0 { $contentValue = "Other" }
			1 { $contentValue = $contentMatches[0] }
			default {
				$contentMatches.Sort()
				$contentValue = [string]::Join("+", $contentMatches)
			}
		}

		# # ─────────────────────────────
		# # GENRE DETECTION
		# # ─────────────────────────────
		switch ($genreMatches.Count) {
			0 { $genreValue = "None" }
			1 { $genreValue = $genreMatches[0] }
			default {
				$genreMatches.Sort()
				$genreValue = [string]::Join("+", $genreMatches)
			}
		}

		# # ─────────────────────────────────────────────
		# #  ASSIGN
		# # ─────────────────────────────────────────────
		$id = [long]$d.publishedfileid

		$a = [Addon]::new()
		$a.Id = $id
		$a.Title = $d.title

		$a.Content = $contentValue
		$a.Genre   = $genreValue

		$a.IsBlacklisted = $blacklistSet.Contains($id)
		$a.IsHoIAF       = $HoIAFSet.Contains($id)

		$addons.Add($a)
		$addonById[$id] = $a
	}
}

$addons.Sort($comparer)

Write-Progress -Activity "Phase 3/4: Fetching addon details" -Completed
$elapsed = $stopwatch.Elapsed - $phaseStartTime
Write-Host "  >> Addons materialized : $($addons.Count)" -ForegroundColor Green
Write-Host "  >> Completed in        : $($elapsed.TotalSeconds.ToString('0.00')) s" -ForegroundColor Gray



# ═══════════════════════════════════════════════════════════════════════════════
#  PHASE 4
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n┌─────────────────────────────────────────────────────────────────────────────┐"   -ForegroundColor Cyan
Write-Host   "│ PHASE 4/4: GENERATING OUTPUT FILE                                           │"   -ForegroundColor Cyan
Write-Host   "└─────────────────────────────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
$phaseStartTime = $stopwatch.Elapsed

# ──────────────────────────────────────────────────────────────────────────────
#  BUILD TAG INDEX
# ──────────────────────────────────────────────────────────────────────────────

$index = [Dictionary[string, Dictionary[string, List[Addon]]]]::new($ParamContent.Count)
foreach ($a in $addons) {

	if ($a.IsBlacklisted) { continue }

	$genreDict = $null
	if (-not $index.TryGetValue($a.Content, [ref]$genreDict)) {
		$genreDict = [Dictionary[string, List[Addon]]]::new($ParamGenre.Count)
		$index[$a.Content] = $genreDict
	}

	$genreKey = $a.Genre
	$list = $null
	if (-not $genreDict.TryGetValue($genreKey, [ref]$list)) {
		$list = [List[Addon]]::new()
		$genreDict[$genreKey] = $list
	}
	$list.Add($a)
}

# ──────────────────────────────────────────────────────────────────────────────
#  Convert-ToAsciiSafe
# ──────────────────────────────────────────────────────────────────────────────

function Convert-ToAsciiSafe {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }

    $bytes = [System.Text.Encoding]::ASCII.GetBytes($s)
    return [System.Text.Encoding]::ASCII.GetString($bytes)
}

# ──────────────────────────────────────────────────────────────────────────────
#  WRITE CONFIGURATION FILE
# ──────────────────────────────────────────────────────────────────────────────

$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$outputPath = $base + "\" + $ParamFileCFG

$fs = [System.IO.FileStream]::new(
	$outputPath,
	[System.IO.FileMode]::Create,
	[System.IO.FileAccess]::Write,
	[System.IO.FileShare]::None,
	65536,
	[System.IO.FileOptions]::SequentialScan
)

$writer = [System.IO.StreamWriter]::new($fs, [System.Text.UTF8Encoding]::new($false))

try {
	# ──────────────────────────────────────────────────────────────────────────
	#  HEADER
	# ──────────────────────────────────────────────────────────────────────────

	$writer.WriteLine("/// workshop.cfg")
	$writer.WriteLine("/// Generated  : $((Get-Date).ToUniversalTime().ToString(`"yyyy-MM-ddTHH:mm:ssZ`"))")
	$writer.WriteLine("///---------------------------------------------------------------------------")
	$writer.WriteLine("/// ALIEN SWARM REACTIVE DROP")
	$writer.WriteLine("/// SERVER WORKSHOP ADDONS CONFIG")
	$writer.WriteLine("/// Author     : Grimowy")
	$writer.WriteLine("/// Discussion : https://discord.com/channels/310381338538541056/1491812301211439318")
	$writer.WriteLine("///---------------------------------------------------------------------------")
	$writer.WriteLine("/// Content    : $($ParamContent -join ', ')")
	$writer.WriteLine("/// Genre      : $($ParamGenre -join ', ')")
	$writer.WriteLine("/// Total      : $($addons.Count) addons")
	$writer.WriteLine("/// HoIAF      : $($HoIAFSet.Count) addons")
	$writer.WriteLine("///---------------------------------------------------------------------------")
	$writer.WriteLine("/// HOW TO USE")
	$writer.WriteLine("///---------------------------------------------------------------------------")
	$writer.WriteLine("/// - Non-HoIAF servers:")
	$writer.WriteLine("///     1. Place this file (workshop.cfg) in the game's cfg directory")
	$writer.WriteLine("///        (e.g. your_asrd_server\\steamcmd\\582400\\reactivedrop\\cfg).")
	$writer.WriteLine("///     2. Comment out unwanted addons and uncomment desired ones.")
	$writer.WriteLine("///        Note: a single addon may include multiple challenges or maps.")
	$writer.WriteLine("///     3. Start the server - required addons will be downloaded automatically.")
	$writer.WriteLine("/// - HoIAF servers:")
	$writer.WriteLine("///     -  Addons are managed automatically by HoIAF.")
	$writer.WriteLine("///---------------------------------------------------------------------------")

	# ──────────────────────────────────────────────────────────────────────────
	#  ADDONS BY TAG (HoIAF + NON-HoIAF)
	# ──────────────────────────────────────────────────────────────────────────

	foreach ($content in $index.Keys) {

		$genreDict = $index[$content]

		foreach ($genre in $genreDict.Keys) {

			$writer.WriteLine()
			$writer.WriteLine("///===========================================================================")
			$writer.WriteLine("/// Content: $($content) | Genre: $($genre)")
			$writer.WriteLine("///===========================================================================")
			$writer.WriteLine()

			$list = $genreDict[$genre]
			$hoiaf = [List[Addon]]::new($list.Count)
			$non   = [List[Addon]]::new($list.Count)

			foreach ($a in $list) {
				if ($a.IsHoIAF) {
					$hoiaf.Add($a)
				}
				else {
					$non.Add($a)
				}
			}

			if ($hoiaf.Count -gt 0) {
				$writer.WriteLine("/// HoIAF")
				foreach ($a in $hoiaf) {
					$title = Convert-ToAsciiSafe $a.Title
					$writer.WriteLine("rd_enable_workshop_item $($a.Id)`t/// $($content): $($title)")
					$writer.WriteLine("/// https://steamcommunity.com/workshop/filedetails/?id=$($a.Id)")
					$writer.WriteLine()
				}
				$writer.WriteLine()
			}

			if ($non.Count -gt 0) {
				$writer.WriteLine("/// Non-HoIAF")
				foreach ($a in $non) {
					$title = Convert-ToAsciiSafe $a.Title
					if ($content -eq "Challenge") {
						$writer.WriteLine("// rd_enable_workshop_item $($a.Id)`t/// $($content): $($title)")
					} else {
						$writer.WriteLine("rd_enable_workshop_item $($a.Id)`t/// $($content): $($title)")
					}
					$writer.WriteLine("/// https://steamcommunity.com/workshop/filedetails/?id=$($a.Id)")
					$writer.WriteLine()
				}
				$writer.WriteLine()
			}
		}
	}

	# ──────────────────────────────────────────────────────────────────────────
	# EXCLUDED (FILTERED FROM RESULTS) SECTION
	# ──────────────────────────────────────────────────────────────────────────

	if ($blacklistSet.Count -gt 0) {
		$writer.WriteLine()
		$writer.WriteLine()
		$writer.WriteLine("///===========================================================================")
		$writer.WriteLine("/// /// EXCLUDED (FILTERED FROM RESULTS) ADDONS ")
		$writer.WriteLine("///===========================================================================")

		foreach ($cat in $blacklist.Keys) {
			$set = $blacklistByCategory[$cat]
			if ($set.Count -eq 0) { continue }

			$found = [List[Addon]]::new($set.Count)
			foreach ($id in $set) {
				$a = $addonById[$id]
				if ($a) {
					$a.Title = [string]::Concat($a.Content, ": ", $a.Title)
					$found.Add($a)
				}
			}

			if ($found.Count -gt 0) {
				$writer.WriteLine()
				$writer.WriteLine("///----------------------------------------")
				$writer.WriteLine("/// $($blacklist[$cat].desc)")
				$writer.WriteLine("///----------------------------------------")
				$writer.WriteLine()

				$found.Sort($comparer)
				foreach ($a in $found) {
					$writer.WriteLine("// rd_enable_workshop_item $($a.Id)`t/// $($a.Title)")
					$writer.WriteLine("/// https://steamcommunity.com/workshop/filedetails/?id=$($a.Id)")
					$writer.WriteLine()
				}
			}
		}

		$writer.WriteLine()
		$writer.WriteLine("///===========================================================================")
		$writer.WriteLine("/// END OF /// EXCLUDED (FILTERED FROM RESULTS) SECTION")
		$writer.WriteLine("///===========================================================================")
	}
} finally {
	$writer.Close()
	$writer.Dispose()
}

Write-Progress -Activity "Phase 4/4: Generating $ParamFileCFG" -Completed
$fileSize = [math]::Round((Get-Item $outputPath).Length / 1KB, 2)
$elapsed = $stopwatch.Elapsed - $phaseStartTime
Write-Host "  >> Output file         : $outputPath" -ForegroundColor Green
Write-Host "  >> File size           : $fileSize KB" -ForegroundColor Green
Write-Host "  >> Completed in        : $($elapsed.TotalSeconds.ToString('0.00')) s" -ForegroundColor Gray


# ═══════════════════════════════════════════════════════════════════════════════
#  FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

$stopwatch.Stop()
$elapsed = $stopwatch.Elapsed
Write-Host "`n┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host   "│ DONE!                                                                       │" -ForegroundColor Green
Write-Host   "└─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host "  >> TOTAL RUNTIME       : $($elapsed.TotalSeconds.ToString('0.00')) s`n" -ForegroundColor Green
Write-Host
Write-Host "[*] There is nothing more" -f Cyan -NoNewline
Write-Host " - press any key to close..." -f White
[void][System.Console]::ReadKey($true)
exit
