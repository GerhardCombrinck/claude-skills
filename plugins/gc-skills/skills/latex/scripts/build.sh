#!/usr/bin/env bash
# Compile a LaTeX file to PDF, with the house style directory on TEXINPUTS and
# the bundled fonts on OSFONTDIR. Cleans up aux files on success.
#
#   ./build.sh week02_running.tex
#   ./build.sh ~/path/doc.tex --keep-aux
#   ./build.sh doc.tex --engine xelatex
#   ./build.sh doc.tex --synctex          # for editor source <-> PDF navigation
#
# macOS/Linux counterpart of build.ps1. Same flags, same output.

set -euo pipefail

TEXFILE=""
KEEP_AUX=0
TWICE=0
SYNCTEX=0
NO_CHECK=0
ENGINE="lualatex"

while [ $# -gt 0 ]; do
  case "$1" in
    --keep-aux) KEEP_AUX=1; shift ;;
    --twice)    TWICE=1; shift ;;
    --synctex)  SYNCTEX=1; shift ;;
    --no-check) NO_CHECK=1; shift ;;
    --engine)   ENGINE="$2"; shift 2 ;;
    -h|--help)  sed -n '2,10p' "$0"; exit 0 ;;
    -*)         echo "unknown flag: $1" >&2; exit 2 ;;
    *)          TEXFILE="$1"; shift ;;
  esac
done

[ -n "$TEXFILE" ] || { echo "usage: build.sh <file.tex> [--keep-aux] [--twice] [--synctex] [--no-check] [--engine ENGINE]" >&2; exit 2; }

case "$ENGINE" in
  lualatex|xelatex|pdflatex) ;;
  *) echo "engine must be lualatex, xelatex or pdflatex" >&2; exit 2 ;;
esac

# ---- ENGINE LOOKUP ------------------------------------------
# $LATEX_BIN wins; otherwise PATH, with the usual MacTeX location as a fallback
# because GUI-launched shells often miss /Library/TeX/texbin.
TEXBIN=""
if [ -n "${LATEX_BIN:-}" ] && [ -x "$LATEX_BIN/$ENGINE" ]; then
  TEXBIN="$LATEX_BIN/$ENGINE"
elif command -v "$ENGINE" >/dev/null 2>&1; then
  TEXBIN="$(command -v "$ENGINE")"
elif [ -x "/Library/TeX/texbin/$ENGINE" ]; then
  TEXBIN="/Library/TeX/texbin/$ENGINE"
fi

if [ -z "$TEXBIN" ]; then
  echo "$ENGINE not found. Install MacTeX (brew install --cask mactex-no-gui) or TeX Live" >&2
  echo "(apt install texlive-luatex texlive-latex-extra texlive-fonts-extra), or set LATEX_BIN." >&2
  exit 1
fi

# ---- PATHS --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STYLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/style"
FONT_DIR="$STYLE_DIR/fonts"

[ -f "$TEXFILE" ]   || { echo "TeX file not found: $TEXFILE" >&2; exit 1; }
[ -d "$STYLE_DIR" ] || { echo "House style directory missing: $STYLE_DIR" >&2; exit 1; }

TEX_ABS="$(cd "$(dirname "$TEXFILE")" && pwd)/$(basename "$TEXFILE")"
WORK_DIR="$(dirname "$TEX_ABS")"
BASE="$(basename "$TEX_ABS")"; BASE="${BASE%.tex}"
PDF="$WORK_DIR/$BASE.pdf"
LOG="$WORK_DIR/$BASE.log"

HAVE_FONTS=0
[ -d "$FONT_DIR" ] && HAVE_FONTS=1

# Under Git Bash/MSYS the TeX binary is a native Windows program: it cannot read
# /c/... paths, and ';' is its list separator because ':' follows a drive letter.
if command -v cygpath >/dev/null 2>&1; then
  SEP=";"
  STYLE_DIR="$(cygpath -w "$STYLE_DIR")"
  FONT_DIR="$(cygpath -w "$FONT_DIR")"
else
  SEP=":"
fi

# Make \input{house} resolve. Trailing separator preserves the default search path.
export TEXINPUTS="$STYLE_DIR$SEP"
# Make the bundled OTFs findable, so no font install is needed.
# OPENTYPEFONTS is the one that matters: house.tex uses fontspec's Extension=.otf,
# which is a kpathsea *filename* lookup. OSFONTDIR only feeds the system font-name
# index, so it is set too, for anyone who switches to \setmainfont{Family Name}.
if [ "$HAVE_FONTS" -eq 1 ]; then
  export OPENTYPEFONTS="$FONT_DIR$SEP${OPENTYPEFONTS:-}"
  export OSFONTDIR="$FONT_DIR$SEP${OSFONTDIR:-}"
fi

cd "$WORK_DIR"

# --enable-installer is MiKTeX-only; TeX Live rejects the unknown flag.
EXTRA=()
if command -v miktex >/dev/null 2>&1; then EXTRA+=(--enable-installer); fi
if [ "$SYNCTEX" -eq 1 ]; then EXTRA+=(-synctex=1); fi

