# DKO Glow Wraps Editor - Double K.O. Designs
# Makes an add-on with your own colors for the Dancers Body Glow Wraps (SFW and/or NSFW): new items with their
# own icons, and optionally the Double K.O. Designs store. Started by "DKO Glow Wraps Editor.exe".
# Needs: Blender 5.x and the .NET 10 runtime. Everything else is in this folder.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
trap { [System.Windows.Forms.MessageBox]::Show("DKO Glow Wraps Editor hit an error:`n`n$($_.Exception.Message)", 'DKO Glow Wraps Editor', 'OK', 'Error') | Out-Null; exit 1 }
[System.Windows.Forms.Application]::EnableVisualStyles()
$Engine = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } elseif ($env:DKO_ENGINE_DIR) { $env:DKO_ENGINE_DIR } else { (Get-Location).Path }
$Root = Split-Path -Parent $Engine
$Settings = Join-Path $env:LOCALAPPDATA 'DKO_Glow_Wraps_Editor\settings.json'
$Registry = Join-Path $Engine 'creations.json'

# runs a program without a window and collects its output lines, so the builder window stays responsive
Add-Type -TypeDefinition @"
using System; using System.Diagnostics; using System.Collections.Concurrent; using System.Text;
public class DkoProc {
    public Process P; public ConcurrentQueue<string> Q = new ConcurrentQueue<string>();
    public DkoProc(string exe, string args) {
        var si = new ProcessStartInfo(exe, args);
        si.UseShellExecute = false; si.CreateNoWindow = true;
        si.RedirectStandardOutput = true; si.RedirectStandardError = true;
        si.StandardOutputEncoding = Encoding.UTF8; si.StandardErrorEncoding = Encoding.UTF8;
        P = new Process(); P.StartInfo = si;
        P.OutputDataReceived += (s, e) => { if (e.Data != null) Q.Enqueue(e.Data); };
        P.ErrorDataReceived += (s, e) => { if (e.Data != null) Q.Enqueue(e.Data); };
        P.Start(); P.BeginOutputReadLine(); P.BeginErrorReadLine();
    }
}
"@

# ---------------- look (Double K.O. Designs: black, hot orange, chrome, blue/violet light) ----------------
$Clr = @{
    Bg     = [System.Drawing.Color]::FromArgb(8, 8, 14)
    Panel  = [System.Drawing.Color]::FromArgb(18, 18, 30)
    Edge   = [System.Drawing.Color]::FromArgb(88, 70, 200)
    Orange = [System.Drawing.Color]::FromArgb(255, 150, 20)
    Hot    = [System.Drawing.Color]::FromArgb(255, 95, 20)
    Chrome = [System.Drawing.Color]::FromArgb(205, 208, 218)
    Text   = [System.Drawing.Color]::FromArgb(232, 232, 242)
    Dim    = [System.Drawing.Color]::FromArgb(140, 140, 165)
    Field  = [System.Drawing.Color]::FromArgb(26, 26, 42)
}
$Fnt = @{
    Body  = New-Object System.Drawing.Font('Segoe UI', 9.5)
    Step  = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
    Small = New-Object System.Drawing.Font('Segoe UI', 8.5)
    Btn   = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
    Num   = New-Object System.Drawing.Font('Segoe UI Black', 15)
    Big   = New-Object System.Drawing.Font('Segoe UI Black', 14)
    Title = New-Object System.Drawing.Font('Segoe UI Light', 12)
    Mono  = New-Object System.Drawing.Font('Consolas', 9)
}

# preset colors: base color (r,g,b), glow color (r,g,b) - the colors of the original glow items
$Presets = [ordered]@{
    'gold' = @(182,159,96, 254,216,0);        'silver' = @(160,168,180, 200,210,225);   'white' = @(235,235,235, 255,255,255)
    'grey' = @(96,100,104, 120,125,130);      'blacklight' = @(12,10,16, 130,0,255);    'blue' = @(16,48,204, 20,60,255)
    'orange' = @(204,88,0, 255,110,0);        'green' = @(0,176,32, 0,220,40);          'purple' = @(112,0,204, 140,0,255)
    'yellow_green' = @(136,204,0, 170,255,0); 'red_purple' = @(160,0,104, 200,0,130);   'pink' = @(204,96,144, 255,120,180)
    'hot_pink' = @(204,24,120, 255,30,150);   'magenta' = @(204,0,204, 255,0,255);      'turquoise' = @(32,180,168, 40,225,210)
    'cyan' = @(0,192,204, 0,240,255);         'lime' = @(96,204,0, 120,255,0);          'crimson' = @(160,0,32, 200,0,40)
    'lavender' = @(144,120,204, 180,150,255); 'neon_pink' = @(240,40,220, 255,16,240);  'neon_green' = @(60,230,40, 57,255,20)
    'neon_blue' = @(40,80,240, 30,80,255);    'neon_yellow' = @(230,240,20, 240,255,0); 'gold_pink' = @(182,159,96, 255,60,170)
    'red_matte' = @(200,20,25, 255,20,20);    'orange_matte' = @(230,100,10, 255,110,0); 'yellow_matte' = @(235,205,20, 255,230,0)
    'green_matte' = @(20,170,45, 0,220,40);   'blue_matte' = @(25,60,210, 20,60,255);   'purple_matte' = @(110,25,200, 140,0,255)
    'blue_orange' = @(25,55,190, 255,120,0);  'purple_yellow' = @(110,20,170, 255,225,0); 'red_cyan' = @(190,15,25, 0,235,255)
    'green_magenta' = @(20,150,40, 255,0,220); 'cold_fire_navy' = @(15,25,90, 255,140,0); 'cold_fire_violet' = @(55,20,110, 255,200,30)
    'silver_alt' = @(190,195,205, 255,255,255)
}
# names used to suggest a name for a custom color pair
$Named = @(
    @('black',10,10,14), @('white',240,240,240), @('grey',128,128,134), @('silver',192,196,206), @('red',230,20,20),
    @('crimson',160,0,32), @('orange',255,128,0), @('gold',212,175,55), @('yellow',255,230,0), @('lime',150,255,0),
    @('green',0,190,40), @('teal',0,150,140), @('cyan',0,230,255), @('sky',90,170,255), @('blue',20,60,255),
    @('navy',15,25,90), @('purple',130,0,255), @('violet',170,90,255), @('magenta',255,0,255), @('pink',255,120,180),
    @('hotpink',255,30,150), @('brown',120,70,30)
)
$DefaultFlow = 'up'
function Color-Name($c, $sep = ' ') {
    # named by hue (which color), then by how dark / pale / grey it is - so a soft green is still "green"
    $h = $c.GetHue(); $l = $c.GetBrightness(); $s = $c.GetSaturation()
    if ($l -lt 0.10) { return 'black' }
    if ($l -gt 0.93) { return 'white' }
    if (($s -lt 0.15) -or (($s -lt 0.25) -and ($l -gt 0.2) -and ($l -lt 0.8))) { if ($l -lt 0.6) { return 'grey' } else { return 'silver' } }
    if (($h -ge 15) -and ($h -lt 45) -and ($l -lt 0.38)) { return 'brown' }
    if (($h -ge 195) -and ($h -lt 250) -and ($l -lt 0.28)) { return 'navy' }
    if ((($h -ge 345) -or ($h -lt 12)) -and ($l -lt 0.32)) { return 'crimson' }
    $nm = 'red'
    foreach ($b in @(@(12, 'red'), @(40, 'orange'), @(52, 'gold'), @(66, 'yellow'), @(90, 'lime'), @(150, 'green'), @(182, 'teal'), @(197, 'cyan'),
                     @(218, 'sky'), @(258, 'blue'), @(272, 'violet'), @(295, 'purple'), @(322, 'magenta'), @(345, 'pink'), @(361, 'red'))) {
        if ($h -lt $b[0]) { $nm = $b[1]; break }
    }
    if (($nm -eq 'red') -and ($l -gt 0.7)) { $nm = 'pink' }
    if (($nm -eq 'pink') -and ($s -gt 0.8) -and ($l -gt 0.4) -and ($l -lt 0.7)) { $nm = 'hot' + $sep + 'pink' }
    if ((@('lime', 'yellow', 'gold') -contains $nm) -and ($l -lt 0.45) -and ($s -lt 0.5)) { return 'olive' }
    if ($l -lt 0.25) { $nm = 'dark' + $sep + $nm }
    elseif (($l -gt 0.78) -and ($nm -ne 'pink')) { $nm = 'light' + $sep + $nm }
    return $nm
}
function To-Color($a, $i) { return [System.Drawing.Color]::FromArgb($a[$i], $a[$i + 1], $a[$i + 2]) }

# ---------------- settings, Blender, .NET, game ----------------
function Load-Settings { try { if (Test-Path $Settings) { return Get-Content $Settings -Raw | ConvertFrom-Json } } catch {}; return [pscustomobject]@{} }
function Save-Settings($s) { try { New-Item -ItemType Directory -Force (Split-Path $Settings) | Out-Null; $s | ConvertTo-Json | Set-Content $Settings } catch {} }
function Set-Prop($o, $n, $v) { if ($o.PSObject.Properties[$n]) { $o.$n = $v } else { $o | Add-Member -NotePropertyName $n -NotePropertyValue $v } }
function Get-Prop($o, $n) { if ($o.PSObject.Properties[$n]) { return $o.$n }; return $null }
$cfg = Load-Settings

function Test-Blender($exe) {
    if (-not $exe -or -not (Test-Path $exe)) { return $false }
    return [bool](Get-ChildItem (Split-Path $exe) -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^[5-9]\.\d+$' -and (Test-Path (Join-Path $_.FullName 'python\bin\python.exe')) })
}
function Find-Blender {
    $b = Get-Prop $cfg 'blender'
    if (Test-Blender $b) { return $b }
    $cands = @()
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs")) {
        if ($base) { $cands += Get-ChildItem (Join-Path $base 'Blender Foundation') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'blender.exe' } }
    }
    $cands += "${env:ProgramFiles(x86)}\Steam\steamapps\common\Blender\blender.exe"
    return ($cands | Where-Object { Test-Blender $_ } | Select-Object -First 1)
}
function Find-Game {
    $g = Get-Prop $cfg 'game'
    if ($g -and (Test-Path (Join-Path $g 'bin\x64\Cyberpunk2077.exe'))) { return $g }
    $libs = @()
    try {
        $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
        if ($steam) {
            $libs += $steam
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path $vdf) { $libs += (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' } }
        }
    } catch {}
    foreach ($l in $libs) { $p = Join-Path $l 'steamapps\common\Cyberpunk 2077'; if (Test-Path (Join-Path $p 'bin\x64\Cyberpunk2077.exe')) { return $p } }
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1423049311', 'HKLM:\SOFTWARE\GOG.com\Games\1423049311')) {
        try { $p = (Get-ItemProperty $k -ErrorAction Stop).path; if ($p -and (Test-Path (Join-Path $p 'bin\x64\Cyberpunk2077.exe'))) { return $p } } catch {}
    }
    foreach ($p in @("$env:ProgramFiles\Epic Games\Cyberpunk2077", 'C:\GOG Games\Cyberpunk 2077')) { if (Test-Path (Join-Path $p 'bin\x64\Cyberpunk2077.exe')) { return $p } }
    return $null
}
function Has-DotNet {
    $d = "$env:ProgramFiles\dotnet\shared\Microsoft.NETCore.App"
    if (-not (Test-Path $d)) { return $false }
    return [bool](Get-ChildItem $d -Directory | Where-Object { $_.Name -match '^(1[0-9]|[2-9][0-9])\.' })
}
$cli = Join-Path $Engine 'wolvenkit\WolvenKit.CLI.exe'

