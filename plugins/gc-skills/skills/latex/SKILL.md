---
name: latex
description: Compile LaTeX documents to PDF with MiKTeX or TeX Live via LuaLaTeX, using a shared house style (Source Sans 3 via fontspec, muted palette, booktabs tables). Use when the user asks for a LaTeX document or PDF, wants to build/compile a .tex file, wants to restyle or change fonts in existing LaTeX docs, or invokes /latex. Also use when producing any printable one-pager, report, plan sheet, or table-heavy handout where a PDF is the deliverable.
---

# LaTeX

Compiles `.tex` to PDF and applies a single shared house style.

## Quick start

The build script lives next to this file, at `scripts/build.ps1` (Windows) or
`scripts/build.sh` (macOS/Linux). **Resolve it against this skill's own directory** —
under a plugin install that is `<plugin root>/skills/latex/scripts/`, under a manual
install `~/.claude/skills/latex/scripts/`. If `$env:CLAUDE_PLUGIN_ROOT` is set, prefer it.

```powershell
& "<skill dir>\scripts\build.ps1" mydoc.tex
```

```bash
"<skill dir>/scripts/build.sh" mydoc.tex
```

Prints `OK mydoc.pdf 257 KB 1 page(s)` and deletes aux files. On failure it prints the
`!` error lines and the `l.NNN` locations, and leaves the log in place.

Flags: `-KeepAux` / `--keep-aux` (keep .aux/.log), `-Twice` / `--twice` (force two
passes for `\ref`/TOC), `-SyncTeX` / `--synctex` (emit and keep `.synctex.gz` for editor
source ↔ PDF navigation), `-Engine` / `--engine` `xelatex|pdflatex` (default `lualatex`),
`-NoCheck` / `--no-check` (skip the quality report).

After a successful build the script prints a `QUALITY` block if the log shows overfull
boxes, bitmap fonts, unresolved references or substituted font shapes. It stays silent
when there is nothing to report. Treat any of them as unfinished work in a document you
are handing over, and look at the output at 400–600 dpi before calling it done:
[REFERENCE.md](REFERENCE.md).

**Always build through this script.** It sets `TEXINPUTS` so `\input{house}` resolves,
sets `OPENTYPEFONTS` so the bundled fonts resolve without being installed, and picks the
engine the house style needs. First run on a new machine is slow while LuaLaTeX builds
its font cache.

If the script cannot find the engine, set `LATEX_BIN` to the directory holding it
(`$env:LATEX_BIN` on Windows). Otherwise it looks in the default MiKTeX user install,
then on `PATH`, then `/Library/TeX/texbin` on macOS.

## Writing a document

Set `geometry` yourself (margins differ per document), then `\input{house}`.
Do **not** re-declare packages or colours the house style already provides.

Start every document with the `% !TeX program` line. It costs nothing when building
through the script, and it stops a GUI editor or Overleaf from trying pdfLaTeX, which
cannot load fontspec.

```latex
% !TeX program = lualatex
\documentclass[11pt,a4paper]{article}
\usepackage[margin=13mm,top=11mm,bottom=12mm]{geometry}
\input{house}

\housefoot{Project name \textbullet\ Section}{Author name}

\begin{document}
\housetitle{Document Title}{Subtitle line}

\begin{housebox}
The one thing that matters on this page.
\end{housebox}

\section*{A section}
\begin{tabularx}{\linewidth}{@{}l X c@{}}
\toprule
\textbf{Day} & \textbf{Detail} & \textbf{\cb} \\
\midrule
\rowcolor{gymbg}
Mon & Something shaded & \cb \\
Tue & Something plain  & \cb \\
\bottomrule
\end{tabularx}

\housenote{Small muted footnote text.}
\end{document}
```

For landscape one-pagers use `\documentclass[10pt,a4paper,landscape]` and
`\housetitlewide{Title}{Right-aligned subtitle}`.

## What house.tex provides

