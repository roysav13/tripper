# Generates the PWA / home-screen icon set in web/icons from the app's own
# palette and display face, so an installed Tripper doesn't sit on the home
# screen wearing the stock Flutter logo.
#
# Run from the repo root:  powershell -File tool/generate_web_icons.ps1
#
# Colours are AppColors.dark.accent (coral) and .inkPrimary (cream) — kept
# in sync by hand, since a .ps1 can't read the Dart theme. The glyph sits
# inside the middle 60% so the same art works as a `maskable` icon, where
# Android may crop to a circle.

Add-Type -AssemblyName System.Drawing

$accent = [System.Drawing.ColorTranslator]::FromHtml('#FF6B5E')
$ink    = [System.Drawing.ColorTranslator]::FromHtml('#F5F1EA')

$fontPath = Join-Path $PSScriptRoot '..\assets\fonts\Fraunces-SemiBold.ttf'
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Resolve-Path $fontPath))
$family = $fonts.Families[0]

$outDir = Join-Path $PSScriptRoot '..\web\icons'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-Icon([int]$size, [string]$path, [double]$glyphScale) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $g.Clear($accent)

    $font = New-Object System.Drawing.Font($family, [float]($size * $glyphScale), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush($ink)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
    $g.DrawString('T', $font, $brush, $rect, $format)

    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "wrote $path"
}

New-Icon 192 (Join-Path $outDir 'Icon-192.png') 0.62
New-Icon 512 (Join-Path $outDir 'Icon-512.png') 0.62
# Maskable art keeps the glyph well inside the safe zone.
New-Icon 192 (Join-Path $outDir 'Icon-maskable-192.png') 0.44
New-Icon 512 (Join-Path $outDir 'Icon-maskable-512.png') 0.44
New-Icon 180 (Join-Path $outDir 'apple-touch-icon-180.png') 0.62
New-Icon 32  (Join-Path $PSScriptRoot '..\web\favicon.png') 0.66