# ---------------- window ----------------
$WinW = 1240; $WinH = 976
$form = New-Object System.Windows.Forms.Form
$form.Text = 'DKO Glow Wraps Editor  -  Double K.O. Designs'
$form.BackColor = $Clr.Bg; $form.ForeColor = $Clr.Text; $form.Font = $Fnt.Body
$form.FormBorderStyle = 'FixedSingle'; $form.MaximizeBox = $false; $form.StartPosition = 'CenterScreen'
$form.AutoScroll = $true
$form.ClientSize = New-Object System.Drawing.Size($WinW, $WinH)
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if ($form.Height -gt $wa.Height) { $form.Height = $wa.Height }
try { $form.Icon = New-Object System.Drawing.Icon (Join-Path $Engine 'ui\dko.ico') } catch {}

function New-Ctl($type, $x, $y, $w, $h, $parent) {
    $c = New-Object "System.Windows.Forms.$type"
    $c.Location = New-Object System.Drawing.Point($x, $y)
    if ($w) { $c.Width = $w }
    if ($h) { $c.Height = $h }
    $parent.Controls.Add($c)
    return $c
}
function New-Label($text, $x, $y, $parent, $font = $Fnt.Body, $color = $Clr.Text) {
    $l = New-Ctl 'Label' $x $y 0 0 $parent
    $l.Text = $text; $l.AutoSize = $true; $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}
function New-Btn($text, $x, $y, $w, $h, $parent, $primary = $false) {
    $b = New-Ctl 'Button' $x $y $w $h $parent
    $b.Text = $text; $b.FlatStyle = 'Flat'; $b.Font = $Fnt.Btn; $b.Cursor = 'Hand'; $b.UseVisualStyleBackColor = $false
    if ($primary) { $b.BackColor = $Clr.Orange; $b.ForeColor = [System.Drawing.Color]::Black; $b.FlatAppearance.BorderColor = $Clr.Hot; $b.Font = $Fnt.Big
                    $b.FlatAppearance.MouseOverBackColor = $Clr.Hot }
    else { $b.BackColor = $Clr.Field; $b.ForeColor = $Clr.Text; $b.FlatAppearance.BorderColor = $Clr.Orange
           $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(48, 36, 24) }
    $b.FlatAppearance.BorderSize = 1
    return $b
}
function Style-Field($c) { $c.BackColor = $Clr.Field; $c.ForeColor = $Clr.Text; if ($c -is [System.Windows.Forms.TextBox]) { $c.BorderStyle = 'FixedSingle' } }
$PanelPaint = {
    param($s, $e)
    $g = $e.Graphics
    $g.DrawRectangle((New-Object System.Drawing.Pen($Clr.Edge, 1)), 0, 0, $s.Width - 1, $s.Height - 1)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Point(0, 0)), (New-Object System.Drawing.Point($s.Width, 0)), $Clr.Hot, $Clr.Edge)
    $g.FillRectangle($br, 0, 0, $s.Width, 3)
}
function New-Panel($y, $h, $num, $title, $w = 774) {
    $p = New-Ctl 'Panel' 20 $y $w $h $form
    $p.BackColor = $Clr.Panel
    $p.Add_Paint($PanelPaint)
    $null = New-Label "$num." 10 8 $p $Fnt.Num $Clr.Orange
    $null = New-Label $title 50 14 $p $Fnt.Step $Clr.Chrome
    return $p
}

# header: the Double K.O. Designs logo
$hdr = New-Ctl 'PictureBox' 0 0 $WinW 150 $form
$hdr.SizeMode = 'Normal'; $hdr.BackColor = [System.Drawing.Color]::Black
try {
    # the banner fills the whole top: scaled to the full width, the extra height trimmed evenly top and bottom
    $src = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,[System.IO.File]::ReadAllBytes((Join-Path $Engine 'ui\dko_banner.png')))))
    $bw = $hdr.Width; $bh = $hdr.Height
    $sh = [Math]::Min($src.Height, [int]($src.Width * $bh / $bw)); $sw = [int]($sh * $bw / $bh)
    $bmp = New-Object System.Drawing.Bitmap($bw, $bh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $bw, $bh)), (New-Object System.Drawing.Rectangle([int](($src.Width - $sw) / 2), [int](($src.Height - $sh) / 2), $sw, $sh)), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); $hdr.Image = $bmp
} catch {}
$sub = New-Label 'G L O W    W R A P S    C O L O R    E D I T O R' 0 150 $form $Fnt.Title $Clr.Chrome
$sub.AutoSize = $false; $sub.Width = $WinW; $sub.Height = 28; $sub.TextAlign = 'MiddleCenter'; $sub.BackColor = [System.Drawing.Color]::Black

# 1. which Glow Wraps
$p1 = New-Panel 186 116 1 'Which Glow Wraps are you creating colors for?'
$rbSfw = New-Ctl 'RadioButton' 50 42 210 24 $p1; $rbSfw.Text = 'Dancers Body Glow Wraps'; $rbSfw.ForeColor = $Clr.Text
$rbNsfw = New-Ctl 'RadioButton' 270 42 250 24 $p1; $rbNsfw.Text = 'Dancers Body Glow Wraps NSFW'; $rbNsfw.ForeColor = $Clr.Text
$rbBoth = New-Ctl 'RadioButton' 530 42 120 24 $p1; $rbBoth.Text = 'Both'; $rbBoth.ForeColor = $Clr.Text
$null = New-Label 'Both versions are made for the Hyst EBBP RB body mod (Big Breasts Push Up, Big Booty) and fit that body only.' 50 70 $p1 $Fnt.Small $Clr.Orange
$null = New-Label 'Your colors become their own items and work on their own - the Dancers Body Glow Wraps mod does not have to be installed.' 50 90 $p1 $Fnt.Small $Clr.Dim
switch ([string](Get-Prop $cfg 'gwc_version')) { 'nsfw' { $rbNsfw.Checked = $true } 'both' { $rbBoth.Checked = $true } default { $rbSfw.Checked = $true } }

# 2. colors
$p2 = New-Panel 310 470 2 'Make a color   (base color + glow color)'
# your colors: the list, in its own section on the right (above Share your colors)
$plst = New-Ctl 'Panel' 806 186 414 594 $form
$plst.BackColor = $Clr.Panel; $plst.Add_Paint($PanelPaint)
$null = New-Label 'Your colors' 12 12 $plst $Fnt.Step $Clr.Chrome
$cbSort = New-Ctl 'ComboBox' 12 44 390 24 $plst; $cbSort.DropDownStyle = 'DropDownList'; Style-Field $cbSort; $cbSort.FlatStyle = 'Flat'
$lb = New-Ctl 'ListBox' 12 76 390 346 $plst
$lb.DrawMode = 'OwnerDrawFixed'; $lb.ItemHeight = 22; $lb.BackColor = $Clr.Field; $lb.ForeColor = $Clr.Text; $lb.BorderStyle = 'FixedSingle'; $lb.IntegralHeight = $false; $lb.HorizontalScrollbar = $true; $lb.HorizontalExtent = 0
$lb.Add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0) { return }
    $it = $s.Items[$e.Index]
    $sel = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0
    $bg = $Clr.Field; if ($sel) { $bg = [System.Drawing.Color]::FromArgb(70, 48, 22) }
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($bg)), $e.Bounds)
    $x = $e.Bounds.X + 5; $y = $e.Bounds.Y + 3
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($it.Base)), $x, $y, 18, 16)
    if ($it.Glow2) {     # Two-tone: both glow colors
        $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($it.Glow)), $x + 18, $y, 9, 16)
        $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($it.Glow2)), $x + 27, $y, 9, 16)
    } else { $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($it.Glow)), $x + 18, $y, 18, 16) }
    $e.Graphics.DrawRectangle((New-Object System.Drawing.Pen($Clr.Dim)), $x, $y, 36, 16)
    $label = $it.Title; if (-not $label) { $label = $it.Id }
    $e.Graphics.DrawString($label, $Fnt.Body, (New-Object System.Drawing.SolidBrush($Clr.Text)), [single]($x + 46), [single]($y - 1))
    $need = [int](46 + 16 + $e.Graphics.MeasureString($label, $Fnt.Body).Width)   # let the list scroll sideways to the end of the longest name
    if ($need -gt $s.HorizontalExtent) { $s.HorizontalExtent = $need }
})
$bRem = New-Btn 'Delete selected' 12 428 390 28 $plst
$bUp = New-Btn 'Move up' 12 462 193 28 $plst
$bDown = New-Btn 'Move down' 209 462 193 28 $plst
foreach ($x in @('Sort the list...', 'By name', 'By band style', 'By glow color', 'By base color', 'Reverse the order')) { [void]$cbSort.Items.Add($x) }; $cbSort.SelectedIndex = 0
$bDup = New-Btn 'Duplicate selected' 12 496 193 28 $plst
$bUndo = New-Btn 'Undo' 209 496 193 28 $plst; $bUndo.Enabled = $false
$bOpen2 = New-Btn 'Open existing add-on...' 12 530 390 28 $plst
$lListNote = New-Label "Every color in the list goes into the add-on. The list is saved: next time just add, change or remove colors and build again." 12 562 $plst $Fnt.Small $Clr.Dim
$lListNote.AutoSize = $false; $lListNote.Size = New-Object System.Drawing.Size(394, 30)
# sharing: its own section (bottom right, next to Build)
$psh = New-Ctl 'Panel' 806 796 414 112 $form
$psh.BackColor = $Clr.Panel; $psh.Add_Paint($PanelPaint)
$null = New-Label 'Share your colors' 12 12 $psh $Fnt.Step $Clr.Chrome
$lShare = New-Label ("Post a color on Nexus or Discord, or send it to friends: select it and click Copy share code. " +
                     "Others click Paste share code to add it.") 12 36 $psh $Fnt.Small $Clr.Dim
$lShare.AutoSize = $false; $lShare.Size = New-Object System.Drawing.Size(394, 36)
$bShare = New-Btn 'Copy share code' 12 76 193 28 $psh
$bPaste = New-Btn 'Paste share code' 209 76 193 28 $psh
# names the Glow Wraps already use (a new color with one of these names gets "custom_" in front)
$Taken = @('gold','silver','white','grey','black','blue','orange','green','purple','yellow_green','red_purple','pink','hot_pink',
           'magenta','turquoise','cyan','lime','crimson','lavender','neon_pink','neon_green','neon_blue','neon_yellow','gold_pink',
           'red_matte','orange_matte','yellow_matte','green_matte','blue_matte','purple_matte','blue_orange','purple_yellow',
           'red_cyan','green_magenta','cold_fire_navy','cold_fire_violet','silver_alt','default')
