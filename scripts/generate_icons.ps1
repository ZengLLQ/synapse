Add-Type -AssemblyName System.Drawing

$outputIcon = "f:\Synapse\desktop\app-icon.png"
$iconsDir = "f:\Synapse\desktop\src-tauri\icons"

if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null
}

$bmp = New-Object System.Drawing.Bitmap 1024, 1024
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$rect = New-Object System.Drawing.Rectangle 0, 0, 1024, 1024
$rectF = New-Object System.Drawing.RectangleF 0, 0, 1024, 1024
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255, 30, 58, 138), [System.Drawing.Color]::FromArgb(255, 79, 70, 229), 45.0)
$g.FillRectangle($brush, $rect)

$font = New-Object System.Drawing.Font('Segoe UI', 460, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.DrawString('S', $font, $whiteBrush, $rectF, $sf)

$brush.Dispose()
$whiteBrush.Dispose()
$font.Dispose()
$g.Dispose()

$bmp.Save($outputIcon, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Generated $outputIcon successfully."
