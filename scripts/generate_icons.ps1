Add-Type -AssemblyName System.Drawing

$iconsDir = "f:\Synapse\desktop\src-tauri\icons"
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null
}

$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255, 37, 99, 235))
$font = New-Object System.Drawing.Font('Arial', 16, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.DrawString('S', $font, $brush, 6, 4)
$g.Dispose()

$bmp.Save("$iconsDir\32x32.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save("$iconsDir\128x128.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save("$iconsDir\icon.png", [System.Drawing.Imaging.ImageFormat]::Png)

$hIcon = $bmp.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hIcon)
$fs = [System.IO.File]::OpenWrite("$iconsDir\icon.ico")
$icon.Save($fs)
$fs.Close()
$icon.Dispose()
$bmp.Dispose()
Write-Host "Icons generated successfully in $iconsDir"