function Clean-Id($id) { $id = ($id.ToLower() -replace '[^a-z0-9_]', '_').Trim('_'); if ($Taken -contains $id) { $id = 'custom_' + $id }; return $id }
# one color = one object: Id, Name, Title, Base, Glow, Finish, Ev, Speed, Tile, Flow, Band, BandW
function Make-Item($o) {
    $d = [ordered]@{ Id = ''; Name = ''; Title = ''; Base = [System.Drawing.Color]::Gray; Glow = [System.Drawing.Color]::White; Finish = 'metallic'
                     Ev = 1.5; Speed = 0.5; Tile = 1; Flow = $DefaultFlow; Band = 'original'; BandW = 1.0; Glow2 = $null }
    foreach ($k in @($o.Keys)) { $d[$k] = $o[$k] }
    $d.Id = Clean-Id ([string]$d.Id)
    return [pscustomobject]$d
}
function Find-Id($id, $skip = -1) { for ($i = 0; $i -lt $lb.Items.Count; $i++) { if (($i -ne $skip) -and ($lb.Items[$i].Id -eq $id)) { return $i } }; return -1 }
function Add-Item($it, $quiet = $false) {
    if (-not $it.Id) { return $false }
    if ((Find-Id $it.Id) -ge 0) { if (-not $quiet) { [void][System.Windows.Forms.MessageBox]::Show("'$($it.Id)' is already in the list (same name and same settings).", 'DKO Glow Wraps Editor') }; return $false }
    [void]$lb.Items.Add($it); return $true
}

$null = New-Label 'Presets' 290 43 $p2 $Fnt.Small $Clr.Dim
$cbFrom = New-Ctl 'ComboBox' 364 39 196 24 $p2; $cbFrom.DropDownStyle = 'DropDownList'; Style-Field $cbFrom; $cbFrom.FlatStyle = 'Flat'
[void]$cbFrom.Items.Add('(my own colors)'); foreach ($k in $Presets.Keys) { [void]$cbFrom.Items.Add($k) }; $cbFrom.SelectedIndex = 0
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($cbFrom, 'Presets: loads the base + glow color of one of the Glow Wraps colors into the buttons below, as a starting point to change.')
$null = New-Label 'Custom' 290 79 $p2 $Fnt.Small $Clr.Dim
$script:baseCol = [System.Drawing.Color]::FromArgb(255, 128, 0)
$script:glowCol = [System.Drawing.Color]::FromArgb(230, 20, 20)
$script:glow2Col = $null       # Two-tone: the second glow color (none = one glow color)
$bBase = New-Btn 'Base' 364 74 62 26 $p2
$bGlow = New-Btn 'Glow' 430 74 62 26 $p2
$bGlow2 = New-Btn 'Glow 2' 496 74 66 26 $p2
$bGlow2X = New-Btn 'x' 564 74 22 26 $p2; $bGlow2X.Font = $Fnt.Small
$bRand = New-Btn 'Random' 592 72 168 28 $p2
$tip.SetToolTip($bRand, 'Fills in a random color: base, glow, finish, sliders, direction and band. Change anything you like, then click Add New.')
$tip.SetToolTip($bBase, 'The base color of the straps.')
$tip.SetToolTip($bGlow, 'The glow color: the light that moves along the straps.')
$tip.SetToolTip($bGlow2, "Two-tone (optional): a second glow color. The glow starts in the Glow color and fades into this one`nalong its tail (Melt: down the drips). Click x to go back to one glow color.")
$tip.SetToolTip($bGlow2X, 'No second glow color (one glow color).')
# finish: one has to be picked for every new color (nothing is picked at the start)
$null = New-Label 'Finish' 290 167 $p2 $Fnt.Small $Clr.Dim
$pFin = New-Ctl 'FlowLayoutPanel' 360 160 400 30 $p2; $pFin.BackColor = $Clr.Panel; $pFin.WrapContents = $false; $pFin.FlowDirection = 'LeftToRight'
$Finishes = [ordered]@{
    'metallic' = @('Metallic', 'Shiny metal in the base color (like the Glow Wraps colors).')
    'chrome'   = @('Chrome',   'Mirror-like polished metal in the base color.')
    'satin'    = @('Satin',    'Soft brushed metal in the base color - between Metallic and Matte.')
    'gloss'    = @('Gloss',    'Shiny non-metal in the base color, like latex or wet vinyl.')
    'matte'    = @('Matte',    'Flat finish in the base color, no shine.')
}
$rbFin = [ordered]@{}
foreach ($k in $Finishes.Keys) {
    $r = New-Ctl 'RadioButton' 0 0 60 24 $pFin; $r.Text = $Finishes[$k][0]; $r.ForeColor = $Clr.Text; $r.Tag = $k
    $r.AutoSize = $true; $r.Margin = New-Object System.Windows.Forms.Padding(2, 4, 10, 0)   # sized to its name, small even gap
    $tip.SetToolTip($r, $Finishes[$k][1]); $rbFin[$k] = $r
}
function Get-Finish { foreach ($k in $rbFin.Keys) { if ($rbFin[$k].Checked) { return $k } }; return '' }
function Set-Finish($f) { foreach ($k in $rbFin.Keys) { $rbFin[$k].Checked = ($k -eq $f) } }

function New-Slider($label, $y, $min, $max, $val, $tipText) {
    $null = New-Label $label 290 ($y + 8) $p2 $Fnt.Small $Clr.Dim
    $t = New-Ctl 'TrackBar' 358 $y 246 30 $p2
    $t.Minimum = $min; $t.Maximum = $max; $t.TickFrequency = 1; $t.SmallChange = 1; $t.LargeChange = 1; $t.Value = $val
    $t.BackColor = $Clr.Panel; $t.AutoSize = $false; $t.Height = 30; $t.Width = 246
    $tip.SetToolTip($t, $tipText)
    return $t
}
$tbEv = New-Slider 'Glow' 192 1 20 6 'Glow strength. Left = deep, colorful glow. Right = white-hot glow with only a hint of color.'
$lEv = New-Label '' 608 200 $p2 $Fnt.Small $Clr.Text
$tbSp = New-Slider 'Speed' 224 0 20 5 'How fast the glow moves along the straps. All the way left = the glow stands still.'
$lSp = New-Label '' 608 232 $p2 $Fnt.Small $Clr.Text
$tbTl = New-Slider 'Repeat' 256 1 8 1 'How many bands of light run along the straps at once. 1 = the Glow Wraps look.'
$lTl = New-Label '' 608 264 $p2 $Fnt.Small $Clr.Text
function Get-Ev { return [double]($tbEv.Value / 4.0) }
function Get-Speed { return [double]($tbSp.Value / 10.0) }
function Update-Ev { $v = Get-Ev; $w = 'colorful'; if ($v -gt 1.5) { $w = 'bright' }; if ($v -gt 3.0) { $w = 'white-hot' }; $lEv.Text = (Num $v) + '   ' + $w }
function Update-Sp { $v = Get-Speed; $w = 'normal'; if ($v -lt 0.45) { $w = 'slow' }; if ($v -eq 0) { $w = 'still' }; if ($v -gt 0.75) { $w = 'fast' }; $lSp.Text = (Num $v) + '   ' + $w }
function Update-Tl { $v = $tbTl.Value; $w = 'normal'; if ($v -gt 1) { $w = 'more bands' }; $lTl.Text = [string]$v + 'x   ' + $w }

# direction of the moving glow (same choices as the DKO Design Builder)
$null = New-Label 'Direction' 290 294 $p2 $Fnt.Small $Clr.Dim
$cbFlow = New-Ctl 'ComboBox' 364 290 196 24 $p2; $cbFlow.DropDownStyle = 'DropDownList'; Style-Field $cbFlow; $cbFlow.FlatStyle = 'Flat'
$Flows = [ordered]@{ 'out' = @('Center outward', 'Outward'); 'in' = @('Outside inward', 'Inward'); 'up' = @('Feet to head', 'Upward'); 'down' = @('Head to feet', 'Downward') }
foreach ($k in $Flows.Keys) { [void]$cbFlow.Items.Add($Flows[$k][0]) }
function Get-Flow { foreach ($k in $Flows.Keys) { if ($Flows[$k][0] -eq [string]$cbFlow.SelectedItem) { return $k } }; return $DefaultFlow }
function Set-Flow($f) { if (-not $Flows.Contains([string]$f)) { $f = $DefaultFlow }; $cbFlow.SelectedItem = $Flows[[string]$f][0] }
Set-Flow $DefaultFlow
$tip.SetToolTip($cbFlow, "Which way the glow travels.`nCenter outward = from the belly out to the head, hands and feet.   Outside inward = the other way.`nFeet to head / Head to feet = up or down the body. The Glow Wraps colors use '$($Flows[$DefaultFlow][0])'.")

# glow band: its look and width (same choices as the DKO Design Builder, plus the Glow Wraps' own glow)
$null = New-Label 'Band' 290 326 $p2 $Fnt.Small $Clr.Dim
$cbBand = New-Ctl 'ComboBox' 364 322 120 24 $p2; $cbBand.DropDownStyle = 'DropDownList'; Style-Field $cbBand; $cbBand.FlatStyle = 'Flat'
$Bands = [ordered]@{ 'original' = 'Original'; 'soft' = 'Soft'; 'bands' = 'Bands'; 'wavy' = 'Wavy'; 'melt' = 'Melt'; 'rings' = 'Rings'; 'sharp' = 'Sharp' }
foreach ($k in $Bands.Keys) { [void]$cbBand.Items.Add($Bands[$k]) }; $cbBand.SelectedIndex = 0
$null = New-Label 'Width' 494 326 $p2 $Fnt.Small $Clr.Dim
$tbBand = New-Ctl 'TrackBar' 534 318 150 30 $p2
$tbBand.Minimum = 1; $tbBand.Maximum = 10; $tbBand.TickFrequency = 1; $tbBand.SmallChange = 1; $tbBand.LargeChange = 2; $tbBand.Value = 4
$tbBand.BackColor = $Clr.Panel; $tbBand.AutoSize = $false; $tbBand.Height = 30; $tbBand.Width = 150
$lBand = New-Label '' 688 326 $p2 $Fnt.Small $Clr.Text
function Get-Band { foreach ($k in $Bands.Keys) { if ($Bands[$k] -eq [string]$cbBand.SelectedItem) { return $k } }; return 'original' }
function Set-Band($b) { if (-not $Bands.Contains([string]$b)) { $b = 'original' }; $cbBand.SelectedItem = $Bands[[string]$b] }
function Get-BandW { return [double]($tbBand.Value / 4.0) }   # 0.25 .. 2.5
function Update-Band { $lBand.Text = (Num (Get-BandW)) + 'x'; $on = ((Get-Band) -ne 'original'); $tbBand.Enabled = $on; $lBand.Enabled = $on }
$tip.SetToolTip($cbBand, "The look of the moving glow:`nOriginal = the Glow Wraps' own glow   Soft = one soft band   Bands = blocky digital steps`nWavy = the band snakes around the body   Melt = a band with drips of uneven length running down from it`nRings = three thin rings   Sharp = one solid band with hard edges.")
$tip.SetToolTip($tbBand, 'How wide the glow band is (0.25x to 2.5x). Middle = normal width. (Not used by Original.)')

