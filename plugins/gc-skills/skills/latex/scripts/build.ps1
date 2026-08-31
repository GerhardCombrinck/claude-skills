<#
.SYNOPSIS
  Compile a LaTeX file to PDF, with the house style directory on TEXINPUTS and
  the bundled fonts on OSFONTDIR. Cleans up aux files on success.

.EXAMPLE
  .\build.ps1 week02_running.tex
  .\build.ps1 C:\path\doc.tex -KeepAux
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TexFile,

    # Keep .aux/.log/.out instead of deleting them
    [switch]$KeepAux,

    # Force a second pass (needed for \ref, \tableofcontents, some tikz externalise)
    [switch]$Twice,

    # Emit .synctex.gz and keep it, so an editor can jump between source and PDF
    [switch]$SyncTeX,

    # Engine override. Default lualatex — house.tex uses fontspec/OTF.
    [ValidateSet('lualatex','xelatex','pdflatex')]
    [string]$Engine = 'lualatex',

    # Skip the post-build quality report (overfull boxes, bitmap fonts,
    # unresolved refs). The report is silent when there is nothing to say.
    [switch]$NoCheck
)

$ErrorActionPreference = 'Stop'

# ---- ENGINE LOOKUP ------------------------------------------
# Order: $env:LATEX_BIN, the default MiKTeX user install, then PATH.
$candidates = @()
if ($env:LATEX_BIN) { $candidates += (Join-Path $env:LATEX_BIN "$Engine.exe") }
$candidates += (Join-Path "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64" "$Engine.exe")

$TexBin = $null
foreach ($c in $candidates) { if (Test-Path $c) { $TexBin = $c; break } }
if (-not $TexBin) { $TexBin = (Get-Command $Engine -ErrorAction SilentlyContinue).Source }
if (-not $TexBin) {
    throw "$Engine not found. Install MiKTeX (winget install MiKTeX.MiKTeX --scope user) or TeX Live, or set `$env:LATEX_BIN to the directory holding $Engine.exe."
}
$MiktexBin = Split-Path -Parent $TexBin

# ---- PATHS --------------------------------------------------
$StyleDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'style'
$FontDir  = Join-Path $StyleDir 'fonts'

if (-not (Test-Path $TexFile))  { throw "TeX file not found: $TexFile" }
if (-not (Test-Path $StyleDir)) { throw "House style directory missing: $StyleDir" }

$tex     = Get-Item $TexFile
$workDir = $tex.DirectoryName
$base    = [IO.Path]::GetFileNameWithoutExtension($tex.Name)
$pdf     = Join-Path $workDir "$base.pdf"
$log     = Join-Path $workDir "$base.log"

# Make \input{house} resolve. Trailing ';' preserves the default search path.
$env:TEXINPUTS = "$StyleDir;"
# Make the bundled OTFs findable, so no font install is needed.
# OPENTYPEFONTS is the one that matters: house.tex uses fontspec's Extension=.otf,
# which is a kpathsea *filename* lookup. OSFONTDIR only feeds the system font-name
# index, so it is set too, for anyone who switches to \setmainfont{Family Name}.
if (Test-Path $FontDir) {
    $env:OPENTYPEFONTS = if ($env:OPENTYPEFONTS) { "$FontDir;$env:OPENTYPEFONTS" } else { "$FontDir;" }
    $env:OSFONTDIR     = if ($env:OSFONTDIR)     { "$FontDir;$env:OSFONTDIR" }     else { "$FontDir;" }
}

