# Turok: Evolution (Xbox, USA) 2-player split-screen co-op mod - Windows patcher
# Applies the co-op patch to YOUR OWN copy of the game. Contains no game data.
#
#   Patch-TurokCoop.ps1 -InputPath <default.xbe | game folder | GOD folder> [-OutputPath <path>] [-InPlace]
#
# Input can be an Xbox game ISO (XISO or full redump-style image), an extracted default.xbe (or the folder holding it), or a GOD package
# (the 41430004 folder, its 00005000 folder, or the GOD header file).
# Without -InPlace the input is never modified:
#   ISO         -> <name>_coop.iso next to it (or -OutputPath)
#   default.xbe -> default_coop.xbe next to it (or -OutputPath)
#   GOD         -> the whole package is copied to .\GOD_coop\41430004 (or -OutputPath) and the copy is patched
# Works with Windows PowerShell 5.1 (built into Windows 10/11) and PowerShell 7.
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [string]$OutputPath,
    [switch]$InPlace,
    [string]$PatchFile
)
$ErrorActionPreference = 'Stop'
$BLOCK = 0x1000; $BPP = 0xA1C4; $BPS = 0xCC; $SUBPART = $BLOCK + $BPS * $BLOCK
$XDVD = @(0, 0x18300000, 0xFD90000, 0x2080000)
$sha = [System.Security.Cryptography.SHA1]::Create()
function Sha1([byte[]]$b) { return ,$sha.ComputeHash($b) }
function Hex([byte[]]$b) { return ([System.BitConverter]::ToString($b)).Replace('-', '').ToLower() }
function Same([byte[]]$a, [byte[]]$b) { return (Hex $a) -eq (Hex $b) }
function Fail($m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

if (-not $PatchFile) { $PatchFile = Join-Path $PSScriptRoot 'turok_evolution_coop_v1.0.tecp' }

# ---------------------------------------------------------------- patch file
$pd = [System.IO.File]::ReadAllBytes($PatchFile)
if ([System.Text.Encoding]::ASCII.GetString($pd, 0, 8) -ne 'TECOOP01') { Fail "not a co-op patch file: $PatchFile" }
$pSize = [System.BitConverter]::ToUInt32($pd, 8)
$pOld = New-Object byte[] 20; [Array]::Copy($pd, 12, $pOld, 0, 20)
$pNew = New-Object byte[] 20; [Array]::Copy($pd, 32, $pNew, 0, 20)
$n = [System.BitConverter]::ToUInt32($pd, 52)
$recs = New-Object System.Collections.ArrayList
$pos = 56
for ($i = 0; $i -lt $n; $i++) {
    $off = [System.BitConverter]::ToUInt32($pd, $pos); $len = [System.BitConverter]::ToUInt32($pd, $pos + 4); $pos += 8
    $d = New-Object byte[] $len; [Array]::Copy($pd, $pos, $d, 0, $len); $pos += $len
    [void]$recs.Add(@($off, $d))
}

function Patch-Xbe([byte[]]$xbe) {
    $h = Sha1 $xbe
    if ($xbe.Length -ne $pSize -or -not (Same $h $pOld)) {
        if (Same $h $pNew) { Fail 'this default.xbe already has the co-op mod.' }
        Fail ("default.xbe does not match the original Turok: Evolution (USA) XBE (expected SHA-1 {0}, got {1})." -f (Hex $pOld), (Hex $h))
    }
    $out = [byte[]]$xbe.Clone()
    foreach ($r in $recs) { [Array]::Copy($r[1], 0, $out, $r[0], $r[1].Length) }
    if (-not (Same (Sha1 $out) $pNew)) { Fail 'internal error: result hash mismatch' }
    return ,$out
}

# ---------------------------------------------------------------- GOD helpers
function Loc([int64]$b) {
    $part = [math]::Floor($b / $BPP); $r = $b % $BPP
    $sub = [math]::Floor($r / $BPS); $k = $r % $BPS
    return @([int]$part, [int]$sub, [int]$k, [int64]($BLOCK + $sub * $SUBPART + $BLOCK + $k * $BLOCK))
}
function PartPath($p) { return Join-Path $script:DataDir ('Data{0:D4}' -f [int]$p) }
function ReadAt($file, [int64]$off, [int]$len) {
    $fs = [System.IO.File]::OpenRead($file)
    try { [void]$fs.Seek($off, 'Begin'); $b = New-Object byte[] $len; $got = 0
          while ($got -lt $len) { $x = $fs.Read($b, $got, $len - $got); if ($x -le 0) { break }; $got += $x }
          return ,$b } finally { $fs.Close() }
}
function WriteAt($file, [int64]$off, [byte[]]$b) {
    $fs = [System.IO.File]::Open($file, 'Open', 'ReadWrite')
    try { [void]$fs.Seek($off, 'Begin'); $fs.Write($b, 0, $b.Length) } finally { $fs.Close() }
}
function GRead([int64]$off, [int]$n) {
    if ($script:IsoPath) {
        $b = ReadAt $script:IsoPath $off $n
        return ,$b
    }
    $out = New-Object byte[] $n; $done = 0
    while ($done -lt $n) {
        $b = [math]::Floor($off / $BLOCK); $o = [int]($off % $BLOCK)
        $l = Loc $b; $take = [math]::Min($n - $done, $BLOCK - $o)
        $chunk = ReadAt (PartPath $l[0]) ($l[3] + $o) $take
        [Array]::Copy($chunk, 0, $out, $done, $take)
        $off += $take; $done += $take
    }
    return ,$out
}
function Find-God($p) {
    $p = [System.IO.Path]::GetFullPath($p)
    if ((Test-Path $p -PathType Leaf) -and (Test-Path "$p.data" -PathType Container)) { return @($p, "$p.data") }
    foreach ($root in @($p, (Join-Path $p '00005000'))) {
        if (-not (Test-Path $root -PathType Container)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $root -File) {
            if (Test-Path ($f.FullName + '.data') -PathType Container) { return @($f.FullName, ($f.FullName + '.data')) }
        }
    }
    return $null
}
function Find-Xbe {
    foreach ($base in $XDVD) {
        try { $hdr = GRead ($base + 32 * 2048) 2048 } catch { continue }
        if ($hdr.Length -lt 20) { continue }
        if ([System.Text.Encoding]::ASCII.GetString($hdr, 0, 20) -ne 'MICROSOFT*XBOX*MEDIA') { continue }
        $rs = [System.BitConverter]::ToUInt32($hdr, 20); $rz = [System.BitConverter]::ToUInt32($hdr, 24)
        $tbl = GRead ($base + [int64]$rs * 2048) $rz
        $todo = New-Object System.Collections.Stack; $todo.Push(0); $seen = @{}
        while ($todo.Count) {
            $o = $todo.Pop()
            if ($seen.ContainsKey($o) -or ($o * 4 + 14) -gt $tbl.Length) { continue }
            $seen[$o] = 1
            $l = [System.BitConverter]::ToUInt16($tbl, $o * 4); $r = [System.BitConverter]::ToUInt16($tbl, $o * 4 + 2)
            if ($l -eq 0xFFFF) { continue }
            $sec = [System.BitConverter]::ToUInt32($tbl, $o * 4 + 4); $size = [System.BitConverter]::ToUInt32($tbl, $o * 4 + 8)
            $nl = $tbl[$o * 4 + 13]
            $name = [System.Text.Encoding]::ASCII.GetString($tbl, $o * 4 + 14, $nl)
            if ($name -ieq 'default.xbe') { return @(($base + [int64]$sec * 2048), [int]$size) }
            if ($l) { $todo.Push([int]$l) }; if ($r) { $todo.Push([int]$r) }
        }
    }
    return $null
}

function Patch-God($header) {
    $hit = Find-Xbe
    if (-not $hit) { Fail 'could not find default.xbe inside the GOD package.' }
    $start = $hit[0]; $size = $hit[1]
    $new = Patch-Xbe (GRead $start $size)
    $blocks = @{}
    foreach ($r in $recs) {
        $a = $start + $r[0]; $z = $a + $r[1].Length
        for ($b = [math]::Floor($a / $BLOCK); $b -le [math]::Floor(($z - 1) / $BLOCK); $b++) { $blocks[[int64]$b] = 1 }
    }
    $touched = @{}
    foreach ($b in ($blocks.Keys | Sort-Object)) {
        $blk = GRead ($b * $BLOCK) $BLOCK
        $lo = [math]::Max($start, $b * $BLOCK); $hi = [math]::Min($start + $size, ($b + 1) * $BLOCK)
        [Array]::Copy($new, [int]($lo - $start), $blk, [int]($lo - $b * $BLOCK), [int]($hi - $lo))
        $l = Loc $b
        WriteAt (PartPath $l[0]) $l[3] $blk
        $key = '{0}/{1}' -f $l[0], $l[1]
        if (-not $touched.ContainsKey($key)) { $touched[$key] = @{} }
        $touched[$key][$l[2]] = (Sha1 $blk)
    }
    $mht = @{}
    foreach ($key in $touched.Keys) {
        $pp = $key.Split('/'); $part = [int]$pp[0]; $sub = [int]$pp[1]
        $shOff = $BLOCK + $sub * $SUBPART
        $sh = ReadAt (PartPath $part) $shOff $BLOCK
        foreach ($k in $touched[$key].Keys) { [Array]::Copy($touched[$key][$k], 0, $sh, $k * 20, 20) }
        WriteAt (PartPath $part) $shOff $sh
        if (-not $mht.ContainsKey($part)) { $mht[$part] = @{} }
        $mht[$part][$sub] = (Sha1 $sh)
    }
    $top = [int](($mht.Keys | Measure-Object -Maximum).Maximum)
    $nxt = $null
    for ($p = $top; $p -ge 0; $p--) {
        $m = ReadAt (PartPath $p) 0 $BLOCK
        if ($mht.ContainsKey($p)) { foreach ($sub in $mht[$p].Keys) { [Array]::Copy($mht[$p][$sub], 0, $m, $sub * 20, 20) } }
        if ($nxt) { [Array]::Copy($nxt, 0, $m, 0xCB * 20, 20) }
        WriteAt (PartPath $p) 0 $m
        $nxt = Sha1 $m
    }
    $hb = [System.IO.File]::ReadAllBytes($header)
    [Array]::Copy($nxt, 0, $hb, 0x37D, 20)
    $body = New-Object byte[] 0xACBC; [Array]::Copy($hb, 0x344, $body, 0, 0xACBC)
    [Array]::Copy((Sha1 $body), 0, $hb, 0x32C, 20)
    [System.IO.File]::WriteAllBytes($header, $hb)
    if (-not (Same (Sha1 (GRead $start $size)) $pNew)) { Fail 'verification failed after writing.' }
}

# ---------------------------------------------------------------- main
$inp = [System.IO.Path]::GetFullPath($InputPath)
$xbe = $null
if ((Test-Path $inp -PathType Leaf) -and $inp.ToLower().EndsWith('.xbe')) { $xbe = $inp }
elseif (Test-Path (Join-Path $inp 'default.xbe') -PathType Leaf) { $xbe = Join-Path $inp 'default.xbe' }
if ($xbe) {
    if ($InPlace) { $out = $xbe } elseif ($OutputPath) { $out = [System.IO.Path]::GetFullPath($OutputPath) } else { $out = Join-Path (Split-Path $xbe) 'default_coop.xbe' }
    $data = Patch-Xbe ([System.IO.File]::ReadAllBytes($xbe))
    [System.IO.File]::WriteAllBytes($out, $data)
    Write-Host "Done: $out" -ForegroundColor Green
    exit 0
}
$god = Find-God $inp
if (-not $god -and (Test-Path $inp -PathType Leaf)) {
    # an Xbox game ISO (XISO or full redump-style image)
    $script:IsoPath = $inp
    $hit = Find-Xbe
    if (-not $hit) { Fail 'this file is not an Xbox game ISO (no Xbox file system found).' }
    [void](Patch-Xbe (GRead $hit[0] $hit[1]))          # check it is the right game before copying
    if ($InPlace) { $out = $inp }
    else {
        if ($OutputPath) { $out = [System.IO.Path]::GetFullPath($OutputPath) }
        else {
            $ext = [System.IO.Path]::GetExtension($inp); if (-not $ext) { $ext = '.iso' }
            $out = Join-Path (Split-Path $inp) ([System.IO.Path]::GetFileNameWithoutExtension($inp) + '_coop' + $ext)
        }
        if (Test-Path $out) { Fail "output file already exists: $out  (delete it first)" }
        Write-Host "Copying ISO to $out (please wait)..."
        Copy-Item -LiteralPath $inp -Destination $out
        (Get-Item -LiteralPath $out).IsReadOnly = $false
    }
    $script:IsoPath = $out
    $new = Patch-Xbe (GRead $hit[0] $hit[1])
    foreach ($r in $recs) { WriteAt $out ($hit[0] + $r[0]) $r[1] }
    if (-not (Same (Sha1 (GRead $hit[0] $hit[1])) $pNew)) { Fail 'verification failed after writing.' }
    Write-Host "Done: $out" -ForegroundColor Green
    exit 0
}
if (-not $god) { Fail "no Xbox ISO, default.xbe or GOD package found at $inp" }
$header = $god[0]
if (-not $InPlace) {
    $titleDir = Split-Path (Split-Path $header)
    if ($OutputPath) { $out = [System.IO.Path]::GetFullPath($OutputPath) } else { $out = Join-Path (Join-Path (Get-Location) 'GOD_coop') (Split-Path $titleDir -Leaf) }
    if (Test-Path $out) { Fail "output folder already exists: $out  (delete it first)" }
    Write-Host "Copying GOD package to $out (a few GB, please wait)..."
    New-Item -ItemType Directory -Path (Split-Path $out) -Force | Out-Null
    Copy-Item -LiteralPath $titleDir -Destination $out -Recurse
    Get-ChildItem -LiteralPath $out -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
    $header = Join-Path $out ($header.Substring($titleDir.Length).TrimStart('\', '/'))
}
$script:DataDir = "$header.data"
Write-Host 'Patching...'
Patch-God $header
Write-Host ("Done: " + (Split-Path (Split-Path $header))) -ForegroundColor Green