$null = New-Label 'Name' 290 362 $p2 $Fnt.Small $Clr.Dim
$tbCol = New-Ctl 'TextBox' 364 358 396 24 $p2; Style-Field $tbCol
$tip.SetToolTip($tbCol, 'Your name for the color. Filled in from the colors until you type your own - your name is kept when you change the other options.')
$bAddCus = New-Btn 'Add New' 364 410 196 28 $p2
$bUpd = New-Btn 'Update Selected' 568 410 192 28 $p2
$lName = New-Label '' 290 388 $p2 $Fnt.Small $Clr.Chrome; $lName.AutoSize = $false; $lName.Size = New-Object System.Drawing.Size(470, 18); $lName.AutoEllipsis = $true
$tip.SetToolTip($lName, 'The item name in the store and inventory. The finish, glow, speed, repeat, direction and band are added to your name, so every color can be told apart.')
$tip.SetToolTip($bAddCus, 'Adds these settings to Your colors as a new color (a color selected in the list stays as it was).')
$tip.SetToolTip($bUpd, 'Saves these settings to the color selected in Your colors: click a color in the list, change it, then click this.')
$null = New-Label "Base = the color of the straps (pick a Finish for it).`nGlow = the light that moves along them.   Glow 2 = optional second glow color.`nClick a color in Your colors to see or change it." 290 106 $p2 $Fnt.Small $Clr.Orange

