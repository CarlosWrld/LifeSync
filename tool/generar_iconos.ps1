# Genera los recursos nativos sin dependencias ni cambios al logo original.
# Ejecutar desde Windows: powershell -File tool/generar_iconos.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourcePath = Join-Path $projectRoot 'assets/branding/logo_original.png'
$sourceImage = [System.Drawing.Bitmap]::FromFile($sourcePath)
$background = $sourceImage.GetPixel(0, 0)

function Export-LauncherIcon {
    param([string]$RelativePath, [int]$Size, [double]$ContentScale = 1.0)

    $destination = Join-Path $projectRoot $RelativePath
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($destination)) | Out-Null
    # RGB opaco, requerido por el icono de App Store.
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    try {
        $graphics.Clear($background)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $ratio = $Size * $ContentScale / [Math]::Max($sourceImage.Width, $sourceImage.Height)
        $width = [int][Math]::Round($sourceImage.Width * $ratio)
        $height = [int][Math]::Round($sourceImage.Height * $ratio)
        $rect = [System.Drawing.Rectangle]::new(
            [int][Math]::Floor(($Size - $width) / 2),
            [int][Math]::Floor(($Size - $height) / 2), $width, $height)
        $graphics.DrawImage($sourceImage, $rect, 0, 0, $sourceImage.Width, $sourceImage.Height,
            [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $attributes.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    Export-LauncherIcon 'assets/branding/icono_app.png' 1024
    $densities = @(
        @{ Name = 'mdpi'; Legacy = 48; Adaptive = 108 },
        @{ Name = 'hdpi'; Legacy = 72; Adaptive = 162 },
        @{ Name = 'xhdpi'; Legacy = 96; Adaptive = 216 },
        @{ Name = 'xxhdpi'; Legacy = 144; Adaptive = 324 },
        @{ Name = 'xxxhdpi'; Legacy = 192; Adaptive = 432 }
    )
    foreach ($density in $densities) {
        $folder = 'android/app/src/main/res/mipmap-' + $density.Name
        Export-LauncherIcon ($folder + '/ic_launcher.png') $density.Legacy
        # Margen para las mascaras del launcher, conservando las proporciones.
        Export-LauncherIcon ($folder + '/ic_launcher_foreground.png') $density.Adaptive 0.70
    }

    $catalogPath = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images | Sort-Object filename -Unique) {
        $points = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [int]($entry.scale -replace 'x', '')
        Export-LauncherIcon ('ios/Runner/Assets.xcassets/AppIcon.appiconset/' + $entry.filename) ([int]($points * $scale))
    }
    $colorsPath = Join-Path $projectRoot 'android/app/src/main/res/values/ic_launcher_colors.xml'
    $color = '#{0:X2}{1:X2}{2:X2}' -f $background.R, $background.G, $background.B
    $xml = '<resources><color name="ic_launcher_background">' + $color + '</color></resources>'
    [System.IO.File]::WriteAllText($colorsPath, $xml + [Environment]::NewLine)
    Write-Output 'Iconos Android e iOS generados. Original conservado en assets/branding/logo_original.png.'
}
finally {
    $sourceImage.Dispose()
}
