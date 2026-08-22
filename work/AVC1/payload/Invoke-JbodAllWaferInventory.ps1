[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RawSearchRoot,
    [Parameter(Mandatory = $true)]
    [string]$StateRoot,
    [string]$RelayQueueRoot = "C:\ProgramData\ArgosRelayRO\queue",
    [ValidateRange(0, 3600)]
    [int]$StableAgeSeconds = 120,
    [ValidateRange(1, 10)]
    [int]$StablePasses = 2,
    [switch]$QueueRelaySummary,
    [switch]$Preflight
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script:StatusPath = Join-Path $StateRoot "state\STATUS.json"
$script:CatalogPath = Join-Path $StateRoot "catalog\ALL_WAFER_CATALOG.json"
$script:CatalogCsvPath = Join-Path $StateRoot "catalog\ALL_WAFER_CATALOG.csv"
$script:CachePath = Join-Path $StateRoot "state\OBSERVATION_CACHE.json"
$script:RelayFingerprintPath = Join-Path $StateRoot "state\LAST_RELAY_FINGERPRINT.txt"
$script:MetadataOverlayPath = Join-Path $StateRoot "metadata\verified\ACTIVE_VERIFIED_METADATA_OVERLAY.json"
$script:InsiteHoldOverlayPath = Join-Path $StateRoot "metadata\holds\ACTIVE_INSITE_METADATA_HOLDS.json"
$script:ConfirmedScribeContractHoldPath = Join-Path $StateRoot "state\CONFIRMED_SCRIBE_CONTRACT_HOLDS.json"
$script:ConfirmedScribeContractHolds = @{}
$script:RawAdmissionModulePath = Join-Path $StateRoot "ArgosRawAcquisitionAdmission.psm1"
if (-not (Test-Path -LiteralPath $script:RawAdmissionModulePath -PathType Leaf)) {
    throw "Raw acquisition admission module is missing: $script:RawAdmissionModulePath"
}
Import-Module -Name $script:RawAdmissionModulePath -ErrorAction Stop
if ($Preflight) {
    if (-not (Test-Path -LiteralPath $RawSearchRoot -PathType Container)) { throw "Raw search root does not exist: $RawSearchRoot" }
    [pscustomobject]@{ State = 'PASS_JBOD_ALL_WAFER_INVENTORY_ADMISSION_PREFLIGHT'; RawSearchRoot = [IO.Path]::GetFullPath($RawSearchRoot); MutationPerformed = $false }
    return
}

function Write-AtomicUtf8Text {
    param([string]$Path, [string]$Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $temp = Join-Path $parent (([IO.Path]::GetFileName($Path)) + "." + [Guid]::NewGuid().ToString("N") + ".tmp")
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temp, $Value, $encoding)
    try {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $backup = $Path + ".replace-backup"
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
            [IO.File]::Replace($temp, $Path, $backup, $true)
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
        }
        else {
            [IO.File]::Move($temp, $Path)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}

function Write-AtomicJson {
    param([string]$Path, [object]$Value, [int]$Depth = 12)
    Write-AtomicUtf8Text -Path $Path -Value (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine)
}

function Get-Sha256Text {
    param([string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "")
    }
    finally { $sha.Dispose() }
}

function Get-Sha256File {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-BmpHeader {
    param([string]$Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        if ($stream.Length -lt 54) { throw "BMP is shorter than its minimum header." }
        $reader = New-Object IO.BinaryReader($stream)
        try {
            if ($reader.ReadByte() -ne 0x42 -or $reader.ReadByte() -ne 0x4D) { throw "BMP signature is missing." }
            $stream.Position = 18
            $width = $reader.ReadInt32()
            $height = [Math]::Abs($reader.ReadInt32())
            $stream.Position = 28
            $bitsPerPixel = $reader.ReadInt16()
            if ($width -le 0 -or $height -le 0) { throw "BMP dimensions are invalid." }
            return [ordered]@{
                widthPx = $width
                heightPx = $height
                bitsPerPixel = $bitsPerPixel
                byteLength = $stream.Length
                headerState = "BMP_HEADER_VALID"
            }
        }
        finally { $reader.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-Channel {
    param([string]$Path)
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ($name -match '(?i)^BACKSIDE_BF$') { return "BACKSIDE_BF" }
    if ($name -match '(?i)^BACKSIDE_DF$') { return "BACKSIDE_DF" }
    if ($name -match '(?i)^FRONTSIDE_BF$') { return "FRONTSIDE_BF" }
    if ($name -match '(?i)^FRONTSIDE_DF$') { return "FRONTSIDE_DF" }
    if ($Path -match '(?i)BrightfieldBacksideWafer') { return "BACKSIDE_BF" }
    if ($Path -match '(?i)DarkfieldBacksideWafer') { return "BACKSIDE_DF" }
    if ($Path -match '(?i)BrightfieldFrontsideWafer') { return "FRONTSIDE_BF" }
    if ($Path -match '(?i)DarkfieldFrontsideWafer') { return "FRONTSIDE_DF" }
    return $null
}

function Get-Domain {
    param([string]$Path, [string]$Channel)
    if ($Channel -like 'FRONTSIDE_*') { return "FRONTSIDE" }
    if ($Path -match '(?i)BackSide[_ -]?BowComp|BowComp') { return "BOWCOMP_BACKSIDE" }
    if ($Path -match '(?i)BackSide[_ -]?Bare|Bare') { return "BARE_BACKSIDE" }
    return "UNKNOWN"
}

function Parse-Identity {
    param([string]$Path, [string]$Domain)
    $lot = ""
    $timestamp = ""
    $timestampProvenance = ""
    $slot = ""
    $variant = ""
    $match = [regex]::Match($Path, '(?i)(?<lot>\d{5}[-_]\d{3})(?<variant>(?:-[A-Z0-9]+)*)_(?<stamp>\d{14})')
    if ($match.Success) {
        $lot = $match.Groups['lot'].Value.Replace('_', '-')
        $timestamp = $match.Groups['stamp'].Value
        $timestampProvenance = 'PATH_ACQUISITION_TIMESTAMP'
        $variant = $match.Groups['variant'].Value.TrimStart('-')
    }
    else {
        $lotMatch = [regex]::Match($Path, '(?i)Lot_(?<lot>.+?)(?=_Slot\d+|[\\/])')
        if ($lotMatch.Success) { $lot = $lotMatch.Groups['lot'].Value.Replace('_', '-') }
    }
    $slotMatch = [regex]::Match($Path, '(?i)(?:[\\/_])Slot0*(?<slot>\d+)(?:[\\/]|_)')
    if ($slotMatch.Success) { $slot = ('Slot{0:D2}' -f [int]$slotMatch.Groups['slot'].Value) }
    if ([string]::IsNullOrWhiteSpace($timestamp) -and -not [string]::IsNullOrWhiteSpace($slot)) {
        # Historical Bare exports may omit the acquisition timestamp from both
        # path and filename. BF and DF still share one SlotNN directory (or one
        # flat parent), whose directory timestamp supplies a deterministic pair
        # key and review date. This is explicitly provenance-labeled and never
        # represented as a tool-recorded acquisition timestamp.
        $cursor = (Get-Item -LiteralPath $Path).Directory
        $slotDirectory = $null
        while ($null -ne $cursor) {
            if ($cursor.Name -match '(?i)^Slot0*\d+$') { $slotDirectory = $cursor; break }
            $cursor = $cursor.Parent
        }
        if ($null -eq $slotDirectory) { $slotDirectory = (Get-Item -LiteralPath $Path).Directory }
        $acquisitionDirectory = if ($null -ne $slotDirectory -and $null -ne $slotDirectory.Parent) {
            $slotDirectory.Parent
        } else { $slotDirectory }
        if ($null -ne $acquisitionDirectory) {
            $timestamp = $acquisitionDirectory.CreationTime.ToString('yyyyMMddHHmmss')
            $timestampProvenance = 'FILESYSTEM_ACQUISITION_DIRECTORY_CREATION_TIME_FALLBACK'
        }
    }
    $valid = -not [string]::IsNullOrWhiteSpace($lot) -and
        -not [string]::IsNullOrWhiteSpace($timestamp) -and
        -not [string]::IsNullOrWhiteSpace($slot)
    $variantToken = if ([string]::IsNullOrWhiteSpace($variant)) { '' } else { '_' + $variant.Replace('-', '_') }
    $identity = if ($valid) { "${lot}${variantToken}_${timestamp}_${slot}" } else { "UNPARSED_" + (Get-Sha256Text $Path).Substring(0, 16) }
    return [ordered]@{
        identity = $identity
        lot = $lot
        timestampToken = $timestamp
        timestampProvenance = $timestampProvenance
        acquisitionVariant = $variant
        slot = $slot
        domain = $Domain
        parsed = $valid
    }
}

function Convert-TimestampToken {
    param([string]$Value)
    if ($Value -match '^\d{14}$') {
        return [DateTime]::ParseExact($Value, 'yyyyMMddHHmmss', [Globalization.CultureInfo]::InvariantCulture)
    }
    return $null
}

function Get-PreviousCache {
    if (-not (Test-Path -LiteralPath $script:CachePath -PathType Leaf)) { return @{} }
    try {
        $parsed = Get-Content -LiteralPath $script:CachePath -Raw | ConvertFrom-Json
        $result = @{}
        foreach ($row in @($parsed.rows)) { $result[[string]$row.path] = $row }
        return $result
    }
    catch { return @{} }
}

function Normalize-AcquisitionKey {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $normalized = $Value.Trim().ToUpperInvariant()
    $match = [regex]::Match($normalized, '^(?<lot>\d{5}[-_]\d{3})(?<variant>.*?)_(?<stamp>\d{14})_SLOT0*(?<slot>\d+)$')
    if ($match.Success) {
        $lot = $match.Groups['lot'].Value.Replace('_','-')
        $variant = ($match.Groups['variant'].Value -replace '[^A-Z0-9]+','_').Trim('_')
        $variantToken = if ($variant) { '_' + $variant } else { '' }
        return $lot + $variantToken + '_' + $match.Groups['stamp'].Value + '_SLOT' + ([int]$match.Groups['slot'].Value).ToString('00')
    }
    return $normalized
}

function Get-VerifiedMetadataOverlay {
    $result = @{}
    if (-not (Test-Path -LiteralPath $script:MetadataOverlayPath -PathType Leaf)) { return $result }
    $overlay = Get-Content -LiteralPath $script:MetadataOverlayPath -Raw | ConvertFrom-Json
    if ([string]$overlay.schema -ne 'argos_verified_scribe_mes_metadata_overlay_v1' -or
        [string]$overlay.state -ne 'VERIFIED_REVIEW_ONLY' -or
        [string]$overlay.lookupAuthority -ne 'CONFIRMED_12_CHARACTER_SCRIBE_ONLY' -or
        -not [bool]$overlay.reviewOnly -or [bool]$overlay.xmlEligible -or [bool]$overlay.productionEligible) {
        throw 'Verified metadata overlay safety contract refused.'
    }
    foreach ($row in @($overlay.rows)) {
        $key = Normalize-AcquisitionKey ([string]$row.acquisitionKey)
        if ([string]::IsNullOrWhiteSpace($key)) { throw 'Verified metadata overlay contains an empty acquisition key.' }
        if ($result.ContainsKey($key)) { throw "Verified metadata overlay contains duplicate acquisition key $key" }
        if ([string]$row.waferId -notmatch '^[A-Z0-9]{12}$' -or
            [string]$row.identityState -notin @(
                'HUMAN_CONFIRMED_REVIEW_ONLY',
                'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY',
                'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY'
            ) -or
            [string]$row.metadataState -ne 'SCRIBE_CONFIRMED_MES_SNAPSHOT') {
            throw "Verified metadata row safety contract failed for $key"
        }
        $result[$key] = $row
    }
    return $result
}

function Get-ConfirmedScribeOverlay {
    $result=@{}
    $contractHolds=New-Object Collections.Generic.List[object]
    $path=Join-Path $StateRoot 'identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json'
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $result}
    $overlay=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    if([string]$overlay.schema-ne'argos_confirmed_scribe_overlay_v1' -or-not[bool]$overlay.reviewOnly-or[bool]$overlay.productionEligible){throw 'Confirmed-scribe overlay safety contract refused.'}
    foreach($row in @($overlay.rows)){
        $key=Normalize-AcquisitionKey ([string]$row.acquisitionKey)
        $scribe=([string]$row.waferId).Trim().ToUpperInvariant()
        $identityState=[string]$row.identityState
        $baseValid=-not[string]::IsNullOrWhiteSpace($key) -and $scribe-match'^[A-Z0-9]{12}$' -and
            ([string]$row.scribe).Trim().ToUpperInvariant()-eq$scribe -and
            $identityState-in@('HUMAN_CONFIRMED_REVIEW_ONLY','IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY','IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY')
        $imageStateValid=$true
        if($identityState-eq'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY'){
            $imageStateValid=[string]$row.scribeChecksumState-eq'SEMI_M12_IMAGE_FIRST_CHECKSUM_VALID_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH' -and
                [string]$row.operatorDisposition-eq'NOT_REASKED_EXACT_PREVIOUSLY_VERIFIED_IMAGE_READ' -and
                [string]$row.imageReadAuthority-eq'DIRECT_IMAGE_FIRST_12_CELL_TOP_RANKED_UNIQUE_M12_AND_EXACT_PREVIOUS_HUMAN_SCRIBE' -and
                @($row.priorHumanAcquisitionKeys).Count-gt0 -and
                [string]$row.proposalSha256-match'^[A-Fa-f0-9]{64}$' -and
                [string]$row.readerResultSha256-match'^[A-Fa-f0-9]{64}$'
        }elseif($identityState-eq'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY'){
            $imageStateValid=[string]$row.scribeChecksumState-eq'SEMI_M12_CURRENT_IMAGE_CANDIDATE_EXACT_UNIQUE_MES' -and
                [string]$row.operatorDisposition-eq'NOT_REQUIRED_CURRENT_PIXELS_EXACT_UNIQUE_MES' -and
                [string]$row.imageReadAuthority-eq'CURRENT_BF_DF_MULTI_CHANNEL_POLARITY_CANONICAL_M12_EXACT_UNIQUE_MES' -and
                [string]$row.readerSummarySha256-match'^[A-Fa-f0-9]{64}$' -and
                [string]$row.mesSnapshotSha256-match'^[A-Fa-f0-9]{64}$' -and
                [bool]$row.currentPixelsOnly -and [bool]$row.exactMesLookupUsed -and
                -not[bool]$row.priorWaferIdentityAssignmentUsed -and -not[bool]$row.hardcodedIdentityUsed -and
                -not[bool]$row.selectionByScoreUsed
        }
        if(-not$baseValid -or -not$imageStateValid -or $result.ContainsKey($key)){
            if(-not[string]::IsNullOrWhiteSpace($key)){
                if($result.ContainsKey($key)){[void]$result.Remove($key)}
                $hold=[pscustomobject][ordered]@{
                    acquisitionKey=$key;scribe=$scribe;state='HOLD_CONFIRMED_SCRIBE_CONTRACT_INVALID'
                    identityState=$identityState;duplicateAcquisitionKey=$script:ConfirmedScribeContractHolds.ContainsKey($key)
                    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false
                }
                $script:ConfirmedScribeContractHolds[$key]=$hold
                $contractHolds.Add($hold)
            }
            continue
        }
        if($script:ConfirmedScribeContractHolds.ContainsKey($key)){continue}
        $result[$key]=$row
    }
    Write-AtomicJson -Path $script:ConfirmedScribeContractHoldPath -Value ([ordered]@{
        schema='argos_confirmed_scribe_contract_holds_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state=if($contractHolds.Count-eq0){'PASS_NO_ROW_CONTRACT_HOLDS'}else{'EXPLICIT_ROW_CONTRACT_HOLDS'}
        holdCount=$contractHolds.Count;rows=@($contractHolds.ToArray());reviewOnly=$true
        trainingEligible=$false;xmlEligible=$false;productionEligible=$false
    }) -Depth 8
    return $result
}

function Get-InsiteMetadataHoldOverlay {
    $result=@{}
    if(-not(Test-Path -LiteralPath $script:InsiteHoldOverlayPath -PathType Leaf)){return $result}
    $overlay=Get-Content -LiteralPath $script:InsiteHoldOverlayPath -Raw|ConvertFrom-Json
    if([string]$overlay.schema-ne'argos_active_insite_metadata_holds_v1' -or
       [string]$overlay.state-ne'EXPLICIT_REVIEW_ONLY_HOLDS' -or
       -not[bool]$overlay.reviewOnly -or [bool]$overlay.trainingEligible -or
       [bool]$overlay.xmlEligible -or [bool]$overlay.productionEligible){throw 'Active Insite hold overlay safety contract refused.'}
    foreach($row in @($overlay.rows)){
        $key=Normalize-AcquisitionKey ([string]$row.acquisitionKey)
        if([string]::IsNullOrWhiteSpace($key) -or $result.ContainsKey($key) -or
           [string]$row.scribe-notmatch'^[A-Z0-9]{12}$' -or [string]$row.state-notmatch'^HOLD_INSITE_'){
            throw "Active Insite hold row safety contract failed for $key"
        }
        $result[$key]=$row
    }
    return $result
}

function Get-PreviousCatalogCounts {
    if (-not (Test-Path -LiteralPath $script:CatalogPath -PathType Leaf)) { return @{} }
    try {
        $catalog = Get-Content -LiteralPath $script:CatalogPath -Raw | ConvertFrom-Json
        return $catalog.counts
    }
    catch { return @{} }
}

function New-Status {
    param([string]$State, [string]$Detail, [object]$Counts)
    $value = [ordered]@{
        schema = "argos_jbod_all_wafer_watcher_status_v1"
        updatedUtc = [DateTime]::UtcNow.ToString('o')
        role = "JBOD"
        state = $State
        detail = $Detail
        reviewOnly = $true
        detectorAuthority = "ROUTE_ONLY_NO_DETECTOR_EXECUTION"
        xmlExportEnabled = $false
        xmlExportState = "DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY"
        rawSearchRoot = [IO.Path]::GetFullPath($RawSearchRoot)
        catalogPath = $script:CatalogPath
        counts = if ($null -eq $Counts) { [ordered]@{} } else { $Counts }
    }
    Write-AtomicJson -Path $script:StatusPath -Value $value
}

function New-StatusPng {
    param([string]$Path, [object]$Catalog)
    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object Drawing.Bitmap(1600, 900, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::FromArgb(8, 14, 18))
        $white = New-Object Drawing.SolidBrush([Drawing.Color]::White)
        $muted = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(185, 210, 220))
        $cyan = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(39, 205, 235))
        $yellow = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 201, 62))
        $title = New-Object Drawing.Font('Segoe UI', 28, [Drawing.FontStyle]::Bold)
        $large = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
        $normal = New-Object Drawing.Font('Consolas', 13, [Drawing.FontStyle]::Regular)
        try {
            $graphics.DrawString('Argos JBOD - all-wafer intake status', $title, $white, 32, 24)
            $graphics.DrawString(('Generated {0} UTC | review-only | XML disabled' -f $Catalog.generatedUtc), $normal, $muted, 34, 78)
            $graphics.DrawString(('Discovered {0}  Stable {1}  Waiting {2}  Route-ready {3}  Held {4}' -f
                $Catalog.counts.acquisitions, $Catalog.counts.stable, $Catalog.counts.waiting,
                $Catalog.counts.routeReady, $Catalog.counts.held), $large, $cyan, 34, 125)
            $graphics.DrawString('Newest acquisitions', $large, $white, 34, 185)
            $y = 230
            foreach ($row in @($Catalog.acquisitions | Select-Object -First 18)) {
                $color = if ($row.routeState -like 'READY_*') { $cyan } elseif ($row.routeState -like 'WAIT_*') { $yellow } else { $muted }
                $line = '{0,-20} {1,-17} {2,-8} {3,-18} {4}' -f $row.lot, $row.scanTimestampLocal, $row.slot, $row.domain, $row.routeState
                $graphics.DrawString($line, $normal, $color, 34, $y)
                $y += 32
            }
            $graphics.DrawString('This screen is status only. It never supplies detector pixels or XML coordinates.', $normal, $yellow, 34, 846)
        }
        finally {
            $white.Dispose(); $muted.Dispose(); $cyan.Dispose(); $yellow.Dispose()
            $title.Dispose(); $large.Dispose(); $normal.Dispose()
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Queue-RelayCatalogSummary {
    param([object]$Catalog, [string]$Fingerprint)
    if (-not $QueueRelaySummary) { return "RELAY_SUMMARY_DISABLED" }
    $pending = Join-Path $RelayQueueRoot "pending"
    if (-not (Test-Path -LiteralPath $pending -PathType Container)) { return "RELAY_QUEUE_NOT_INSTALLED" }
    $last = if (Test-Path -LiteralPath $script:RelayFingerprintPath -PathType Leaf) {
        (Get-Content -LiteralPath $script:RelayFingerprintPath -Raw).Trim()
    } else { "" }
    if ($last -eq $Fingerprint) { return "RELAY_SUMMARY_UNCHANGED" }

    $packageId = 'CAT__ALL_WAFERS__' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $partial = Join-Path $pending ($packageId + '.partial')
    $ready = Join-Path $pending ($packageId + '.ready')
    if (Test-Path -LiteralPath $partial) { throw "Refusing existing relay partial package: $partial" }
    if (Test-Path -LiteralPath $ready) { throw "Refusing existing relay ready package: $ready" }
    New-Item -ItemType Directory -Path $partial | Out-Null
    try {
        $png = Join-Path $partial 'ALL_WAFER_STATUS.png'
        New-StatusPng -Path $png -Catalog $Catalog
        Copy-Item -LiteralPath $script:CatalogPath -Destination (Join-Path $partial 'ALL_WAFER_CATALOG.json')
        Copy-Item -LiteralPath $script:CatalogCsvPath -Destination (Join-Path $partial 'ALL_WAFER_CATALOG.csv')
        $manifest = [ordered]@{
            schema = 'argos_share_image_queue_manifest_v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            state = 'READY_LOCAL_AWAITING_RELAY'
            relayState = 'ALL_WAFER_CATALOG_SUMMARY_REVIEW_ONLY'
            productionDataRoute = $false
            reviewOnly = $true
            packageId = $packageId
            lot = 'ALL_WAFERS'
            scanTimestampLocal = [DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:ss')
            side = 'STATUS_ONLY'
            waferCount = [int]$Catalog.counts.acquisitions
            payloadFile = 'ALL_WAFER_STATUS.png'
            width = 1600
            height = 900
            bytes = (Get-Item -LiteralPath $png).Length
            sha256 = Get-Sha256File $png
            sourceImage = $script:CatalogPath
            catalogFile = 'ALL_WAFER_CATALOG.json'
            catalogFingerprintSha256 = $Fingerprint
            detectorPixelsIncluded = $false
            xmlIncluded = $false
        }
        $manifestPath = Join-Path $partial 'SHARE_IMAGE_MANIFEST.json'
        $encoding = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $encoding)
        [IO.Directory]::Move($partial, $ready)
        Write-AtomicUtf8Text -Path $script:RelayFingerprintPath -Value ($Fingerprint + [Environment]::NewLine)
        return "RELAY_SUMMARY_QUEUED:$packageId"
    }
    catch {
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Recurse -Force }
        throw
    }
}

try {
    if (-not (Test-Path -LiteralPath $RawSearchRoot -PathType Container)) {
        throw "Raw search root does not exist: $RawSearchRoot"
    }
    New-Status -State 'SCANNING' -Detail 'Refreshing inventory between bounded processing batches; completed results remain available.' -Counts (Get-PreviousCatalogCounts)
    $previous = Get-PreviousCache
    $verifiedMetadata = Get-VerifiedMetadataOverlay
    $confirmedScribes = Get-ConfirmedScribeOverlay
    $insiteHolds = Get-InsiteMetadataHoldOverlay
    $now = Get-Date
    $cacheRows = New-Object Collections.Generic.List[object]
    $candidates = New-Object Collections.Generic.List[object]
    $files = @(Get-ChildItem -LiteralPath $RawSearchRoot -Recurse -File -Filter '*.bmp' -ErrorAction SilentlyContinue)

    foreach ($file in $files) {
        $admission = Get-ArgosRawAcquisitionAdmission -Path $file.FullName
        if (-not [bool]$admission.eligibleForInventory) { continue }
        $channel = Get-Channel $file.FullName
        if ([string]::IsNullOrWhiteSpace($channel)) { continue }
        $domain = Get-Domain -Path $file.FullName -Channel $channel
        $identity = Parse-Identity -Path $file.FullName -Domain $domain
        $acquisitionKey = ([string]$identity.identity) + '__' + $domain
        $prior = $previous[$file.FullName]
        $unchanged = $false
        $passes = 1
        if ($null -ne $prior) {
            $unchanged = ([int64]$prior.length -eq [int64]$file.Length) -and
                ([int64]$prior.lastWriteUtcTicks -eq [int64]$file.LastWriteTimeUtc.Ticks)
            if ($unchanged) { $passes = [int]$prior.unchangedPasses + 1 }
        }
        $ageSeconds = [Math]::Max(0, ($now.ToUniversalTime() - $file.LastWriteTimeUtc).TotalSeconds)
        $stable = $unchanged -and $passes -ge $StablePasses -and $ageSeconds -ge $StableAgeSeconds
        $cacheRows.Add([pscustomobject][ordered]@{
            path = $file.FullName
            length = [int64]$file.Length
            lastWriteUtcTicks = [int64]$file.LastWriteTimeUtc.Ticks
            unchangedPasses = $passes
        })
        try {
            $header = Get-BmpHeader $file.FullName
        }
        catch {
            $header = [ordered]@{ widthPx = 0; heightPx = 0; bitsPerPixel = 0; byteLength = [int64]$file.Length; headerState = 'BMP_HEADER_INVALID'; error = $_.Exception.Message }
        }
        $candidates.Add([pscustomobject][ordered]@{
            acquisitionKey = $acquisitionKey
            identity = $identity.identity
            lot = $identity.lot
            timestampToken = $identity.timestampToken
            timestampProvenance = $identity.timestampProvenance
            acquisitionVariant = $identity.acquisitionVariant
            slot = $identity.slot
            domain = $identity.domain
            identityParsed = [bool]$identity.parsed
            channel = $channel
            path = $file.FullName
            length = [int64]$file.Length
            lastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
            stable = $stable
            unchangedPasses = $passes
            header = $header
        })
    }

    $cacheArray = @($cacheRows | ForEach-Object { $_ })
    Write-AtomicJson -Path $script:CachePath -Value ([ordered]@{
        schema = 'argos_jbod_file_observation_cache_v1'
        updatedUtc = [DateTime]::UtcNow.ToString('o')
        rows = $cacheArray
    }) -Depth 8

    $acquisitions = New-Object Collections.Generic.List[object]
    foreach ($group in @($candidates | Group-Object acquisitionKey)) {
        $items = @($group.Group)
        $first = $items[0]
        $channels = [ordered]@{}
        foreach ($channelGroup in @($items | Group-Object channel)) {
            $best = @($channelGroup.Group | Sort-Object @{Expression={ [int64]$_.header.widthPx * [int64]$_.header.heightPx }; Descending=$true}, @{Expression='length';Descending=$true})[0]
            $channels[$channelGroup.Name] = $best
        }
        $allStable = @($channels.Values | Where-Object { -not $_.stable }).Count -eq 0
        $allHeadersValid = @($channels.Values | Where-Object { $_.header.headerState -ne 'BMP_HEADER_VALID' }).Count -eq 0
        $bf = if ($channels.Contains('BACKSIDE_BF')) { $channels['BACKSIDE_BF'] } else { $null }
        $df = if ($channels.Contains('BACKSIDE_DF')) { $channels['BACKSIDE_DF'] } else { $null }
        $frontBf = if ($channels.Contains('FRONTSIDE_BF')) { $channels['FRONTSIDE_BF'] } else { $null }
        $frontDf = if ($channels.Contains('FRONTSIDE_DF')) { $channels['FRONTSIDE_DF'] } else { $null }
        $hasBacksideChannels = $null -ne $bf -or $null -ne $df
        $dimensionMatch = $null -ne $bf -and $null -ne $df -and
            [int]$bf.header.widthPx -eq [int]$df.header.widthPx -and
            [int]$bf.header.heightPx -eq [int]$df.header.heightPx
        $largeNativeCandidate = $null -ne $bf -and [int]$bf.header.widthPx -ge 10000 -and [int]$bf.header.heightPx -ge 8000
        $frontDimensionMatch = $null -ne $frontBf -and $null -ne $frontDf -and
            [int]$frontBf.header.widthPx -eq [int]$frontDf.header.widthPx -and
            [int]$frontBf.header.heightPx -eq [int]$frontDf.header.heightPx
        $frontLargeNativeCandidate = $null -ne $frontBf -and
            [int]$frontBf.header.widthPx -ge 10000 -and [int]$frontBf.header.heightPx -ge 8000

        $metadataKey = Normalize-AcquisitionKey ([string]$first.identity)
        $metadata = if ($verifiedMetadata.ContainsKey($metadataKey)) { $verifiedMetadata[$metadataKey] } else { $null }
        $confirmedScribe = if ($confirmedScribes.ContainsKey($metadataKey)) { $confirmedScribes[$metadataKey] } else { $null }
        $confirmedScribeContractHold = if($script:ConfirmedScribeContractHolds.ContainsKey($metadataKey)){$script:ConfirmedScribeContractHolds[$metadataKey]}else{$null}
        $insiteHold = if($insiteHolds.ContainsKey($metadataKey)){$insiteHolds[$metadataKey]}else{$null}
        $scanTimeContextState = if ($null -ne $metadata -and
            $metadata.PSObject.Properties.Name -contains 'scanTimeContextState') {
            [string]$metadata.scanTimeContextState
        } else { '' }
        $scanTimeContextAuthority = if ($null -ne $metadata -and
            $metadata.PSObject.Properties.Name -contains 'scanTimeContextAuthority') {
            [string]$metadata.scanTimeContextAuthority
        } else { '' }
        $hasExactScanTimeContext = $null -ne $metadata -and
            $scanTimeContextState -eq 'EXACT_PRIOR_MOVEIN_FOUND' -and
            $scanTimeContextAuthority -eq 'LAST_INSITE_MOVEIN_PRECEDING_ARGOS_SCAN'
        $sourceDomainHint=[string]$first.domain
        $resolvedDomain=$sourceDomainHint
        $domainAuthority=if($sourceDomainHint-eq'FRONTSIDE'){'IMAGE_CHANNEL_FRONTSIDE'}else{'RECIPE_PATH_HINT_ONLY_NOT_DECISION_AUTHORITY'}
        $regimeState=if($null-eq$metadata){''}else{[string]$metadata.backsideRegimeState}
        $frontsideScratchTestRouteState=if($null-eq$metadata -or
            -not($metadata.PSObject.Properties.Name-contains'frontsideScratchTestRouteState')){''}else{[string]$metadata.frontsideScratchTestRouteState}
        if($hasBacksideChannels){
            # Recipe folder names are observational only.  Every backside pair
            # waits for confirmed-scribe Insite history, which is the sole
            # Bare/BowComp decision authority.
            if($null-eq$metadata){
                $resolvedDomain='BACKSIDE_PENDING_REGIME'
                $domainAuthority='CONFIRMED_SCRIBE_INSITE_REGIME_REQUIRED'
            }elseif(-not $hasExactScanTimeContext){
                $resolvedDomain='BACKSIDE_REGIME_HOLD'
                $domainAuthority='CONFIRMED_SCRIBE_EXACT_SCAN_TIME_CONTEXT_REQUIRED'
            }elseif($regimeState-eq'BACKSIDE_REGIME_BOWCOMP'){
                $resolvedDomain='BOWCOMP_BACKSIDE'
                $domainAuthority='CONFIRMED_SCRIBE_INSITE_EXACT_BOWCOMP_HISTORY'
            }elseif($regimeState-eq'BACKSIDE_REGIME_BARE'){
                $resolvedDomain='BARE_BACKSIDE'
                $domainAuthority='CONFIRMED_SCRIBE_INSITE_COMPLETE_HISTORY_NO_BOWCOMP_EVENT'
            }else{
                $resolvedDomain='BACKSIDE_REGIME_HOLD'
                $domainAuthority='CONFIRMED_SCRIBE_INSITE_REGIME_INCOMPLETE_OR_CONFLICT'
            }
        }

        if (-not [bool]$first.identityParsed) { $route = 'HOLD_IDENTITY_PARSE_FAILED' }
        elseif (-not $allHeadersValid) { $route = 'HOLD_INPUT_HEADER_INVALID' }
        elseif (-not $allStable) { $route = 'WAIT_INPUT_FILE_STABILITY' }
        elseif ($resolvedDomain -eq 'BOWCOMP_BACKSIDE' -and ($null -eq $bf -or $null -eq $df)) { $route = 'HOLD_BOWCOMP_BF_DF_PAIR_INCOMPLETE' }
        elseif ($resolvedDomain -eq 'BOWCOMP_BACKSIDE' -and -not $dimensionMatch) { $route = 'HOLD_BOWCOMP_BF_DF_DIMENSION_MISMATCH' }
        elseif ($resolvedDomain -eq 'BOWCOMP_BACKSIDE' -and -not $largeNativeCandidate) { $route = 'HOLD_NONCOMPLIANT_INPUT_RESOLUTION' }
        elseif ($resolvedDomain -eq 'BOWCOMP_BACKSIDE') { $route = 'READY_BOWCOMP_METHOD_QUALIFICATION' }
        elseif ($resolvedDomain -eq 'BARE_BACKSIDE' -and ($null -eq $bf -or $null -eq $df)) { $route = 'HOLD_BARE_BF_DF_PAIR_INCOMPLETE' }
        elseif ($resolvedDomain -eq 'BARE_BACKSIDE' -and -not $dimensionMatch) { $route = 'HOLD_BARE_BF_DF_DIMENSION_MISMATCH' }
        elseif ($resolvedDomain -eq 'BARE_BACKSIDE' -and -not $largeNativeCandidate) { $route = 'HOLD_NONCOMPLIANT_INPUT_RESOLUTION' }
        elseif ($resolvedDomain -eq 'BARE_BACKSIDE') { $route = 'READY_BARE_REVIEW_ONLY_PROCESSING' }
        elseif ($resolvedDomain -eq 'FRONTSIDE' -and ($null -eq $frontBf -or $null -eq $frontDf)) { $route = 'HOLD_FRONTSIDE_BF_DF_PAIR_INCOMPLETE' }
        elseif ($resolvedDomain -eq 'FRONTSIDE' -and -not $frontDimensionMatch) { $route = 'HOLD_FRONTSIDE_BF_DF_DIMENSION_MISMATCH' }
        elseif ($resolvedDomain -eq 'FRONTSIDE' -and -not $frontLargeNativeCandidate) { $route = 'HOLD_NONCOMPLIANT_INPUT_RESOLUTION' }
        elseif ($resolvedDomain -eq 'FRONTSIDE' -and $null -eq $metadata) { $route = 'HOLD_INSITE_METADATA_REQUIRED_BEFORE_FRONTSIDE_DETECTOR' }
        elseif ($resolvedDomain -eq 'FRONTSIDE' -and $frontsideScratchTestRouteState -eq 'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED') { $route = 'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING' }
        elseif ($resolvedDomain -eq 'FRONTSIDE') { $route = 'HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED' }
        elseif ($resolvedDomain -eq 'BACKSIDE_REGIME_HOLD') { $route = 'HOLD_INSITE_BACKSIDE_REGIME_INCOMPLETE_OR_CONFLICT' }
        else { $route = 'HOLD_DOMAIN_UNQUALIFIED' }

        $stamp = Convert-TimestampToken ([string]$first.timestampToken)
        $channelRecords = [ordered]@{}
        foreach ($key in $channels.Keys) {
            $item = $channels[$key]
            $channelRecords[$key] = [ordered]@{
                path = $item.path
                bytes = [int64]$item.length
                lastWriteUtc = $item.lastWriteUtc
                stable = [bool]$item.stable
                unchangedPasses = [int]$item.unchangedPasses
                widthPx = [int]$item.header.widthPx
                heightPx = [int]$item.header.heightPx
                bitsPerPixel = [int]$item.header.bitsPerPixel
                headerState = [string]$item.header.headerState
                sha256State = 'DEFERRED_UNTIL_DETECTOR_ADMISSION'
            }
        }
        $waferId = if ($null -ne $metadata) { [string]$metadata.waferId } elseif($null-ne$confirmedScribe){[string]$confirmedScribe.waferId}elseif($null-ne$insiteHold){[string]$insiteHold.scribe}else{''}
        $product = if ($null -eq $metadata) { '' } else { [string]$metadata.product }
        $processBlock = if ($null -eq $metadata) { '' } else { [string]$metadata.processBlock }
        $step = if ($null -eq $metadata) { '' } else { [string]$metadata.step }
        $tool = if ($null -eq $metadata) { '' } else { [string]$metadata.tool }
        $metadataState = if ($null-ne$metadata) { 'SCRIBE_CONFIRMED_MES_SNAPSHOT' } elseif($null-ne$insiteHold){[string]$insiteHold.state}elseif($null-ne$confirmedScribe){'SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'}elseif($null-ne$confirmedScribeContractHold){'HOLD_CONFIRMED_SCRIBE_CONTRACT_INVALID'}else{'SCRIBE_IDENTITY_CONFIRMATION_HOLD'}
        $identityState = if ($null-ne$metadata) { [string]$metadata.identityState } elseif($null-ne$confirmedScribe){[string]$confirmedScribe.identityState}elseif($null-ne$confirmedScribeContractHold){'HOLD_CONFIRMED_SCRIBE_CONTRACT_INVALID'}else{'SCRIBE_IDENTITY_CONFIRMATION_HOLD'}
        # Raw folder identity is sufficient to queue the image-first scribe
        # reader, but step-dependent detector admission requires the confirmed
        # 12-character scribe and its exact read-only Insite visual-state row.
        if (($hasBacksideChannels -or $resolvedDomain -eq 'FRONTSIDE') -and
            $null -ne $metadata -and -not $hasExactScanTimeContext) {
            $route = 'HOLD_EXACT_SCAN_TIME_INSITE_CONTEXT_REQUIRED_BEFORE_DETECTOR'
        }
        elseif (($hasBacksideChannels -or $resolvedDomain -eq 'FRONTSIDE') -and $null -eq $metadata) {
            $route = if($null-ne$confirmedScribeContractHold){
                'HOLD_CONFIRMED_SCRIBE_CONTRACT_INVALID'
            }elseif($null-ne$insiteHold){
                [string]$insiteHold.state
            }elseif ($null -ne $confirmedScribe) {
                'HOLD_INSITE_METADATA_REQUIRED_BEFORE_DETECTOR'
            } else {
                'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'
            }
        }
        $acquisitions.Add([pscustomobject][ordered]@{
            identity = ([string]$first.identity)+'__'+$resolvedDomain
            physicalIdentity = [string]$first.identity
            lot = [string]$first.lot
            scanTimestampLocal = if ($null -eq $stamp) { '' } else { $stamp.ToString('yyyy-MM-ddTHH:mm:ss') }
            scanDateLocal = if ($null -eq $stamp) { '' } else { $stamp.ToString('yyyy-MM-dd') }
            timestampProvenance = [string]$first.timestampProvenance
            slot = [string]$first.slot
            acquisitionVariant = [string]$first.acquisitionVariant
            domain = $resolvedDomain
            sourceDomainHint = $sourceDomainHint
            domainAuthority = $domainAuthority
            backsideRegimeState = $regimeState
            frontsideScratchTestRouteState = $frontsideScratchTestRouteState
            frontsideScratchTestRouteAuthority = if($null-eq$metadata -or -not($metadata.PSObject.Properties.Name-contains'frontsideScratchTestRouteAuthority')){''}else{[string]$metadata.frontsideScratchTestRouteAuthority}
            frontsideScratchTestFingerprintVersion = if($null-eq$metadata -or -not($metadata.PSObject.Properties.Name-contains'frontsideScratchTestFingerprintVersion')){''}else{[string]$metadata.frontsideScratchTestFingerprintVersion}
            frontsideScratchTestRoute = if($null-eq$metadata -or -not($metadata.PSObject.Properties.Name-contains'frontsideScratchTestRoute')){$null}else{$metadata.frontsideScratchTestRoute}
            waferId = $waferId
            scribe = $waferId
            identityState = $identityState
            scribeChecksumState = if ($null-ne$metadata) { [string]$metadata.scribeChecksumState } elseif($null-ne$confirmedScribe){[string]$confirmedScribe.scribeChecksumState}else{'NOT_CONFIRMED'}
            metadataLookupAuthority = 'CONFIRMED_12_CHARACTER_SCRIBE_ONLY'
            product = $product
            productName = if ($null -eq $metadata) { '' } else { [string]$metadata.productName }
            productRevision = if ($null -eq $metadata) { '' } else { [string]$metadata.productRevision }
            processBlock = $processBlock
            processBlockWorkflow = if ($null -eq $metadata) { '' } else { [string]$metadata.processBlockWorkflow }
            step = $step
            operation = if ($null -eq $metadata) { '' } else { [string]$metadata.operation }
            tool = $tool
            visualStateKey = if ($null -eq $metadata) { '' } else { [string]$metadata.visualStateKey }
            mesIssuedWaferContainer = if ($null -eq $metadata) { '' } else { [string]$metadata.issuedWaferContainer }
            mesQueryState = if ($null-ne$metadata) { [string]$metadata.mesQueryState } elseif($null-ne$insiteHold){if([bool]$insiteHold.terminal){'INSITE_HOLD_TERMINAL'}else{'INSITE_HOLD_RETRY_SCHEDULED'}}elseif($null-ne$confirmedScribe){'INSITE_LOOKUP_PENDING'}else{'NOT_QUERIED_UNCONFIRMED_SCRIBE'}
            metadataState = $metadataState
            insiteHoldAttemptCount = if($null-ne$insiteHold){[int]$insiteHold.attemptCount}else{0}
            insiteHoldTerminal = if($null-ne$insiteHold){[bool]$insiteHold.terminal}else{$false}
            insiteHoldNextRetryUtc = if($null-ne$insiteHold){[string]$insiteHold.nextRetryUtc}else{''}
            scanTimeContextState = $scanTimeContextState
            scanTimeContextAuthority = $scanTimeContextAuthority
            routeState = $route
            detectorExecutionState = 'NOT_STARTED_ROUTE_ONLY'
            xmlExportState = 'DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY'
            channels = $channelRecords
        })
    }

    $orderedAcquisitions = @($acquisitions | ForEach-Object { $_ } | Sort-Object `
        @{ Expression = 'scanTimestampLocal'; Descending = $true },
        @{ Expression = 'lot'; Descending = $false },
        @{ Expression = 'slot'; Descending = $false })
    $counts = [ordered]@{
        bmpFilesRecognized = [int]$candidates.Count
        acquisitions = [int]$orderedAcquisitions.Count
        stable = [int]@($orderedAcquisitions | Where-Object { $_.routeState -notlike 'WAIT_*' }).Count
        waiting = [int]@($orderedAcquisitions | Where-Object { $_.routeState -like 'WAIT_*' }).Count
        routeReady = [int]@($orderedAcquisitions | Where-Object { $_.routeState -like 'READY_*' }).Count
        held = [int]@($orderedAcquisitions | Where-Object { $_.routeState -like 'HOLD_*' }).Count
        bowComp = [int]@($orderedAcquisitions | Where-Object { $_.domain -eq 'BOWCOMP_BACKSIDE' }).Count
        bare = [int]@($orderedAcquisitions | Where-Object { $_.domain -eq 'BARE_BACKSIDE' }).Count
        frontside = [int]@($orderedAcquisitions | Where-Object { $_.domain -eq 'FRONTSIDE' }).Count
        backsidePendingRegime = [int]@($orderedAcquisitions | Where-Object { $_.domain -eq 'BACKSIDE_PENDING_REGIME' }).Count
        backsideRegimeHold = [int]@($orderedAcquisitions | Where-Object { $_.domain -eq 'BACKSIDE_REGIME_HOLD' }).Count
        recipePathHintsUnqualified = [int]@($orderedAcquisitions | Where-Object { $_.sourceDomainHint -eq 'UNKNOWN' }).Count
        unknownDomain = [int]@($orderedAcquisitions | Where-Object { $_.domain -in @('BACKSIDE_PENDING_REGIME','BACKSIDE_REGIME_HOLD','UNKNOWN') }).Count
    }
    $catalog = [ordered]@{
        schema = 'argos_jbod_all_wafer_catalog_v1'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        rawSearchRoot = [IO.Path]::GetFullPath($RawSearchRoot)
        reviewOnly = $true
        trainingEligible = $false
        productionEligible = $false
        xmlExportEnabled = $false
        xmlExportState = 'DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY'
        scanMethod = 'FILENAME_METADATA_AND_54_BYTE_BMP_HEADER_ONLY'
        imagePixelsLoaded = $false
        imageBytesEmbedded = $false
        detectorExecution = 'ROUTE_ONLY_NO_DETECTOR_EXECUTION'
        filterableFields = @('scanDateLocal','lot','scanTimestampLocal','slot','domain','step','tool','product','waferId','routeState')
        counts = $counts
        acquisitions = $orderedAcquisitions
    }
    Write-AtomicJson -Path $script:CatalogPath -Value $catalog -Depth 14
    $csvRows = foreach ($row in $orderedAcquisitions) {
        [pscustomobject]@{
            identity = $row.identity; scanDateLocal = $row.scanDateLocal; lot = $row.lot
            scanTimestampLocal = $row.scanTimestampLocal; slot = $row.slot; domain = $row.domain
            step = $row.step; tool = $row.tool; product = $row.product; waferId = $row.waferId
            identityState = $row.identityState; metadataLookupAuthority = $row.metadataLookupAuthority
            metadataState = $row.metadataState; routeState = $row.routeState
            detectorExecutionState = $row.detectorExecutionState; xmlExportState = $row.xmlExportState
        }
    }
    $csvText = ($csvRows | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
    Write-AtomicUtf8Text -Path $script:CatalogCsvPath -Value ($csvText + [Environment]::NewLine)
    $fingerprintRows = foreach ($row in $orderedAcquisitions) {
        $channelText = foreach ($key in $row.channels.Keys) {
            $value = $row.channels[$key]
            "$key|$($value.path)|$($value.bytes)|$($value.lastWriteUtc)|$($value.stable)|$($value.widthPx)x$($value.heightPx)"
        }
        "$($row.identity)|$($row.domain)|$($row.routeState)|$($channelText -join ';')"
    }
    $fingerprint = Get-Sha256Text ($fingerprintRows -join "`n")
    $relayState = Queue-RelayCatalogSummary -Catalog $catalog -Fingerprint $fingerprint
    $counts['relayState'] = $relayState
    New-Status -State 'WATCHING' -Detail 'Catalog pass complete; background watcher remains active.' -Counts $counts
    [pscustomobject]@{
        State = 'PASS_ALL_WAFER_CATALOG_REVIEW_ONLY'
        Acquisitions = $counts.acquisitions
        RouteReady = $counts.routeReady
        Waiting = $counts.waiting
        Held = $counts.held
        RelayState = $relayState
        CatalogPath = $script:CatalogPath
        StatusPath = $script:StatusPath
    }
}
catch {
    try { New-Status -State 'FAILED' -Detail $_.Exception.Message -Counts @{} } catch {}
    throw
}