$script:typed = $false; $script:settingName = $false; $script:loading = $false   # typed = the user typed the name themselves
function Num($v) { return ([string]$v).Replace(',', '.') }
function Get-NameText {
    $n = (($tbCol.Text -replace '[^A-Za-z0-9 _-]', ' ') -replace '[_-]', ' ').Trim()
    return (($n -split '\s+') | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ' '
}
function Get-Title {
    $f = Get-Finish; $fn = 'no finish yet'; if ($f) { $fn = $Finishes[$f][0] }
    $t = (Get-NameText) + ', ' + $fn + ', Glow ' + (Num (Get-Ev)) + ', Speed ' + (Num (Get-Speed)) + ', ' + [string]$tbTl.Value + 'x, ' + $Flows[(Get-Flow)][1]
    if ($script:glow2Col) { $t = $t + ', Two-Tone' }
    if ((Get-Band) -ne 'original') { $t = $t + ', ' + $Bands[(Get-Band)] + ' ' + (Num (Get-BandW)) + 'x' }
    return $t
}
function Get-Id {
    $n = ($tbCol.Text.ToLower() -replace '[^a-z0-9]+', '_').Trim('_')
    $id = $n + '_' + (Get-Finish) + '_glow' + ((Num (Get-Ev)) -replace '\.', 'p') + '_speed' + ((Num (Get-Speed)) -replace '\.', 'p') + '_x' + [string]$tbTl.Value + '_' + (Get-Flow)
    if ((Get-Band) -ne 'original') { $id = $id + '_' + (Get-Band) + '_w' + ((Num (Get-BandW)) -replace '\.', 'p') }
    if ($script:glow2Col) { $c2 = $script:glow2Col; $id = $id + '_tt' + ('{0:x2}{1:x2}{2:x2}' -f $c2.R, $c2.G, $c2.B) }
    return $id
}
function Update-Name { $lName.Text = 'In game: Dancers Body Glow Wraps (' + (Get-Title) + ')' }
function Update-Preview { }     # replaced by the live preview below, once it is set up
function Update-Swatches {
    if ($script:loading) { return }
    foreach ($pair in @(@($bBase, $script:baseCol), @($bGlow, $script:glowCol), @($bGlow2, $script:glow2Col))) {
        $b = $pair[0]; $c = $pair[1]
        if (-not $c) { $b.BackColor = $Clr.Field; $b.ForeColor = $Clr.Dim; continue }      # Glow 2 not used
        $b.BackColor = $c
        if (($c.R * 0.3 + $c.G * 0.59 + $c.B * 0.11) -gt 140) { $b.ForeColor = [System.Drawing.Color]::Black } else { $b.ForeColor = [System.Drawing.Color]::White }
    }
    $bGlow2X.Enabled = [bool]$script:glow2Col
    # the name follows the colors - unless the user typed their own, or is changing a color picked in the list
    if ((-not $script:typed) -and ($lb.SelectedIndex -lt 0)) {
        $script:settingName = $true
        $nm = (Color-Name $script:baseCol) + ' ' + (Color-Name $script:glowCol)
        if ($script:glow2Col) { $nm = $nm + ' ' + (Color-Name $script:glow2Col) }
        $tbCol.Text = $nm
        $script:settingName = $false
    }
    Update-Name
    Update-Preview
}
# the settings in the controls as a list item
function Item-FromControls {
    return Make-Item ([ordered]@{ Id = (Get-Id); Name = (Get-NameText); Title = (Get-Title); Base = $script:baseCol; Glow = $script:glowCol
                                 Finish = (Get-Finish); Ev = (Get-Ev); Speed = (Get-Speed); Tile = $tbTl.Value; Flow = (Get-Flow); Band = (Get-Band); BandW = (Get-BandW)
                                 Glow2 = $script:glow2Col })
}
# a list item's settings into the controls (to see or change them)
function Show-Item($it) {
    $script:loading = $true
    $script:baseCol = $it.Base; $script:glowCol = $it.Glow; $script:glow2Col = $it.Glow2
    Set-Finish $it.Finish
    $tbEv.Value = [Math]::Max(1, [Math]::Min(20, [int][Math]::Round($it.Ev * 4)))
    $tbSp.Value = [Math]::Max(0, [Math]::Min(20, [int][Math]::Round($it.Speed * 10)))
    $tbTl.Value = [Math]::Max(1, [Math]::Min(8, [int]$it.Tile))
    Set-Flow $it.Flow; Set-Band $it.Band
    $tbBand.Value = [Math]::Max(1, [Math]::Min(10, [int][Math]::Round($it.BandW * 4)))
    $nm = $it.Name; if (-not $nm) { $nm = ([string]$it.Title).Split(',')[0]; if (-not $nm) { $nm = $it.Id -replace '_', ' ' } }
    $script:settingName = $true; $tbCol.Text = $nm; $script:settingName = $false
    $script:typed = $false
    $script:loading = $false
    Update-Ev; Update-Sp; Update-Tl; Update-Band; Update-Swatches
}

$tbCol.Add_TextChanged({ if (-not $script:settingName) { $script:typed = ($tbCol.Text.Trim() -ne '') }; Update-Name })
$cbFrom.Add_SelectedIndexChanged({
    $k = [string]$cbFrom.SelectedItem
    if ($Presets.Contains($k)) { $v = $Presets[$k]; $script:baseCol = To-Color $v 0; $script:glowCol = To-Color $v 3; if ($k -like '*_matte') { Set-Finish 'matte' } else { Set-Finish 'metallic' }; Update-Swatches }
})
$bBase.Add_Click({ $d = New-Object System.Windows.Forms.ColorDialog; $d.FullOpen = $true; $d.Color = $script:baseCol; if ($d.ShowDialog() -eq 'OK') { $script:baseCol = $d.Color; Update-Swatches } })
$bGlow.Add_Click({ $d = New-Object System.Windows.Forms.ColorDialog; $d.FullOpen = $true; $d.Color = $script:glowCol; if ($d.ShowDialog() -eq 'OK') { $script:glowCol = $d.Color; Update-Swatches } })
$bGlow2.Add_Click({
    $d = New-Object System.Windows.Forms.ColorDialog; $d.FullOpen = $true
    if ($script:glow2Col) { $d.Color = $script:glow2Col } else { $d.Color = $script:glowCol }
    if ($d.ShowDialog() -eq 'OK') { $script:glow2Col = $d.Color; Update-Swatches }
})
$bGlow2X.Add_Click({ $script:glow2Col = $null; Update-Swatches })
function Check-Ready {
    if (-not (Get-Finish)) { [void][System.Windows.Forms.MessageBox]::Show('Pick a finish first: Metallic, Chrome, Satin, Gloss or Matte.', 'DKO Glow Wraps Editor'); return $false }
    if (-not $tbCol.Text.Trim()) { [void][System.Windows.Forms.MessageBox]::Show('Type a name for the color first.', 'DKO Glow Wraps Editor'); return $false }
    return $true
}
# ---- undo: the list as it was before each change (add, update, remove, duplicate, move, sort, paste, open)
$script:undo = New-Object System.Collections.ArrayList
function Push-Undo {
    $snap = New-Object System.Collections.ArrayList
    foreach ($x in $lb.Items) { [void]$snap.Add($x) }
    [void]$script:undo.Add(@{ Items = $snap; Sel = $lb.SelectedIndex })
    while ($script:undo.Count -gt 50) { $script:undo.RemoveAt(0) }
    $bUndo.Enabled = $true
}
function Do-Undo {
    if ($script:undo.Count -eq 0) { return }
    $u = $script:undo[$script:undo.Count - 1]; $script:undo.RemoveAt($script:undo.Count - 1)
    $lb.BeginUpdate(); $lb.Items.Clear(); foreach ($x in $u.Items) { [void]$lb.Items.Add($x) }; $lb.EndUpdate()
    $lb.SelectedIndex = [Math]::Min($u.Sel, $lb.Items.Count - 1)
    if ($lb.SelectedIndex -lt 0) { $script:typed = $false; Update-Swatches }
    $bUndo.Enabled = ($script:undo.Count -gt 0)
}
$bUndo.Add_Click({ Do-Undo })
$tip.SetToolTip($bUndo, 'Undo the last change to the color list (also Ctrl+Z when you are not typing in a box).')
$form.KeyPreview = $true
$form.Add_KeyDown({
    param($s, $e)
    if ($e.Control -and $e.KeyCode -eq 'Z' -and -not ($form.ActiveControl -is [System.Windows.Forms.TextBox])) { Do-Undo; $e.Handled = $true; $e.SuppressKeyPress = $true }
})
$bAddCus.Add_Click({
    if (-not (Check-Ready)) { return }
    $it = Item-FromControls
    if ((Find-Id $it.Id) -lt 0) { Push-Undo }
    if (Add-Item $it) {
        $lb.SelectedIndex = -1
        $script:typed = $false; Update-Swatches   # ready for the next color
    }
})
$bUpd.Add_Click({
    $i = $lb.SelectedIndex
    if ($i -lt 0) { [void][System.Windows.Forms.MessageBox]::Show('Click the color in Your colors that you want to change first.', 'DKO Glow Wraps Editor'); return }
    if (-not (Check-Ready)) { return }
    $it = Item-FromControls
    if ((Find-Id $it.Id $i) -ge 0) { [void][System.Windows.Forms.MessageBox]::Show("Another color in the list already has exactly these settings and name ('$($it.Id)').", 'DKO Glow Wraps Editor'); return }
    Push-Undo
    $lb.Items[$i] = $it
    $lb.Invalidate()
})
$lb.Add_SelectedIndexChanged({
    if ($lb.SelectedIndex -ge 0) { Show-Item $lb.Items[$lb.SelectedIndex] }
})
# a click on an empty spot of the list: nothing selected
$lb.Add_MouseDown({ param($s, $e); if ($lb.IndexFromPoint($e.Location) -lt 0 -and $lb.SelectedIndex -ge 0) { $lb.SelectedIndex = -1 } })
foreach ($r in $rbFin.Values) { $r.Add_CheckedChanged({ Update-Swatches }) }
$tbEv.Add_ValueChanged({ Update-Ev; Update-Swatches })
$tbSp.Add_ValueChanged({ Update-Sp; Update-Swatches })
$tbTl.Add_ValueChanged({ Update-Tl; Update-Swatches })
$cbFlow.Add_SelectedIndexChanged({ Update-Swatches })
$cbBand.Add_SelectedIndexChanged({ Update-Band; Update-Swatches })
$tbBand.Add_ValueChanged({ Update-Band; Update-Swatches })
$bRem.Add_Click({ if ($lb.SelectedIndex -ge 0) { Push-Undo; $lb.Items.RemoveAt($lb.SelectedIndex); $lb.SelectedIndex = -1; $script:typed = $false; Update-Swatches } })
# duplicate: a copy of the selected color right under it, named "<name> Copy" - change it and click Update Selected
$bDup.Add_Click({
    $i = $lb.SelectedIndex
    if ($i -lt 0) { [void][System.Windows.Forms.MessageBox]::Show('Click the color in the list that you want to copy first.', 'DKO Glow Wraps Editor'); return }
    Show-Item $lb.Items[$i]
    $base = Get-NameText; $n = 1
    do {
        $nm = $base + ' Copy'; if ($n -gt 1) { $nm = $nm + ' ' + $n }
        $script:settingName = $true; $tbCol.Text = $nm; $script:settingName = $false
        $it = Item-FromControls; $n++
    } while ((Find-Id $it.Id) -ge 0)
    $script:typed = $true
    Push-Undo
    $lb.Items.Insert($i + 1, $it); $lb.SelectedIndex = $i + 1
})
$tip.SetToolTip($bDup, 'Adds a copy of the selected color right under it (named "... Copy"), to make a variation of it: change it, then click Update Selected.')
function Move-Sel($d) {
    $i = $lb.SelectedIndex; $j = $i + $d
    if ($i -lt 0 -or $j -lt 0 -or $j -ge $lb.Items.Count) { return }
    Push-Undo
    $it = $lb.Items[$i]; $lb.Items.RemoveAt($i); $lb.Items.Insert($j, $it); $lb.SelectedIndex = $j
}
$bUp.Add_Click({ Move-Sel -1 })
$bDown.Add_Click({ Move-Sel 1 })
$tip.SetToolTip($bUp, 'Moves the selected color up the list. The store and the add-on list the colors in this order.')
$tip.SetToolTip($bDown, 'Moves the selected color down the list. The store and the add-on list the colors in this order.')
$cbSort.Add_SelectedIndexChanged({
    $k = $cbSort.SelectedIndex
    if ($k -le 0 -or $lb.Items.Count -lt 2) { $cbSort.SelectedIndex = 0; return }
    Push-Undo
    $items = @($lb.Items)
    $bandOrder = @($Bands.Keys)
    switch ($k) {
        1 { $items = @($items | Sort-Object { ([string]$_.Name).ToLower() }, { $_.Id }) }
        2 { $items = @($items | Sort-Object { $bandOrder.IndexOf([string]$_.Band) }, { ([string]$_.Name).ToLower() }) }
        3 { $items = @($items | Sort-Object { if ($_.Glow.GetSaturation() -lt 0.12) { 400 + $_.Glow.GetBrightness() } else { $_.Glow.GetHue() } }, { ([string]$_.Name).ToLower() }) }
        4 { $items = @($items | Sort-Object { if ($_.Base.GetSaturation() -lt 0.12) { 400 + $_.Base.GetBrightness() } else { $_.Base.GetHue() } }, { ([string]$_.Name).ToLower() }) }
        5 { [array]::Reverse($items) }
    }
    $lb.BeginUpdate(); $lb.Items.Clear(); foreach ($x in $items) { [void]$lb.Items.Add($x) }; $lb.EndUpdate()
    $lb.SelectedIndex = -1; $script:typed = $false; Update-Swatches
    $cbSort.SelectedIndex = 0
})
$tip.SetToolTip($cbSort, 'Sorts the color list (the store and the add-on list the colors in this order). Undo puts it back.')
# random: every setting picked at random, all still editable before Add New
$script:rng = New-Object System.Random
function Rand-Color {
    # a vivid color: random hue, mostly strong saturation, sometimes dark or pale
    $h = $script:rng.NextDouble() * 360; $sat = 0.55 + 0.45 * $script:rng.NextDouble(); $val = 0.35 + 0.65 * $script:rng.NextDouble()
    if ($script:rng.Next(8) -eq 0) { $sat = 0.05 * $script:rng.NextDouble() }       # now and then a black / grey / white
    $c = $val * $sat; $x = $c * (1 - [Math]::Abs((($h / 60) % 2) - 1)); $m = $val - $c
    switch ([int][Math]::Floor($h / 60)) { 0 { $r = $c; $g = $x; $b = 0 } 1 { $r = $x; $g = $c; $b = 0 } 2 { $r = 0; $g = $c; $b = $x }
                                           3 { $r = 0; $g = $x; $b = $c } 4 { $r = $x; $g = 0; $b = $c } default { $r = $c; $g = 0; $b = $x } }
    return [System.Drawing.Color]::FromArgb([int](255 * ($r + $m)), [int](255 * ($g + $m)), [int](255 * ($b + $m)))
}
$bRand.Add_Click({
    $script:loading = $true
    $lb.SelectedIndex = -1
    $cbFrom.SelectedIndex = 0
    $script:baseCol = Rand-Color
    $script:glowCol = Rand-Color
    $script:glow2Col = $null; if ($script:rng.Next(3) -eq 0) { $script:glow2Col = Rand-Color }     # Two-tone about 1 time in 3
    $keys = @($rbFin.Keys); Set-Finish $keys[$script:rng.Next($keys.Count)]
    $tbEv.Value = $script:rng.Next(2, 15)          # 0.5 .. 3.5
    $tbSp.Value = $script:rng.Next(1, 16)          # 0.1 .. 1.5
    $tbTl.Value = $script:rng.Next(1, 5)           # 1x .. 4x
    $fk = @($Flows.Keys); Set-Flow $fk[$script:rng.Next($fk.Count)]
    $bk = @($Bands.Keys); Set-Band $bk[$script:rng.Next($bk.Count)]
    $tbBand.Value = $script:rng.Next(2, 9)         # 0.5x .. 2x
    $script:typed = $false
    $script:loading = $false
    Update-Ev; Update-Sp; Update-Tl; Update-Band; Update-Swatches
})
# ---- live preview: the straps with the moving glow, made like the add-on makes it (lighting is approximate) ----
# (in step 2, left of the color settings)
$pbPrev = New-Ctl 'PictureBox' 40 40 225 392 $p2; $pbPrev.BackColor = $Clr.Panel; $pbPrev.SizeMode = 'Normal'
$bFront = New-Btn 'Front' 40 436 72 26 $p2
$bBack = New-Btn 'Back' 116 436 72 26 $p2
$bPause = New-Btn 'Pause' 192 436 73 26 $p2
$lPrev = New-Label '' 40 60 $p2 $Fnt.Small $Clr.Orange; $lPrev.Visible = $false
$lPrev.AutoSize = $false; $lPrev.Size = New-Object System.Drawing.Size(225, 120)
$tip.SetToolTip($pbPrev, 'The selected color (or the settings you are changing) on the straps, with the glow moving like in the game. Light and shine are only approximate.')
$script:pvOk = $false; $script:pvView = 0; $script:pvT = 0.0; $script:pvPause = $false; $script:pvBmp = $null; $script:pvBuf = $null
try {
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $Engine 'ui\gwc_preview.cs'))) -Language CSharp
    $err = [GwcPreview]::Load((Join-Path $Engine 'ui\preview.dat'))
    if ($err) { throw $err }
    $script:pvBmp = New-Object System.Drawing.Bitmap([GwcPreview]::W, [GwcPreview]::H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $script:pvBuf = New-Object int[] ([GwcPreview]::W * [GwcPreview]::H)
    $pbPrev.Image = $script:pvBmp
    $script:pvOk = $true
} catch { $lPrev.Text = 'Preview not available:' + "`n" + $_.Exception.Message; $lPrev.Visible = $true; $lPrev.BringToFront() }
function Update-Preview {
    if (-not $script:pvOk) { return }
    try {
        $ver = 0; if ($rbNsfw.Checked) { $ver = 1 }
        $f = Get-Flow; $lay = 0; if ($f -eq 'out' -or $f -eq 'in') { $lay = 1 }
        $band = Get-Band; if ($band -eq 'wavy' -or $band -eq 'melt') { $lay += 2 }
        $sign = 1; if ($f -eq 'down' -or $f -eq 'in') { $sign = -1 }
        $g2 = $script:glow2Col; $g2r = -1; $g2g = -1; $g2b = -1; if ($g2) { $g2r = $g2.R; $g2g = $g2.G; $g2b = $g2.B }
        $fin = Get-Finish; if (-not $fin) { $fin = 'metallic' }
        [GwcPreview]::Set($ver, $lay, $script:baseCol.R, $script:baseCol.G, $script:baseCol.B, $script:glowCol.R, $script:glowCol.G, $script:glowCol.B,
                          $g2r, $g2g, $g2b, $fin, (Get-Ev), (Get-Speed), $sign, $tbTl.Value, $band, (Get-BandW))
        Draw-Preview
    } catch {}
}
function Draw-Preview {
    if (-not $script:pvOk) { return }
    [GwcPreview]::Render($script:pvView, $script:pvT, $script:pvBuf, $Clr.Panel.ToArgb())
    $r = New-Object System.Drawing.Rectangle(0, 0, $script:pvBmp.Width, $script:pvBmp.Height)
    $bd = $script:pvBmp.LockBits($r, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try { [System.Runtime.InteropServices.Marshal]::Copy($script:pvBuf, 0, $bd.Scan0, $script:pvBuf.Length) } finally { $script:pvBmp.UnlockBits($bd) }
    $pbPrev.Invalidate()
}
$pvTimer = New-Object System.Windows.Forms.Timer; $pvTimer.Interval = 40
$pvTimer.Add_Tick({ if ($script:pvPause -or -not $p2.Visible) { return }; $script:pvT += 0.04; Draw-Preview })
$bFront.Add_Click({ $script:pvView = 0; Draw-Preview })
$bBack.Add_Click({ $script:pvView = 1; Draw-Preview })
$bPause.Add_Click({ $script:pvPause = -not $script:pvPause; if ($script:pvPause) { $bPause.Text = 'Play' } else { $bPause.Text = 'Pause' } })
foreach ($r in @($rbSfw, $rbNsfw, $rbBoth)) { $r.Add_CheckedChanged({ Update-Preview }) }
if ($script:pvOk) { $pvTimer.Start() }
$form.Add_FormClosed({ try { $pvTimer.Stop() } catch {} })
Update-Ev; Update-Sp; Update-Tl; Update-Band; Update-Swatches

# ---- color lists: saved list, built add-ons ----
function Item-FromJson($c) {
    $P = $c.PSObject.Properties
    $o = [ordered]@{ Id = [string]$c.id }
    $o.Glow = [System.Drawing.Color]::FromArgb([int]$c.glow[0], [int]$c.glow[1], [int]$c.glow[2])
    $o.Base = [System.Drawing.Color]::FromArgb([int]$c.base[0], [int]$c.base[1], [int]$c.base[2])
    if ($P['ev'] -and $c.ev) { $o.Ev = [double]$c.ev }
    if ($P['finish'] -and $c.finish) { $o.Finish = [string]$c.finish } elseif ($P['matte'] -and $c.matte) { $o.Finish = 'matte' }
    if ($P['speed'] -and $null -ne $c.speed) { $o.Speed = [Math]::Abs([double]$c.speed) }
    if ($P['tile'] -and $c.tile) { $o.Tile = [int]$c.tile }
    if ($P['flow'] -and $c.flow) { $o.Flow = [string]$c.flow }
    if ($P['band'] -and $c.band) { $o.Band = [string]$c.band }
    if ($P['band_width'] -and $c.band_width) { $o.BandW = [double]$c.band_width }
    if ($P['name'] -and $c.name) { $o.Name = [string]$c.name }
    if ($P['title'] -and $c.title) { $o.Title = [string]$c.title }
    if ($P['glow2'] -and $c.glow2 -and @($c.glow2).Count -ge 3) { $o.Glow2 = [System.Drawing.Color]::FromArgb([int]$c.glow2[0], [int]$c.glow2[1], [int]$c.glow2[2]) }
    return Make-Item $o
}
function Item-ToJson($it) {
    return [ordered]@{ id = $it.Id; name = $it.Name; title = $it.Title; finish = $it.Finish; matte = ($it.Finish -eq 'matte'); ev = [double]$it.Ev
                       speed = [double]$it.Speed; tile = [int]$it.Tile; flow = $it.Flow; band = $it.Band; band_width = [double]$it.BandW
                       base = @([int]$it.Base.R, [int]$it.Base.G, [int]$it.Base.B); glow = @([int]$it.Glow.R, [int]$it.Glow.G, [int]$it.Glow.B)
                       glow2 = $(if ($it.Glow2) { @([int]$it.Glow2.R, [int]$it.Glow2.G, [int]$it.Glow2.B) } else { $null }) }
}
$Saved = Join-Path $Engine 'glowwraps_colors.json'

# ---- share codes: one color as a line of text (DKOGWC1:...) to post anywhere; pasting one adds the color
$ShareTag = 'DKOGWC1:'
function Share-Code($it) {
    $j = Item-ToJson $it
    $j.Remove('id'); $j.Remove('title'); $j.Remove('matte')     # the id is made again from the settings
    $json = ConvertTo-Json $j -Compress
    return $ShareTag + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
}
function Read-Share($text) {
    $m = [regex]::Match([string]$text, 'DKOGWC1:([A-Za-z0-9+/=]+)')
    if (-not $m.Success) { return $null }
    $c = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($m.Groups[1].Value)) | ConvertFrom-Json
    if (-not $c.base -or -not $c.glow) { return $null }
    return $c
}
$bShare.Add_Click({
    $i = $lb.SelectedIndex
    if ($i -lt 0) { [void][System.Windows.Forms.MessageBox]::Show('Click the color in the list that you want to share first.', 'DKO Glow Wraps Editor'); return }
    $code = Share-Code $lb.Items[$i]
    try { [System.Windows.Forms.Clipboard]::SetText($code); $bShare.Text = 'Copied!' }
    catch { [void][System.Windows.Forms.MessageBox]::Show("Could not copy. The share code is:`n`n$code", 'DKO Glow Wraps Editor') }
})
$lb.Add_SelectedIndexChanged({ $bShare.Text = 'Copy share code' })
$bPaste.Add_Click({
    $c = $null
    try { $c = Read-Share ([System.Windows.Forms.Clipboard]::GetText()) } catch {}
    if (-not $c) { [void][System.Windows.Forms.MessageBox]::Show("No share code found. Copy a share code first (it starts with $ShareTag), then click Paste share code.", 'DKO Glow Wraps Editor'); return }
    # its settings go into the controls, so the name and item name are made the same way as your own colors
    Show-Item (Item-FromJson $c)
    if ($c.name) { $script:settingName = $true; $tbCol.Text = [string]$c.name; $script:settingName = $false; $script:typed = $true; Update-Name }
    if (-not (Get-Finish)) { Set-Finish 'metallic' }
    $it = Item-FromControls
    $i = Find-Id $it.Id
    if ($i -ge 0) { $lb.SelectedIndex = $i; [void][System.Windows.Forms.MessageBox]::Show('That color is already in your list (selected).', 'DKO Glow Wraps Editor'); return }
    Push-Undo
    [void]$lb.Items.Add($it); $lb.SelectedIndex = $lb.Items.Count - 1
})
$tip.SetToolTip($bShare, "Copies a share code for the selected color: one line of text you can post anywhere (Nexus, Discord...).`nAnyone with DKO Glow Wraps Editor can add the color with Paste share code.")
$tip.SetToolTip($bPaste, 'Adds the color of a share code you copied (from a post or a message) to your list.')

