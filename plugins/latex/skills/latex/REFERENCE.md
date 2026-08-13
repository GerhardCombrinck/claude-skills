# LaTeX skill — reference

## Changing the house font

Edit `\setmainfont` in the FONT block of [style/house.tex](style/house.tex). Every
document picks it up on the next build.

Fonts load as OTF through `fontspec` under LuaLaTeX, so **no font-map setup is ever
needed** — that was a deliberate choice after `pdflatex` + `sourcesanspro` failed to
register its map (`Font SourceSans3-Bold-tlf-t1--base not found`, `miktex-makemf did
not succeed`), which is not reliably fixable with `initexmf --mkmaps` or
`miktex fontmaps configure`. Don't go back to pdflatex + a font package.

| `\setmainfont{...}` | Result |
|---|---|
| `SourceSans3` + `Extension=.otf` | **current** — neutral humanist sans, bundled in `style/fonts/` |
| `texgyreheros` | Helvetica clone, present in every TeX distribution |
| `texgyrepagella` | Palatino-ish serif, present in every TeX distribution |
| `Segoe UI` / `Helvetica Neue` | any system-installed font, by name, no Extension needed |

Two ways to name a font:

- **By file**, for fonts in the TeX tree or on `OPENTYPEFONTS`: needs `Extension=.otf`
  and the `*-Regular` style pattern, as the current block does.
- **By family name**, for fonts installed in the OS: `\setmainfont{Segoe UI}` alone.
  Simpler, but only works for system-installed fonts, so it is not portable.

## Bundled fonts

`style/fonts/` carries the six Source Sans 3 OTFs the house style uses (Regular,
Semibold, Bold and their italics), under the SIL Open Font License. The build script
prepends that directory to `OPENTYPEFONTS`, so LuaLaTeX finds them on a machine where
the font was never installed, and no `Path=` is needed in house.tex.

`OPENTYPEFONTS` is the kpathsea variable for OTF *filename* lookups, which is what
`Extension=.otf` triggers. `OSFONTDIR` does **not** work for this — it only feeds the
system font-name index. The script sets both, but only the first one matters unless you
switch house.tex to family-name lookup.

Consequence: **building by hand, outside the script, can fail with
`Package fontspec Error: The font "SourceSans3" cannot be found`** on a machine that
lacks the font. Either build through the script, or set `OPENTYPEFONTS` to
`style/fonts` yourself.

To add a weight, drop the OTF in `style/fonts/` and reference it by its `*-Weight`
suffix. To drop the bundle entirely, switch `\setmainfont` to `texgyreheros`.

Bold is mapped to **Semibold** deliberately — Source Sans Bold is too heavy in dense
tables. Change `BoldFont` to `*-Bold` if you want the heavier weight.

Maths glyphs (`\square`, `\geq`) still render in Latin Modern Math. That is fine and
usually invisible in these documents.

## Links and PDF bookmarks

`hyperref` is loaded **last** in house.tex — it must come after nearly everything.
Any package that has to load *after* hyperref (`imakeidx`, `cleveref`) goes in the
document's own style file, which inputs house first. Get this order wrong and you get
broken index links or a missing bookmark tree.

What it gives every document automatically: clickable TOC and index, PDF bookmarks
(parts → chapters → sections → subsections), and the bookmark pane open on launch.

```latex
\housemeta{Document Title}{Author Name}{Subject line}   % PDF metadata
```

**Starred headings need `\housetoc`, not `\addcontentsline`:**

```latex
\chapter*{Preface}
\housetoc{chapter}{Preface}     % = \phantomsection + \addcontentsline
```

Without the `\phantomsection` that `\housetoc` inserts, the bookmark points at the
*previous* page. This is silent — nothing warns you, the link is just wrong.

**For print**, swap `colorlinks=true` for `hidelinks` in the hyperref options: links
stay live on screen but render plain black on paper.

**Verifying bookmarks exist** — titles live in compressed object streams, so grepping
the PDF finds nothing. Build with `-KeepAux` and read the `.out` file, which lists the
whole tree in plain text with `[level]` prefixes. (`--keep-aux` on the shell script.)

## Chart recipe (pgfplots)

Bar chart with one colour per group, used for the training volume plot:

