Add-Type -AssemblyName System.Drawing

$src = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CardComposite {
  public static int Process(string inDir, string outDir, string adPath) {
    var files = Directory.GetFiles(inDir, "*.png");
    Array.Sort(files);
    int done = 0;
    using (var ad = new Bitmap(adPath)) {
      foreach (var f in files) {
        using (var raw = new Bitmap(f))
        using (var bmp = new Bitmap(raw.Width, raw.Height, PixelFormat.Format32bppArgb)) {
          using (var gc = Graphics.FromImage(bmp)) gc.DrawImage(raw, 0, 0, raw.Width, raw.Height);
          var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
          var bd = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
          int stride = bd.Stride;
          byte[] px = new byte[stride * bmp.Height];
          Marshal.Copy(bd.Scan0, px, 0, px.Length);

          // strict green scan for the card bounding box
          int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1;
          for (int y = 0; y < bmp.Height; y++) {
            int off = y * stride;
            for (int x = 0; x < bmp.Width; x++) {
              int i = off + x * 4;
              byte b = px[i], g = px[i + 1], r = px[i + 2];
              if (g > 100 && g > r + 60 && g > b + 60) {
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
              }
            }
          }

          if (maxX >= 0 && maxX - minX > 20 && maxY - minY > 20) {
            int bw = maxX - minX + 1, bh = maxY - minY + 1;
            try {
            // ad scaled to fit the card, black padding (matches ad background)
            using (var adScaled = new Bitmap(bw, bh)) {
              using (var g2 = Graphics.FromImage(adScaled)) {
                g2.Clear(Color.Black);
                g2.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                double s = Math.Max((double)bw / ad.Width, (double)bh / ad.Height);
                int aw = (int)(ad.Width * s), ah = (int)(ad.Height * s);
                g2.DrawImage(ad, (bw - aw) / 2, (bh - ah) / 2, aw, ah);
              }
              var abd = adScaled.LockBits(new Rectangle(0, 0, bw, bh), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
              byte[] apx = new byte[abd.Stride * bh];
              Marshal.Copy(abd.Scan0, apx, 0, apx.Length);

              for (int y = minY; y <= maxY; y++) {
                int off = y * stride;
                for (int x = minX; x <= maxX; x++) {
                  int i = off + x * 4;
                  byte b = px[i], g = px[i + 1], r = px[i + 2];
                  if (g > 80 && g > r + 30 && g > b + 30) {
                    // green -> ad pixel
                    int ai = (y - minY) * abd.Stride + (x - minX) * 4;
                    px[i] = apx[ai]; px[i + 1] = apx[ai + 1]; px[i + 2] = apx[ai + 2];
                  } else if (g > r + 12 && g > b + 12) {
                    // faint green fringe at the card edge -> despill
                    px[i + 1] = Math.Max(r, b);
                  }
                }
              }
              adScaled.UnlockBits(abd);
            }
            } catch (Exception ex) {
              throw new Exception("frame=" + Path.GetFileName(f) + " bbox=" + minX + "," + minY + " " + bw + "x" + bh, ex);
            }
          }

          Marshal.Copy(px, 0, bd.Scan0, px.Length);
          bmp.UnlockBits(bd);
          bmp.Save(Path.Combine(outDir, Path.GetFileName(f)), ImageFormat.Png);
          done++;
        }
      }
    }
    return done;
  }
}
'@

# force-load GDI+ internals, then reference every loaded assembly
$probe = New-Object System.Drawing.Bitmap(1,1); $probe.Dispose()
$refs = [AppDomain]::CurrentDomain.GetAssemblies() |
  Where-Object { $_.Location } | ForEach-Object Location | Select-Object -Unique
Add-Type -TypeDefinition $src -ReferencedAssemblies $refs

$m = "C:\Users\joeld\Documents\GitHub\JuneCreator\meme"
try {
  $n = [CardComposite].GetMethod('Process').Invoke($null, @("$m\gold_in", "$m\gold_out", "$m\pro_ad.png"))
  Write-Output "Processed $n frames"
} catch {
  $ex = $_.Exception
  while ($ex.InnerException) { Write-Output $ex.Message; $ex = $ex.InnerException }
  Write-Output $ex.GetType().FullName
  Write-Output $ex.Message
  Write-Output $ex.StackTrace
}