# open a Glow Wraps Colors add-on that was built before (its .zip, or the .yaml in the game / Vortex folder)
$DataTag = '# DKO-GWC-DATA: '
function Read-AddOn($path) {
    $text = $null
    if ($path -like '*.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $z = [System.IO.Compression.ZipFile]::OpenRead($path)
        try {
            foreach ($e in $z.Entries) {
                if ($e.FullName -replace '\\', '/' -like '*doubleko_glow_wraps_colors.yaml') {
                    $sr = New-Object System.IO.StreamReader($e.Open()); $text = $sr.ReadToEnd(); $sr.Close(); break
                }
            }
        } finally { $z.Dispose() }
    } else { $text = [IO.File]::ReadAllText($path) }
    if (-not $text) { return $null }
    foreach ($ln in ($text -split "`n")) {
        $ln = $ln.Trim()
        if ($ln.StartsWith($DataTag)) {
            $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ln.Substring($DataTag.Length)))
            return ($json | ConvertFrom-Json)
        }
    }
    return 'old'
}
$bOpen2.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Title = 'Open a Glow Wraps Colors add-on'
    $d.Filter = 'Glow Wraps Colors add-on (DoubleKO_Glow_Wraps_Colors.zip or doubleko_glow_wraps_colors.yaml)|*.zip;*.yaml|All files|*.*'
    $g = Find-Game
    $inGame = if ($g) { Join-Path $g 'r6\tweaks\doubleko' } else { $null }
    if ($inGame -and (Test-Path (Join-Path $inGame 'doubleko_glow_wraps_colors.yaml'))) { $d.InitialDirectory = $inGame; $d.FileName = 'doubleko_glow_wraps_colors.yaml' }
    else { $d.InitialDirectory = $Root }
    if ($d.ShowDialog() -ne 'OK') { return }
    $data = $null
    try { $data = Read-AddOn $d.FileName } catch {}
    if ($data -eq 'old') { [void][System.Windows.Forms.MessageBox]::Show("This add-on was made with an older version of DKO Glow Wraps Editor, which did not store its color settings in the add-on.`nIts colors are still in your saved list if you made them on this computer.", 'DKO Glow Wraps Editor'); return }
    if (-not $data -or -not $data.colors) { [void][System.Windows.Forms.MessageBox]::Show('No Glow Wraps Colors were found in that file.', 'DKO Glow Wraps Editor'); return }
    $cols = @($data.colors)
    $a = [System.Windows.Forms.MessageBox]::Show("Found $($cols.Count) color(s) in this add-on.`n`nYes = replace the colors in the list with them`nNo = add them to the colors already in the list", 'DKO Glow Wraps Editor', 'YesNoCancel')
    if ($a -eq 'Cancel') { return }
    Push-Undo
    if ($a -eq 'Yes') { $lb.Items.Clear() }
    $n = 0; foreach ($c in $cols) { if (Add-Item (Item-FromJson $c) $true) { $n++ } }
    switch ([string]$data.version) { 'nsfw' { $rbNsfw.Checked = $true } 'both' { $rbBoth.Checked = $true } 'sfw' { $rbSfw.Checked = $true } }
    [void][System.Windows.Forms.MessageBox]::Show("$n color(s) loaded. Click one to see or change it, then build again - the new add-on replaces the old one.", 'DKO Glow Wraps Editor')
})
# at start: load the newest color list - the saved list, the add-on zip built last, or the add-on in the game
function Load-Startup {
    $log = New-Object System.Collections.Generic.List[string]
    $log.Add((Get-Date).ToString('s') + '  loading your colors')
    try {
        $cands = @()
        if (Test-Path $Saved) { $cands += [pscustomobject]@{ Path = $Saved; Time = (Get-Item $Saved).LastWriteTime; Saved = $true } }
        $z = Join-Path $Root 'DoubleKO_Glow_Wraps_Colors.zip'
        if (Test-Path $z) { $cands += [pscustomobject]@{ Path = $z; Time = (Get-Item $z).LastWriteTime; Saved = $false } }
        $g = $null; try { $g = Find-Game } catch { $log.Add('  game folder not found: ' + $_.Exception.Message) }
        if ($g) { $y = Join-Path $g 'r6\tweaks\doubleko\doubleko_glow_wraps_colors.yaml'; if (Test-Path $y) { $cands += [pscustomobject]@{ Path = $y; Time = (Get-Item $y).LastWriteTime; Saved = $false } } }
        foreach ($c in @($cands | Sort-Object Time -Descending)) {
            $log.Add('  trying ' + $c.Path)
            try {
                $ver = $null
                if ($c.Saved) {
                    $list = Get-Content $c.Path -Raw | ConvertFrom-Json      # into a variable first: Windows PowerShell hands a JSON list over as ONE object
                } else {
                    $d = Read-AddOn $c.Path
                    if (-not $d -or ($d -is [string]) -or -not $d.colors) { $log.Add('    no color list in it'); continue }
                    $list = $d.colors; $ver = [string]$d.version
                }
                $n = 0
                foreach ($x in $list) {
                    try {
                        if ($x.PSObject.Properties['transparent'] -and $x.transparent) { continue }
                        if (Add-Item (Item-FromJson $x) $true) { $n++ }
                    } catch { $log.Add('    skipped one color: ' + $_.Exception.Message) }
                }
                $log.Add("    $n color(s) loaded")
                if ($n -gt 0) {
                    try { switch ($ver) { 'nsfw' { $rbNsfw.Checked = $true } 'both' { $rbBoth.Checked = $true } 'sfw' { $rbSfw.Checked = $true } } } catch {}
                    break
                }
            } catch { $log.Add('    could not read it: ' + $_.Exception.Message) }
        }
    } catch { $log.Add('  failed: ' + $_.Exception.Message) }
    try { $ad = Join-Path $env:LOCALAPPDATA 'DKO_Glow_Wraps_Colors'; [IO.Directory]::CreateDirectory($ad) | Out-Null; [IO.File]::WriteAllLines((Join-Path $ad 'startup_log.txt'), $log) } catch {}
}
$tip.SetToolTip($bOpen2, "Load the colors of an add-on you built before (its DoubleKO_Glow_Wraps_Colors.zip, or the`ndoubleko_glow_wraps_colors.yaml in the game's r6\tweaks\doubleko folder) to add, change or remove colors.`nYour newest list is loaded by itself when the window opens.")
Load-Startup

