param([ValidateSet('enabled','disabled')][string]$Expected = 'enabled')
$ErrorActionPreference = 'Stop'
$state = adb shell dumpsys wifi
$actual = ($state | Select-String '^Wi-Fi is (enabled|disabled)$').Line.Trim()
$setting = (adb shell settings get global wifi_on).Trim()
if ($actual -ne "Wi-Fi is $Expected") {
    throw "Wi-Fi boot state: expected=$Expected actual=$actual persisted=$setting"
}
if ($Expected -eq 'enabled' -and ($state | Select-String 'what=CMD_STA_START_FAILURE')) {
    throw 'Wi-Fi failed to start during this boot'
}
Write-Output "PASS: $actual persisted=$setting"
