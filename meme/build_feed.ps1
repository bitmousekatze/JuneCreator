Add-Type -AssemblyName System.Drawing

$dir = "C:\Users\joeld\Documents\GitHub\JuneCreator\meme"
$posts = Get-Content "$dir\posts.json" -Raw | ConvertFrom-Json

# layout constants
$W       = 1920          # canvas width
$cardW   = 1700
$cardX   = [int](($W - $cardW) / 2)
$pad     = 36
$innerW  = $cardW - 2*$pad
$imgMaxH = 720
$gap     = 50

$bgColor     = [System.Drawing.Color]::FromArgb(13,13,18)
$cardColor   = [System.Drawing.Color]::FromArgb(23,23,31)
$borderColor = [System.Drawing.Color]::FromArgb(42,42,53)
$userColor   = [System.Drawing.Color]::FromArgb(167,139,250)
$titleColor  = [System.Drawing.Color]::FromArgb(240,240,245)
$likeColor   = [System.Drawing.Color]::FromArgb(244,93,105)

$userFont  = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
$titleFont = New-Object System.Drawing.Font("Segoe UI", 32, [System.Drawing.FontStyle]::Bold)
$likeFont  = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)

# measuring pass
$measureBmp = New-Object System.Drawing.Bitmap(10,10)
$mg = [System.Drawing.Graphics]::FromImage($measureBmp)

$cards = @()
$totalH = $gap
foreach($p in $posts){
  $img = [System.Drawing.Image]::FromFile("$dir\posts\$($p.file)")
  $scale = [Math]::Min($innerW / $img.Width, $imgMaxH / $img.Height)
  $imgW = [int]($img.Width * $scale); $imgH = [int]($img.Height * $scale)
  $titleSize = $mg.MeasureString($p.title, $titleFont, $innerW)
  $titleH = [int][Math]::Ceiling($titleSize.Height)
  $cardH = $pad + 44 + 12 + $titleH + 20 + $imgH + 20 + 40 + $pad
  $cards += [pscustomobject]@{ p=$p; img=$img; imgW=$imgW; imgH=$imgH; titleH=$titleH; cardH=$cardH; y=$totalH }
  $totalH += $cardH + $gap
}
$mg.Dispose(); $measureBmp.Dispose()

Write-Output "Feed canvas: ${W}x${totalH}"

$bmp = New-Object System.Drawing.Bitmap($W, $totalH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear($bgColor)

$cardBrush   = New-Object System.Drawing.SolidBrush($cardColor)
$borderPen   = New-Object System.Drawing.Pen($borderColor, 2)
$userBrush   = New-Object System.Drawing.SolidBrush($userColor)
$titleBrush  = New-Object System.Drawing.SolidBrush($titleColor)
$likeBrush   = New-Object System.Drawing.SolidBrush($likeColor)

foreach($c in $cards){
  $y = $c.y
  $g.FillRectangle($cardBrush, $cardX, $y, $cardW, $c.cardH)
  $g.DrawRectangle($borderPen, $cardX, $y, $cardW, $c.cardH)
  $cy = $y + $pad
  $g.DrawString("@$($c.p.username)", $userFont, $userBrush, $cardX + $pad, $cy)
  $cy += 44 + 12
  $titleRect = New-Object System.Drawing.RectangleF(($cardX + $pad), $cy, $innerW, ($c.titleH + 4))
  $g.DrawString($c.p.title, $titleFont, $titleBrush, $titleRect)
  $cy += $c.titleH + 20
  $imgX = $cardX + $pad + [int](($innerW - $c.imgW) / 2)
  $g.DrawImage($c.img, $imgX, $cy, $c.imgW, $c.imgH)
  $cy += $c.imgH + 20
  $g.DrawString([string][char]0x2665 + " $($c.p.likes)", $likeFont, $likeBrush, $cardX + $pad, $cy)
  $c.img.Dispose()
}

$g.Dispose()
$bmp.Save("$dir\feed.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "Saved feed.png"