# 3. build
$p3 = New-Panel 796 112 3 'Build the add-on'
$chkStore = New-Ctl 'CheckBox' 50 40 500 22 $p3; $chkStore.Text = 'Add the colors to the Double K.O. Designs store (Virtual Atelier)'; $chkStore.Checked = $true; $chkStore.ForeColor = $Clr.Text
$chkInst = New-Ctl 'CheckBox' 50 62 500 22 $p3; $chkInst.Text = 'Also install it into my game now (no Vortex needed)'; $chkInst.Checked = $false; $chkInst.ForeColor = $Clr.Text
$null = New-Label 'The finished .zip files are saved in the DKO Glow Wraps Editor folder.' 50 84 $p3 $Fnt.Small $Clr.Dim
$bGo = New-Btn 'BUILD COLORS' 570 34 186 56 $p3 $true

# progress view (replaces the steps while building)
$pr = New-Ctl 'Panel' 20 186 1200 722 $form; $pr.BackColor = $Clr.Panel; $pr.Visible = $false
$pr.Add_Paint($PanelPaint)
$lStep = New-Label 'Starting...' 16 14 $pr $Fnt.Step $Clr.Orange
$bar = New-Ctl 'ProgressBar' 18 46 1164 12 $pr; $bar.Style = 'Marquee'; $bar.MarqueeAnimationSpeed = 30
$log = New-Ctl 'TextBox' 18 70 1164 440 $pr; $log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true
$log.BackColor = [System.Drawing.Color]::FromArgb(6, 6, 10); $log.ForeColor = $Clr.Chrome; $log.Font = $Fnt.Mono; $log.BorderStyle = 'None'
$bOpen = New-Btn 'Show the finished add-on' 18 574 280 40 $pr; $bOpen.Visible = $false
$bCopy = New-Btn 'Copy add-to-inventory command' 306 574 340 40 $pr; $bCopy.Visible = $false
$script:invCmd = ''
$bCopy.Add_Click({
    if (-not $script:invCmd) { return }
    try { [System.Windows.Forms.Clipboard]::SetText($script:invCmd); $bCopy.Text = 'Copied! Paste it in the console' }
    catch { [void][System.Windows.Forms.MessageBox]::Show("Could not copy. The command is:`n`n$($script:invCmd)", 'DKO Glow Wraps Editor') }
})
(New-Object System.Windows.Forms.ToolTip).SetToolTip($bCopy, "Copies one command that adds all the new color items to your inventory.`nIn game: open the Cyber Engine Tweaks overlay, click in the Console box, press Ctrl+V, then Enter.")
$bAgain = New-Btn 'Back to editor' 654 574 270 40 $pr; $bAgain.Visible = $false
$bAgain.Add_Click({ $pr.Visible = $false; foreach ($p in @($p1, $p2, $p3, $plst, $psh)) { $p.Visible = $true } })
$bDone = New-Btn 'Done' 932 574 250 40 $pr; $bDone.Visible = $false
$bDone.Add_Click({ $form.Close() })
# Add to Vortex: hands the finished zip(s) to Vortex, which installs them like a dragged-in file
$bVortex = New-Btn 'Add to Vortex' 18 520 1164 46 $pr $true; $bVortex.Visible = $false
(New-Object System.Windows.Forms.ToolTip).SetToolTip($bVortex, "Sends the finished add-on (and the store file) to Vortex, which installs them into Cyberpunk 2077.`nIf Vortex is open it is closed and opened again on Cyberpunk 2077 (you are asked first).")
function Find-Vortex {
    $v = Get-Prop $cfg 'vortex'
    if ($v -and (Test-Path $v)) { return $v }
    # Vortex registers itself for nxm:// links: that tells where it is
    try {
        $cmd = (Get-ItemProperty 'Registry::HKEY_CLASSES_ROOT\nxm\shell\open\command' -ErrorAction Stop).'(default)'
        if ($cmd -match '"?([^"]*Vortex\.exe)"?') { if (Test-Path $matches[1]) { return $matches[1] } }
    } catch {}
    foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        try {
            foreach ($e in @(Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Vortex*' -and $_.InstallLocation })) {
                $p = Join-Path $e.InstallLocation 'Vortex.exe'; if (Test-Path $p) { return $p }
            }
        } catch {}
    }
    foreach ($p in @("$env:ProgramFiles\Black Tree Gaming Ltd\Vortex\Vortex.exe", "$env:LOCALAPPDATA\Programs\vortex\Vortex.exe", "${env:ProgramFiles(x86)}\Black Tree Gaming Ltd\Vortex\Vortex.exe")) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}
