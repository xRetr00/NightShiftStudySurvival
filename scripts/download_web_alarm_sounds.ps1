$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetDir = Join-Path $repoRoot 'NightShiftStudySurvival/Resources/Sounds'
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

$downloads = @(
    @{
        Name = 'web_disaster.mp3'
        Url = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'
    },
    @{
        Name = 'web_nuclear.mp3'
        Url = 'https://assets.mixkit.co/active_storage/sfx/2935/2935-preview.mp3'
    },
    @{
        Name = 'web_red_alert.mp3'
        Url = 'https://assets.mixkit.co/active_storage/sfx/2899/2899-preview.mp3'
    }
)

foreach ($item in $downloads) {
    $outFile = Join-Path $targetDir $item.Name
    Invoke-WebRequest -Uri $item.Url -OutFile $outFile -MaximumRedirection 5 -TimeoutSec 60
    Write-Output "Downloaded: $($item.Name)"
}

Write-Output "Web alarm sounds downloaded into $targetDir"
