param([string]$Serial = '369cd024', [string]$OutputDirectory = '.')
$ErrorActionPreference = 'Stop'
$adb = (Get-Command adb.exe -ErrorAction Stop).Source
$state = & $adb -s $Serial get-state 2>&1
if ($LASTEXITCODE -ne 0 -or "$state".Trim() -ne 'device') {
    throw "Device $Serial is not connected/authorized: $state"
}
$destination = Join-Path $OutputDirectory ('camera-audio-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $destination -ErrorAction Stop | Out-Null
function Save-AdbOutput([string]$Name, [string[]]$Arguments) {
    if ($Arguments.Count -gt 1 -and $Arguments[0] -eq 'shell') {
        $Arguments = @('shell', 'timeout', '20') + $Arguments[1..($Arguments.Count - 1)]
    }
    $result = & $adb -s $Serial @Arguments 2>&1
    $code = $LASTEXITCODE
    $result | Set-Content -LiteralPath (Join-Path $destination $Name) -Encoding UTF8
    if ($code -ne 0) { Write-Warning "$Name failed (exit $code); saved diagnostic output" }
}
# Read-only snapshot: preserve existing log buffers and current routing/volume.
Save-AdbOutput 'logcat-all.txt' @('logcat', '-b', 'all', '-d', '-v', 'threadtime')
Save-AdbOutput 'audio-policy.txt' @('shell', 'dumpsys', 'media.audio_policy')
Save-AdbOutput 'audio-flinger.txt' @('shell', 'dumpsys', 'media.audio_flinger')
Save-AdbOutput 'audio-service.txt' @('shell', 'dumpsys', 'audio')
Save-AdbOutput 'camera-service.txt' @('shell', 'dumpsys', 'media.camera')
Save-AdbOutput 'services.txt' @('shell', 'service', 'list')
Save-AdbOutput 'hal-services.txt' @('shell', 'lshal')
Save-AdbOutput 'properties.txt' @('shell', 'getprop')
Save-AdbOutput 'processes.txt' @('shell', 'ps', '-A')
Save-AdbOutput 'kernel.txt' @('shell', 'dmesg')
Save-AdbOutput 'alsa-cards.txt' @('shell', 'cat', '/proc/asound/cards')
Save-AdbOutput 'alsa-pcm.txt' @('shell', 'cat', '/proc/asound/pcm')
Save-AdbOutput 'mixer.txt' @('shell', 'tinymix')
Select-String -LiteralPath (Join-Path $destination 'logcat-all.txt') -Pattern 'audio|audioserver|AudioFlinger|AudioPolicy|PAL|AGM|ASoC|alsa|sound|speaker|avc: denied|linker' |
    ForEach-Object { $_.Line } | Set-Content -LiteralPath (Join-Path $destination 'audio-filtered.txt') -Encoding UTF8
Write-Output "Saved logs to $destination"