$bVortex.Add_Click({
    $vx = Find-Vortex
    if (-not $vx) {
        [void][System.Windows.Forms.MessageBox]::Show('Vortex was not found. Please pick your Vortex.exe (usually in C:\Program Files\Black Tree Gaming Ltd\Vortex).', 'DKO Glow Wraps Editor')
        $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter = 'Vortex.exe|Vortex.exe'
        if ($dlg.ShowDialog() -ne 'OK') { return }
        $vx = $dlg.FileName
    }
    Set-Prop $cfg 'vortex' $vx; Save-Settings $cfg
    $files = @($script:lastZip, $script:lastStore) | Where-Object { $_ -and (Test-Path $_) }
    if (-not $files) { return }
    $bVortex.Enabled = $false
    try {
        # Vortex only takes the game (--game) when it starts; an open Vortex installs into the game it shows.
        # So an open Vortex is closed (normally, like clicking its X) and started again on Cyberpunk 2077.
        $game = $true
        if (Get-Process -Name 'Vortex' -ErrorAction SilentlyContinue) {
            $a = [System.Windows.Forms.MessageBox]::Show("Vortex is open. It adds new mods to whichever game it shows, and it can only be switched to Cyberpunk 2077 when it starts.`n`nYes = close Vortex and open it again on Cyberpunk 2077 (recommended)`nNo = send the files to the open Vortex anyway (make sure it shows Cyberpunk 2077)", 'DKO Glow Wraps Editor', 'YesNoCancel')
            if ($a -eq 'Cancel') { $bVortex.Enabled = $true; return }
            if ($a -eq 'No') { $game = $false }
            else {
                Say '   closing Vortex...'
                foreach ($p in @(Get-Process -Name 'Vortex' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })) { try { [void]$p.CloseMainWindow() } catch {} }
                $t = (Get-Date).AddSeconds(30)
                while ((Get-Process -Name 'Vortex' -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $t)) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
                if (Get-Process -Name 'Vortex' -ErrorAction SilentlyContinue) {
                    [void][System.Windows.Forms.MessageBox]::Show('Vortex did not close (it may be busy or asking something). Please close Vortex yourself, then click Add to Vortex again.', 'DKO Glow Wraps Editor')
                    $bVortex.Enabled = $true; return
                }
            }
        }
        $first = $true
        foreach ($f in $files) {
            $argv = @('--install-archive', ('"' + $f + '"'))
            if ($first -and $game) {
                $argv = @('--game', 'cyberpunk2077') + $argv
                Start-Process -FilePath $vx -ArgumentList $argv
                Say '   opening Vortex on Cyberpunk 2077...'
                # wait until Vortex's window is up before handing it the next file
                $t = (Get-Date).AddSeconds(90)
                while (-not (Get-Process -Name 'Vortex' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }) -and ((Get-Date) -lt $t)) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 250 }
                $t = (Get-Date).AddSeconds(8); while ((Get-Date) -lt $t) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
            } else {
                if (-not $first) { $t = (Get-Date).AddSeconds(4); while ((Get-Date) -lt $t) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 } }
                Start-Process -FilePath $vx -ArgumentList $argv
            }
            Say ('   sent to Vortex: ' + (Split-Path $f -Leaf))
            $first = $false
        }
        $where = 'into Cyberpunk 2077'; if (-not $game) { $where = 'into the game it has open - make sure that is Cyberpunk 2077' }
        Say "   Vortex installs them $where. If it asks, choose Replace, then Enable / Deploy."
        [void][System.Windows.Forms.MessageBox]::Show("Sent to Vortex:`n   " + (($files | ForEach-Object { Split-Path $_ -Leaf }) -join "`n   ") + "`n`nVortex installs them $where.`nIf Vortex asks about a mod that is already installed, choose Replace. Then enable them and deploy if Vortex does not do it by itself.", 'DKO Glow Wraps Editor')
    } catch { [void][System.Windows.Forms.MessageBox]::Show("Could not start Vortex: $($_.Exception.Message)", 'DKO Glow Wraps Editor') }
    $bVortex.Enabled = $true
})
$lNote = New-Ctl 'Label' 18 622 1164 92 $pr; $lNote.TextAlign = 'MiddleCenter'; $lNote.Font = $Fnt.Btn
$lNote.ForeColor = $Clr.Orange; $lNote.BackColor = [System.Drawing.Color]::Transparent; $lNote.Visible = $false
$bOpen.Add_Click({ if ($script:lastZip) { Start-Process explorer.exe "/select,`"$($script:lastZip)`"" } else { Start-Process explorer.exe $Root } })

# support footer
$KoFi = 'https://ko-fi.com/doublekodesigns'
$ft = New-Ctl 'Panel' 20 918 1200 50 $form; $ft.BackColor = $Clr.Panel
$ftText = New-Ctl 'Label' 14 2 960 47 $ft
$ftText.Text = "DKO Glow Wraps Editor is free to use and share. If it has helped you create something awesome,`nplease consider supporting the developer and future Double K.O. Designs releases with a donation on Ko-fi.`nThank you!"
$ftText.TextAlign = 'MiddleCenter'; $ftText.Font = $Fnt.Small; $ftText.ForeColor = $Clr.Dim; $ftText.BackColor = [System.Drawing.Color]::Transparent
$ftIcon = New-Ctl 'PictureBox' 992 15 20 20 $ft; $ftIcon.SizeMode = 'Zoom'; $ftIcon.BackColor = [System.Drawing.Color]::Transparent; $ftIcon.Cursor = 'Hand'
try { $ftIcon.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,[System.IO.File]::ReadAllBytes((Join-Path $Engine 'ui\kofi.png'))))) } catch {
    try { $ftIcon.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,[System.IO.File]::ReadAllBytes((Join-Path $Engine 'ui\coffee.png'))))) } catch {} }
$ftIcon.Add_Click({ Start-Process $KoFi })
$ftLink = New-Ctl 'LinkLabel' 1016 17 170 20 $ft
$ftLink.Text = 'ko-fi.com/doublekodesigns'; $ftLink.AutoSize = $true; $ftLink.Font = $Fnt.Small
$ftLink.LinkColor = $Clr.Orange; $ftLink.ActiveLinkColor = $Clr.Text; $ftLink.VisitedLinkColor = $Clr.Orange; $ftLink.BackColor = [System.Drawing.Color]::Transparent
$ftLink.Add_LinkClicked({ Start-Process $KoFi })

# ---------------- building ----------------
$script:busy = $null
$script:lastZip = $null
$script:lastStore = $null
function Say($t) { $log.AppendText($t + "`r`n") }
function Quote-Arg($a) { return '"' + ($a -replace '"', '\"') + '"' }
function Run-Step($title, $exe, [string[]]$argv, $pattern, $logFile) {
    $lStep.Text = $title; Say ''; Say "== $title"
    $p = New-Object DkoProc($exe, (($argv | ForEach-Object { Quote-Arg $_ }) -join ' '))
    $script:busy = $p
    $line = $null
    while ((-not $p.P.HasExited) -or ($p.Q.Count -gt 0)) {
        while ($p.Q.TryDequeue([ref]$line)) {
            Add-Content -Path $logFile -Value $line
            if ($line -match $pattern) { Say ('   ' + $line.Trim()) }
        }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 40
        if ($p.P.HasExited) { $p.P.WaitForExit() }
    }
    $script:busy = $null
    return $p.P.ExitCode
}
function Fail($t) {
    $lStep.Text = 'Something went wrong'; $lStep.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)
    Say ''; Say "ERROR: $t"; $bar.Style = 'Blocks'; $bar.Value = 0
    $bAgain.Visible = $true; $bDone.Visible = $true
    [void][System.Windows.Forms.MessageBox]::Show($t, 'DKO Glow Wraps Editor', 'OK', 'Error')
}
$form.Add_FormClosing({ if ($script:busy) { try { $script:busy.P.Kill() } catch {} } })

# Python: the one inside Blender (same as the Design Builder), or a Python that is installed on the computer
function Find-Python {
    $bl = Find-Blender
    if ($bl) {
        $bv = Get-ChildItem (Split-Path $bl) -Directory | Where-Object { $_.Name -match '^[5-9]\.\d+$' } | Sort-Object Name -Descending | Select-Object -First 1
        if ($bv) { $p = Join-Path $bv.FullName 'python\bin\python.exe'; if (Test-Path $p) { return $p } }
    }
    foreach ($n in @('py.exe', 'python.exe')) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c -and $c.Source -notlike '*WindowsApps*') { return $c.Source }
    }
    return $null
}

$bGo.Add_Click({
    if ($lb.Items.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show('Step 2: add at least one color.', 'DKO Glow Wraps Editor'); return }
    $ver = 'sfw'; if ($rbNsfw.Checked) { $ver = 'nsfw' }; if ($rbBoth.Checked) { $ver = 'both' }
    Set-Prop $cfg 'gwc_version' $ver; Save-Settings $cfg
    $py = Find-Python
    if (-not $py) {
        [void][System.Windows.Forms.MessageBox]::Show("Blender 5 was not found (its built-in Python is used). Please pick your blender.exe.`n`nNo Blender yet? It is free at blender.org.", 'DKO Glow Wraps Editor')
        $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter = 'blender.exe|blender.exe'
        if ($dlg.ShowDialog() -ne 'OK' -or -not (Test-Blender $dlg.FileName)) { [void][System.Windows.Forms.MessageBox]::Show('Blender 5 is needed (free at blender.org).', 'DKO Glow Wraps Editor'); return }
        Set-Prop $cfg 'blender' $dlg.FileName; Save-Settings $cfg
        $py = Find-Python
    }
    if (-not (Has-DotNet)) {
        $r = [System.Windows.Forms.MessageBox]::Show("The free Microsoft .NET 10 Runtime is needed (WolvenKit uses it).`n`nOpen the download page now? Install '.NET Runtime 10' (x64), then build again.", 'DKO Glow Wraps Editor', 'YesNo')
        if ($r -eq 'Yes') { Start-Process 'https://dotnet.microsoft.com/download/dotnet/10.0' }
        return
    }
    if (-not (Test-Path $cli)) { [void][System.Windows.Forms.MessageBox]::Show("WolvenKit is missing ($cli). Unpack the whole DKO Glow Wraps Editor zip again.", 'DKO Glow Wraps Editor'); return }
    $game = $null
    if ($chkInst.Checked) {
        $game = Find-Game
        if (-not $game) {
            $fd = New-Object System.Windows.Forms.FolderBrowserDialog; $fd.Description = 'Pick your "Cyberpunk 2077" game folder'
            if ($fd.ShowDialog() -eq 'OK' -and (Test-Path (Join-Path $fd.SelectedPath 'bin\x64\Cyberpunk2077.exe'))) { $game = $fd.SelectedPath }
            else { [void][System.Windows.Forms.MessageBox]::Show('That is not the Cyberpunk 2077 folder. The add-on will only be saved as a .zip.', 'DKO Glow Wraps Editor') }
        }
        if ($game) { Set-Prop $cfg 'game' $game; Save-Settings $cfg }
    }

    foreach ($p in @($p1, $p2, $p3, $plst, $psh)) { $p.Visible = $false }
    $pr.Visible = $true; $log.Clear(); foreach ($b in @($bOpen, $bCopy, $bAgain, $bDone, $bVortex, $lNote)) { $b.Visible = $false }; $script:lastStore = $null
    $lStep.ForeColor = $Clr.Orange; $bar.Style = 'Marquee'

    $work = Join-Path $env:LOCALAPPDATA 'DKO_Glow_Wraps_Editor\work'
    if (Test-Path $work) { Remove-Item $work -Recurse -Force }
    New-Item -ItemType Directory -Force $work | Out-Null
    $logFile = Join-Path $work 'build_log.txt'
    $cols = @(foreach ($it in $lb.Items) { Item-ToJson $it })
    $json = ConvertTo-Json -InputObject $cols -Depth 4
    $colorsJson = Join-Path $work 'colors.json'
    [IO.File]::WriteAllText($colorsJson, $json, (New-Object System.Text.UTF8Encoding($false)))
    try { [IO.File]::WriteAllText($Saved, $json, (New-Object System.Text.UTF8Encoding($false))) } catch {}   # remember the list for next time
    Say ('Colors:   ' + (($cols | ForEach-Object { $_.id }) -join ', ')); Say "Version:  $ver"; Say "Full log: $logFile"

    # 1. the add-on (its own copy of the straps with the new colors, glow bands, icons, names, items)
    $mod = Join-Path $work 'mod'
    $items = Join-Path $work 'items.json'
    $rc = Run-Step '1/3   Making the color add-on' $py @('-u', (Join-Path $Engine 'dko_glowwraps_colors.py'), $colorsJson, '--cli', $cli, '--work', (Join-Path $work 'files'), '--mod', $mod, '--version', $ver, '--items', $items) '^(===|DONE|FAILED|NOTE|colors)' $logFile
    if ($rc -ne 0 -or -not (Test-Path (Join-Path $mod 'archive\pc\mod\DoubleKO_Glow_Wraps_Colors.archive'))) {
        $e = Select-String -Path $logFile -Pattern '^FAILED (.*)' | Select-Object -Last 1
        $why = "See $logFile"; if ($e) { $why = $e.Matches[0].Groups[1].Value + "`n`nFull log: $logFile" }
        Fail "Making the add-on failed. $why"; return
    }

    # 2. the Double K.O. Designs store (it lists the new colors too; it only shows items that are installed)
    $store = $null
    if ($chkStore.Checked) {
        $store = Join-Path $work 'store'
        $sargs = @('-u', (Join-Path $Engine 'dko_store.py'), $Registry, $store, '--extra', 'glowwraps_colors', $items)
        $g2 = $game; if (-not $g2) { $g2 = Find-Game }
        if ($g2) { $old = Join-Path $g2 'r6\scripts\DoubleKODesigns\DoubleKODesigns-atelier-store.reds'; if (Test-Path $old) { $sargs += @('--base', $old) } }
        $rc = Run-Step '2/3   Adding the colors to the Double K.O. Designs store' $py $sargs '^store' $logFile
        if ($rc -ne 0) { Say '   (the store could not be updated - the add-on itself is fine)'; $store = $null }
    }

    # 3. zips in the builder folder (+ optional install)
    $lStep.Text = '3/3   Saving the add-on'; Say ''; Say '== 3/3   Saving the add-on'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $Root 'DoubleKO_Glow_Wraps_Colors.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($mod, $zip)
    Say "   $zip"
    if ($store) {
        $szip = Join-Path $Root 'DoubleKO_Designs_Atelier_Store.zip'
        $script:lastStore = $szip
        if (Test-Path $szip) { Remove-Item $szip -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($store, $szip)
        Say "   $szip"
        Say '   (this store file adds your new colors to the Double K.O. Designs store in Virtual Atelier)'
    }
    if ($game) {
        try {
            Copy-Item (Join-Path $mod '*') $game -Recurse -Force
            Say "   installed into $game"
            if ($store) {
                $va = @(Get-ChildItem (Join-Path $game 'archive\pc\mod') -Filter 'VirtualAtelier*.archive' -ErrorAction SilentlyContinue).Count -gt 0
                if ($va) { Copy-Item (Join-Path $store '*') $game -Recurse -Force; Say '   store installed:  Virtual Atelier  >  Double K.O. Designs' }
                else { Say '   store NOT installed: Virtual Atelier is not in your game. Install Virtual Atelier, then the store .zip.' }
            }
        } catch { Say "   could not install into the game (is it running?): $($_.Exception.Message)" }
    }
    $ids = @(); try { $j = Get-Content $items -Raw | ConvertFrom-Json; $ids = @($j) } catch {}   # via a variable: a JSON list comes over as ONE object
    $script:invCmd = (($ids | ForEach-Object { 'Game.AddToInventory("' + $_ + '")' }) -join '; ')
    $script:lastZip = $zip
    $bar.Style = 'Blocks'; $bar.Value = 100
    $lStep.Text = 'Done!'; $lStep.ForeColor = [System.Drawing.Color]::FromArgb(90, 230, 120)
    Say ''; Say 'Install DoubleKO_Glow_Wraps_Colors.zip with Vortex (the Add to Vortex button, or drag it in) or unpack it into your Cyberpunk 2077 folder.'
    Say 'It works on its own (it needs ArchiveXL and TweakXL - not the Glow Wraps mod). Building again replaces it with your new list.'
    $note = 'Install:  DoubleKO_Glow_Wraps_Colors.zip'
    if ($store) { $note = $note + "   +   DoubleKO_Designs_Atelier_Store.zip`nThe store file adds your new colors to the Double K.O. Designs store (Virtual Atelier).`nLet the new store file win in Vortex." }
    $lNote.Text = $note; $lNote.Visible = $true
    $bOpen.Visible = $true; $bAgain.Visible = $true; $bDone.Visible = $true; $bVortex.Visible = $true; $bCopy.Visible = ($ids.Count -gt 0); $bCopy.Text = 'Copy add-to-inventory command'
})

[void]$form.ShowDialog()