run_tex() {
  "$TEXBIN" -interaction=nonstopmode -halt-on-error "${EXTRA[@]+"${EXTRA[@]}"}" "$BASE.tex" >/dev/null 2>&1
}

CODE=0
PASSES=1
[ "$TWICE" -eq 1 ] && PASSES=2
for _ in $(seq 1 $PASSES); do
  run_tex || CODE=$?
  [ "$CODE" -ne 0 ] && break
done

# Build the index if the document declared one, then rerun to place it
if [ "$CODE" -eq 0 ] && [ -f "$WORK_DIR/$BASE.idx" ] && command -v makeindex >/dev/null 2>&1; then
  makeindex "$WORK_DIR/$BASE.idx" >/dev/null 2>&1 || true
  run_tex || CODE=$?
fi

# Auto-rerun if LaTeX asks for it (cross-refs, TOC, tikz) — up to 3 times
RERUN=0
while [ "$CODE" -eq 0 ] && [ "$RERUN" -lt 3 ] && [ -f "$LOG" ] && \
      grep -qE 'Rerun to get|Rerun LaTeX|Table of Contents has changed' "$LOG"; do
  run_tex || CODE=$?
  RERUN=$((RERUN + 1))
done

if [ "$CODE" -ne 0 ]; then
  echo "COMPILE FAILED"
  if [ -f "$LOG" ]; then
    # The '!' lines are the actual errors; the l.NNN lines locate them.
    grep -aE '^!|^l\.[0-9]+' "$LOG" | head -12 | sed 's/^/  /'
    echo "  full log: $LOG"
  fi
  exit 1
fi

# ---- QUALITY REPORT -----------------------------------------
# Runs before cleanup, because it reads the log. Silent when clean, so it costs
# nothing on a good build and is impossible to forget on a bad one.
if [ "$NO_CHECK" -eq 0 ] && [ -f "$LOG" ]; then
  # Overfull boxes under 1pt are invisible; don't report noise.
  # The braces matter: under `set -o pipefail` a grep that matches nothing exits 1
  # and takes the whole assignment, and the build, down with it. A clean document
  # is exactly the case where these greps find nothing.
  OVER=$( { grep -ao 'Overfull \\hbox ([0-9.]*pt' "$LOG" 2>/dev/null || true; } \
         | sed 's/.*(\([0-9.]*\)pt/\1/' \
         | awk '$1 >= 1.0' | wc -l | tr -d ' ')
  # A .pk reference means a bitmap font was generated and embedded. That always
  # signals a font package that failed to resolve to its outlines, and it looks
  # furry in every viewer.
  BITMAP=$(grep -ac '\.pk>' "$LOG" 2>/dev/null || true)
  UNDEF=$(grep -ac "Reference \`.*' on page" "$LOG" 2>/dev/null || true)
  SHAPE=$(grep -ac "Font shape \`.*' undefined" "$LOG" 2>/dev/null || true)

  ISSUES=""
  [ "${OVER:-0}"   -gt 0 ] && ISSUES="$ISSUES\n  ! $OVER overfull box(es) over 1pt"
  [ "${BITMAP:-0}" -gt 0 ] && ISSUES="$ISSUES\n  ! bitmap fonts in use ($BITMAP), a font failed to resolve"
  [ "${UNDEF:-0}"  -gt 0 ] && ISSUES="$ISSUES\n  ! $UNDEF undefined reference(s)"
  [ "${SHAPE:-0}"  -gt 0 ] && ISSUES="$ISSUES\n  ! $SHAPE substituted font shape(s)"

  if [ -n "$ISSUES" ]; then
    echo "QUALITY"
    printf '%b\n' "${ISSUES#\\n}"
    echo "  rebuild with --keep-aux and read $BASE.log for locations"
  fi
fi

if [ "$KEEP_AUX" -eq 0 ]; then
  # .synctex.gz is the one aux file worth keeping when asked for: deleting it is
  # what breaks double-click navigation between the PDF and the source.
  JUNK="aux log out toc lof lot nav snm fls fdb_latexmk idx ilg ind"
  [ "$SYNCTEX" -eq 0 ] && JUNK="$JUNK synctex.gz"
  for ext in $JUNK; do
    rm -f "$WORK_DIR/$BASE.$ext"
  done
  # multi-file documents leave one .aux per \input'd file
  find "$WORK_DIR" -name '*.aux' -delete 2>/dev/null || true
fi

KB=$(( ($(wc -c < "$PDF") + 512) / 1024 ))
# crude but dependency-free page count
PAGES=$(grep -ao '/Type[[:space:]]*/Page[^s]' "$PDF" | wc -l | tr -d ' ')

if [ "$PAGES" -gt 0 ] 2>/dev/null; then
  echo "OK  $(basename "$PDF")  ${KB} KB  ${PAGES} page(s)"
else
  echo "OK  $(basename "$PDF")  ${KB} KB"
fi
echo "$PDF"
