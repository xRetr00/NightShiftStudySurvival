$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

$soundsDir = 'NightShiftStudySurvival/Resources/Sounds'
$appIconDir = 'NightShiftStudySurvival/Resources/Assets.xcassets/AppIcon.appiconset'
$logoDir = 'NightShiftStudySurvival/Resources/Assets.xcassets/Logo.imageset'
$accentDir = 'NightShiftStudySurvival/Resources/Assets.xcassets/AccentColor.colorset'

New-Item -ItemType Directory -Force -Path $soundsDir | Out-Null
New-Item -ItemType Directory -Force -Path $appIconDir | Out-Null
New-Item -ItemType Directory -Force -Path $logoDir | Out-Null
New-Item -ItemType Directory -Force -Path $accentDir | Out-Null

function New-WavSine {
    param(
        [string]$Path,
        [double]$Freq,
        [double]$Duration = 1.2,
        [double]$Amplitude = 0.45,
        [int]$SampleRate = 44100
    )

    $samples = [int]($Duration * $SampleRate)
    $channels = 1
    $bitsPerSample = 16
    $blockAlign = [int]($channels * ($bitsPerSample / 8))
    $byteRate = [int]($SampleRate * $blockAlign)
    $dataSize = [int]($samples * $blockAlign)

    $stream = [System.IO.File]::Create($Path)
    $writer = New-Object System.IO.BinaryWriter($stream)

    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $dataSize))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]$channels)
        $writer.Write([int]$SampleRate)
        $writer.Write([int]$byteRate)
        $writer.Write([int16]$blockAlign)
        $writer.Write([int16]$bitsPerSample)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]$dataSize)

        for ($n = 0; $n -lt $samples; $n++) {
            $t = $n / $SampleRate
            $sampleValue = [math]::Sin(2 * [math]::PI * $Freq * $t) * $Amplitude
            $pcm = [int16][math]::Round($sampleValue * 32767)
            $writer.Write($pcm)
        }
    }
    finally {
        $writer.Close()
        $stream.Close()
    }
}

$styleBase = @{
    default = 620
    siren = 900
    industrial = 440
}

$profileMultiplier = @{
    gentleloop = 0.8
    standardloop = 1.0
    loudfastloop = 1.2
    aggressivealternating = 1.35
    emergencymax = 1.5
    mathlockurgent = 1.4
    silent = 1.0
}

foreach ($style in $styleBase.Keys) {
    foreach ($profile in $profileMultiplier.Keys) {
        $freq = $styleBase[$style] * $profileMultiplier[$profile]
        $amp = if ($profile -eq 'silent') { 0.015 } else { 0.45 }
        $file = Join-Path $soundsDir ("alarm_{0}_{1}.wav" -f $style, $profile)
        New-WavSine -Path $file -Freq $freq -Amplitude $amp
    }
}

Add-Type -AssemblyName System.Drawing

function New-BrandImage {
    param(
        [string]$Path,
        [int]$Size
    )

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)

    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $rect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
        $c1 = [System.Drawing.Color]::FromArgb(255, 8, 23, 53)
        $c2 = [System.Drawing.Color]::FromArgb(255, 20, 78, 108)
        $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 45)
        $g.FillRectangle($bg, $rect)
        $bg.Dispose()

        $moonBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 246, 229, 141))
        $moonRect = New-Object System.Drawing.RectangleF(($Size * 0.58), ($Size * 0.14), ($Size * 0.24), ($Size * 0.24))
        $g.FillEllipse($moonBrush, $moonRect)
        $moonBrush.Dispose()

        $cutBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 20, 78, 108))
        $cutRect = New-Object System.Drawing.RectangleF(($Size * 0.64), ($Size * 0.12), ($Size * 0.22), ($Size * 0.22))
        $g.FillEllipse($cutBrush, $cutRect)
        $cutBrush.Dispose()

        $fontSize = [float]($Size * 0.35)
        $font = New-Object System.Drawing.Font('Segoe UI Semibold', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 243, 244, 246))
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $textRect = New-Object System.Drawing.RectangleF(0, ($Size * 0.37), $Size, ($Size * 0.48))
        $g.DrawString('NS', $font, $textBrush, $textRect, $format)

        $font.Dispose()
        $textBrush.Dispose()
        $format.Dispose()

        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}

$icons = @{
    'icon-20@2x.png' = 40
    'icon-20@3x.png' = 60
    'icon-29@2x.png' = 58
    'icon-29@3x.png' = 87
    'icon-40@2x.png' = 80
    'icon-40@3x.png' = 120
    'icon-60@2x.png' = 120
    'icon-60@3x.png' = 180
    'icon-20~ipad.png' = 20
    'icon-20@2x~ipad.png' = 40
    'icon-29~ipad.png' = 29
    'icon-29@2x~ipad.png' = 58
    'icon-40~ipad.png' = 40
    'icon-40@2x~ipad.png' = 80
    'icon-76~ipad.png' = 76
    'icon-76@2x~ipad.png' = 152
    'icon-83.5@2x~ipad.png' = 167
    'icon-1024.png' = 1024
}

foreach ($entry in $icons.GetEnumerator()) {
    $out = Join-Path $appIconDir $entry.Key
    New-BrandImage -Path $out -Size $entry.Value
}

New-BrandImage -Path (Join-Path $logoDir 'logo-512.png') -Size 512
New-BrandImage -Path (Join-Path $logoDir 'logo-1024.png') -Size 1024

Write-Output 'Assets generated.'
