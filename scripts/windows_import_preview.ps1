param(
    [Parameter(Mandatory = $true)]
    [string]$JsonPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $JsonPath)) {
    throw "JSON file not found: $JsonPath"
}

$raw = Get-Content -Path $JsonPath -Raw
$data = $raw | ConvertFrom-Json

$subjects = @($data.subjects)
$alarms = @($data.alarms)
$sleepPlans = @($data.sleepRecommendations)
$sleepLogs = @($data.sleepExecutionLogs)

$sessions = @()
foreach ($subject in $subjects) {
    foreach ($session in @($subject.sessions)) {
        $sessions += [pscustomobject]@{
            Subject = [string]$subject.code
            Day = [int]$session.dayOfWeek
            Start = [int]$session.startMinutes
            End = [int]$session.endMinutes
        }
    }
}

$blocks = @()
foreach ($plan in $sleepPlans) {
    foreach ($block in @($plan.blocks)) {
        $blocks += [pscustomobject]@{
            DayType = [string]$plan.dayType
            Start = [datetime]$block.startAt
            End = [datetime]$block.endAt
            Strategy = [string]$block.strategyLabel
        }
    }
}

Write-Output "--- Import Preview ---"
Write-Output ("Settings section: {0}" -f ($(if ($null -ne $data.settings) { 'Present' } else { 'Missing' })))
Write-Output ("Subjects: {0}" -f $subjects.Count)
Write-Output ("Sessions: {0}" -f $sessions.Count)
Write-Output ("Alarms: {0}" -f $alarms.Count)
Write-Output ("Sleep recommendations: {0}" -f $sleepPlans.Count)
Write-Output ("Sleep logs: {0}" -f $sleepLogs.Count)
Write-Output ("Sleep blocks: {0}" -f $blocks.Count)

$sessionOverlapCount = 0
$sessionGroups = $sessions | Group-Object Day
foreach ($group in $sessionGroups) {
    $sorted = $group.Group | Sort-Object Start
    for ($i = 0; $i -lt $sorted.Count - 1; $i++) {
        $current = $sorted[$i]
        $next = $sorted[$i + 1]
        if ($next.Start -lt $current.End) {
            $sessionOverlapCount++
        }
    }
}

$blockOverlapCount = 0
$sortedBlocks = $blocks | Sort-Object Start
for ($i = 0; $i -lt $sortedBlocks.Count - 1; $i++) {
    $current = $sortedBlocks[$i]
    $next = $sortedBlocks[$i + 1]
    if ($next.Start -lt $current.End) {
        $blockOverlapCount++
    }
}

if ($sessionOverlapCount -gt 0) {
    Write-Output ("WARNING: Timetable has {0} overlapping session pair(s)." -f $sessionOverlapCount)
}
if ($blockOverlapCount -gt 0) {
    Write-Output ("WARNING: Sleep plan has {0} overlapping block pair(s)." -f $blockOverlapCount)
}
if ($sessionOverlapCount -eq 0 -and $blockOverlapCount -eq 0) {
    Write-Output "No overlap warnings in incoming backup."
}

$blocks | Select-Object -First 5 | ForEach-Object {
    Write-Output ("Block: {0} {1:HH:mm}-{2:HH:mm} ({3})" -f $_.DayType, $_.Start, $_.End, $_.Strategy)
}