| | |
|---|---|
| Engine | **LuaLaTeX** (fontspec needs it — not pdflatex) |
| Font | Source Sans 3, bundled in `style/fonts/`, loaded as OTF via `fontspec`. Bold is Semibold. |
| Colours | `ink` `muted` `accent` `rulegrey`; row tints `restbg` `gymbg` `racebg`; phases `p0`–`p4` |
| Packages | xcolor(table), booktabs, tabularx, array, enumitem, amssymb, ulem, fancyhdr, titlesec, tcolorbox, pgfplots, hyperref |
| Macros | `\housetitle` `\housetitlewide` `\housefoot` `\housenote` `\housemeta` `\housetoc` `\cb` `\pdot{p2}` `L{}` column |
| Boxes | `housebox` (loud, accent frame), `houseinfo` (calm), `housewarn` (attention). The last two take an optional title |
| Long docs | chapter styling (guarded to report/book), `float` for `figure[H]`, styled captions |
| Diagrams | TikZ kit: `dgbox` `dgterm` `dgask` `dgflow` `dgstub` `dgtag` |

**All styling lives in [style/house.tex](style/house.tex).** Edit that one file to restyle
every document. Font alternatives are listed as commented lines at the top of it.

## Beyond the one-pager

- **[LONGDOC.md](LONGDOC.md)** — manuals and handbooks: the `report` skeleton, callouts,
  when `tabular` beats `longtable`, and the quality gate before handover.
- **[DIAGRAMS.md](DIAGRAMS.md)** — flowcharts: the node kit, and the layout rules that
  decide whether a diagram looks deliberate (top-aligning rows, `-|` versus `|-`,
  rejoining branches, where labels go).

## House writing rules

- **Never use em dashes.** `---` is banned in every document built with this skill, and
  so is a literal `—`. Rewrite with a comma, a colon, parentheses, or a full stop. In a
  table cell meaning "nothing", use `--` (en dash) or `n/a`, never `---`. Verify before
  shipping: `grep -rn -- '---' *.tex sections/*.tex` should return nothing.

## Rules that avoid the common failures

- `\rowcolor` needs `[table]` on xcolor — house.tex already does this. Don't load plain `xcolor`.
- `\blacksquare`/`\square` need `amssymb` — already loaded. Don't redeclare.
- `\newline` inside a table only works in a paragraph column (`p{}`, `X`), never in `l`/`c`/`r`.
- `geometry` is **not** in house.tex on purpose. Every document sets its own.
- Charts: pgfplots is preloaded. Use `ybar` with one `\addplot` per colour group.
- Never add `fontenc`/`inputenc` — LuaLaTeX is native UTF-8 and they break fontspec.
- Don't switch to pdflatex for a document using house.tex; fontspec will error out.

## Multi-file books

The build script handles `\tableofcontents`, `\printindex` and cross-references: it runs
`makeindex` when a `.idx` appears and re-runs the engine until references settle
(up to 3 passes), then cleans every `.aux` in the tree.

Structure a book as a master file plus content directories (`frontmatter/`, `chapters/`,
`back/`, `images/`) and a local `style.tex` that inputs `house` and adds book-specific
macros. Project-specific structure belongs in that local file; only the global look
belongs in `house.tex`.

Useful pattern for a book that grows: define a `\photoplate{path}{caption}` macro that
renders a dashed placeholder showing the awaited filename when the image is missing, so
the document always compiles before the photos exist.

## Building from a GUI editor

TeXworks, TeXstudio and VS Code launch LuaLaTeX with a bare environment, so
`\input{house}` fails and every house macro comes back undefined. See
[EDITORS.md](EDITORS.md) for the TeXworks setup (and the VS Code and Overleaf
equivalents). Short version: point the editor's typesetting tool at
`scripts/build.ps1` rather than at `lualatex`.

## Details

See [REFERENCE.md](REFERENCE.md) for the chart recipe, table patterns, and
troubleshooting compile errors.