```latex
\begin{tikzpicture}
\begin{axis}[
  width=272mm, height=68mm,
  ybar, bar width=3.1pt,
  ymin=0, ymax=60, xmin=0, xmax=55.5,
  ylabel={\small km / week}, ylabel near ticks,
  xtick={1,6,12,18,24,30}, ytick={0,10,20,30,40,50},
  ymajorgrids=true, grid style={rulegrey,line width=0.4pt},
  axis lines*=left, tick style={draw=none},
  tick label style={font=\footnotesize,color=muted},
  label style={color=muted}, clip=false,
]
\addplot[fill=p1,draw=none] coordinates {(1,26)(2,29)(3,32)};
\addplot[only marks,mark=star,mark size=3pt,draw=p4,fill=p4] coordinates {(3,36)};
\node[font=\scriptsize\bfseries,color=p4] at (axis cs:3,40) {LABEL};
\draw[rulegrey,line width=0.6pt] (axis cs:6.5,0) -- (axis cs:6.5,54);
\end{axis}
\end{tikzpicture}
```

`clip=false` is what lets labels sit above the plot area. Phase dividers are plain
`\draw` lines in `axis cs:` coordinates.

## Table patterns

**Two-column reference blocks side by side:**

```latex
\begin{minipage}[t]{0.48\linewidth}
  ... left ...
\end{minipage}
\hfill
\begin{minipage}[t]{0.52\linewidth}
  ... right ...
\end{minipage}
```

**Shaded rows** — put `\rowcolor{gymbg}` immediately before the row content.
Shading applies to the whole row including the `@{}` edges.

**Blank log grid** — use `\midrule` between every row instead of `\addlinespace`,
so it reads as a form to write in rather than a table to read.

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Undefined control sequence` at `\end{tabularx}` | a macro inside the table isn't defined — usually `\newline` in an `l`/`c`/`r` column, or a missing package | change the column to `p{}`/`X`; check amssymb/xcolor are from house.tex |
| `\rowcolor` undefined | plain `xcolor` loaded somewhere before house.tex | remove it; house.tex loads `[table]{xcolor}` |
| `Option clash for package xcolor` | document loads xcolor itself | delete that line, house.tex owns it |
| `File 'house.tex' not found` | not building through the build script | use the script, or set `TEXINPUTS` to the style dir |
| `The font "SourceSans3" cannot be found` | not building through the build script, so `OPENTYPEFONTS` is unset and the font is not installed | use the script, or set `OPENTYPEFONTS` to `style/fonts` |
| `Package fontspec Error: The fontspec package requires either XeTeX or LuaTeX` | built with `-Engine pdflatex` | drop the flag; default lualatex is correct |
| `Font ...-tlf-t1--base not found` / `miktex-makemf did not succeed` | a pdflatex-era font package with an unregistered map | not fixable via `initexmf --mkmaps` or `miktex fontmaps configure` — use fontspec/OTF instead |
| `lualatex: command not found` / `not found at ...` | TeX not installed, or not on `PATH` for a GUI-launched shell | install MiKTeX or MacTeX/TeX Live, or set `LATEX_BIN` to the directory holding the engine |
| First LuaLaTeX build is slow | luaotfload building its font cache | one-off; later builds are fast |
| Output is 2 pages when you wanted 1 | genuine overflow | reduce `\arraystretch`, shrink `geometry` margins, or accept the split and put the log grid on page 2 |
| `Missing } inserted` at `\end{tabularx}` | **a `\begin{tabularx}` opened in one macro and closed in another** — tabularx reads its body whole and cannot be split across an environment definition | build the layout from `minipage` boxes separated by `\hfill` instead |
| `Missing } inserted` at `\end{tabularx}`, list involved | `itemize`/`enumerate` inside a table cell | move the list out of the table, or wrap the cell content in a `minipage` |
| Fonts look like default LaTeX | `\input{house}` missing or placed before `\documentclass` | it goes after `\documentclass` and after `geometry` |

Read the full log with `-KeepAux` / `--keep-aux` when the summarised errors aren't enough.

## Adding a new document

1. Copy the skeleton from [SKILL.md](SKILL.md).
2. Set `geometry` for the page shape you want.
3. Build with `scripts/build.ps1` (Windows) or `scripts/build.sh` (macOS/Linux).
4. If it needs a new colour or macro, add it to `house.tex` rather than the document —
   that keeps every document consistent and restylable from one file.