Push-Location $workDir
try {
    # Windows PowerShell 5.1 turns native-command stderr into a terminating error
    # under 'Stop'. TeX writes harmless warnings to stderr, so relax it here;
    # correctness is enforced by $LASTEXITCODE checks below.
    $ErrorActionPreference = 'Continue'

    # --enable-installer is MiKTeX-only; TeX Live errors on the unknown flag.
    $extra = @()
    if (Test-Path (Join-Path $MiktexBin 'miktex.exe')) { $extra += '--enable-installer' }
    if ($SyncTeX) { $extra += '-synctex=1' }

    $passes = if ($Twice) { 2 } else { 1 }

    for ($i = 1; $i -le $passes; $i++) {
        & $TexBin -interaction=nonstopmode -halt-on-error @extra $tex.Name 2>&1 | Out-Null
        $code = $LASTEXITCODE
        if ($code -ne 0) { break }
    }

    # Build the index if the document declared one, then rerun to place it
    $idx = Join-Path $workDir "$base.idx"
    if ($code -eq 0 -and (Test-Path $idx)) {
        $makeindex = (Get-Command (Join-Path $MiktexBin 'makeindex.exe') -ErrorAction SilentlyContinue).Source
        if (-not $makeindex) { $makeindex = (Get-Command makeindex -ErrorAction SilentlyContinue).Source }
        if ($makeindex) {
            & $makeindex $idx 2>&1 | Out-Null
            & $TexBin -interaction=nonstopmode -halt-on-error @extra $tex.Name 2>&1 | Out-Null
            $code = $LASTEXITCODE
        }
    }

    # Auto-rerun if LaTeX asks for it (cross-refs, TOC, tikz) — up to 3 times
    $rerun = 0
    while ($code -eq 0 -and $rerun -lt 3 -and (Test-Path $log) -and
           (Select-String -Path $log -Pattern 'Rerun to get|Rerun LaTeX|Table of Contents has changed' -Quiet)) {
        & $TexBin -interaction=nonstopmode -halt-on-error @extra $tex.Name 2>&1 | Out-Null
        $code = $LASTEXITCODE
        $rerun++
    }

    if ($code -ne 0) {
        Write-Host "COMPILE FAILED" -ForegroundColor Red
        if (Test-Path $log) {
            # The '!' lines are the actual errors; the l.NNN lines locate them.
            Select-String -Path $log -Pattern '^!|^l\.\d+' |
                Select-Object -First 12 |
                ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Yellow }
            Write-Host "  full log: $log" -ForegroundColor DarkGray
        }
        exit 1
    }

    # ---- QUALITY REPORT -------------------------------------
    # Runs before cleanup, because it reads the log. Silent when clean, so it
    # costs nothing on a good build and is impossible to forget on a bad one.
    if (-not $NoCheck -and (Test-Path $log)) {
        $logText = Get-Content $log -Raw -ErrorAction SilentlyContinue

        # Overfull boxes under 1pt are invisible; don't report noise.
        $over = ([regex]::Matches($logText, 'Overfull \\hbox \((\d+(?:\.\d+)?)pt') |
                 Where-Object { [double]$_.Groups[1].Value -ge 1.0 }).Count

        # A .pk reference means a bitmap font was generated and embedded. On a
        # modern engine that always signals a font package that failed to
        # resolve to its Type1/OTF outlines, and it looks furry in every viewer.
        $bitmap = ([regex]::Matches($logText, '\.pk>')).Count

        # Patterns deliberately avoid quote and backtick characters: the log wraps
        # them around the label name, and matching them here is a quoting minefield.
        $undef  = ([regex]::Matches($logText, 'Reference .{1,80}? undefined on input line')).Count
        $shape  = ([regex]::Matches($logText, 'Font shape .{1,60}? undefined')).Count

        $issues = @()
        if ($over)   { $issues += "$over overfull box(es) over 1pt" }
        if ($bitmap) { $issues += "bitmap fonts in use ($bitmap) - a font failed to resolve" }
        if ($undef)  { $issues += "$undef undefined reference(s)" }
        if ($shape)  { $issues += "$shape substituted font shape(s)" }

        if ($issues) {
            Write-Host "QUALITY" -ForegroundColor Yellow
            foreach ($i in $issues) { Write-Host "  ! $i" -ForegroundColor Yellow }
            Write-Host "  rebuild with -KeepAux and read $base.log for locations" -ForegroundColor DarkGray
        }
    }

    if (-not $KeepAux) {
        # .synctex.gz is the one aux file worth keeping when asked for: deleting it is
        # what breaks double-click navigation between the PDF and the source.
        $junk = 'aux','log','out','toc','lof','lot','nav','snm','fls','fdb_latexmk','idx','ilg','ind'
        if (-not $SyncTeX) { $junk += 'synctex.gz' }
        foreach ($ext in $junk) {
            Remove-Item (Join-Path $workDir "$base.$ext") -ErrorAction SilentlyContinue
        }
        # multi-file documents leave one .aux per \input'd file
        Get-ChildItem $workDir -Recurse -Filter '*.aux' -ErrorAction SilentlyContinue |
            Remove-Item -ErrorAction SilentlyContinue
    }

    $info  = Get-Item $pdf
    $pages = 0
    try {
        # crude but dependency-free page count. GetEncoding(28591) is latin-1 and
        # exists on both Windows PowerShell 5.1 and PowerShell 7 — [Text.Encoding]::Latin1
        # is PS7-only and silently costs the page count when TeXworks calls powershell.exe.
        $raw   = [IO.File]::ReadAllText($pdf, [Text.Encoding]::GetEncoding(28591))
        $pages = ([regex]::Matches($raw, '/Type\s*/Page[^s]')).Count
    } catch { }

    Write-Host "OK  $($info.Name)  $([math]::Round($info.Length/1KB)) KB$(if($pages){"  $pages page(s)"})" -ForegroundColor Green
    Write-Output $pdf
}
finally {
    Pop-Location
}
