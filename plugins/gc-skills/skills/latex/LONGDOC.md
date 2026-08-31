# Manuals, handbooks and other long documents

The default house document is a one-page `article`. This file covers the other
shape: a `report`-class document with chapters, figures, callouts and reference
appendices, of the kind you hand to a client.

## Skeleton

```latex
% !TeX program = lualatex
\documentclass[11pt,a4paper,oneside]{report}
\usepackage[margin=2.6cm,top=2.4cm,bottom=2.6cm]{geometry}
\input{house}

\housemeta{Product Manual}{Author Name}{What this document is}

\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrule}{\hbox to\headwidth{\color{rulegrey}%
  \leaders\hrule height 0.4pt\hfill}}
\fancyhead[L]{\footnotesize\color{muted}Product \textbullet\ User Manual}
\fancyhead[R]{\footnotesize\color{muted}\thepage}
\fancypagestyle{plain}{\fancyhf{}\renewcommand{\headrulewidth}{0pt}%
  \fancyfoot[C]{\footnotesize\color{muted}\thepage}}

\begin{document}
\begin{titlepage} ... \end{titlepage}
\tableofcontents
\thispagestyle{empty}

\chapter{Introduction}
...
\appendix
\chapter{Quick reference}
\end{document}
```

`oneside` matters: without it `report` reserves blank verso pages for a binding
nobody is going to do.

Set `\setlength{\parskip}{6pt}` and `\setlength{\parindent}{0pt}` for a document
read on screen. Indented, unspaced paragraphs are a print convention and look
cramped in a PDF people scroll.

## Callouts

house.tex gives you three, and the distinction is worth keeping:

```latex
\begin{houseinfo}                       % calm: rationale, context, why
Falling back to the national rate is the safe direction to be wrong in.
\end{houseinfo}

\begin{housewarn}[The VAT trap]         % loud: this will cost money if missed
Rates are entered excluding VAT.
\end{housewarn}

\begin{housebox}                        % the single most important thing here
...
\end{housebox}
```

Both take an optional title. Use `housewarn` sparingly: a document where every
third block is a warning has no warnings.

## Tables

**Use `tabular` for anything that fits on a page.** `longtable` with `\endhead`
repeats its header on every page, which is right for a genuinely long reference
table and wrong for a five-row one, because if it splits you get an orphaned
header and a single row stranded on the next page. Wrap short tables so they
cannot split at all:

```latex
\begin{center}
\begin{tabular}{@{}L{5.6cm}L{2.4cm}L{1.4cm}r@{}}
\toprule
\textbf{Item} & \textbf{Class} & \textbf{Qty} & \textbf{Total}\\
\midrule
...
\bottomrule
\end{tabular}
\end{center}
```

`L{}` is the ragged-right paragraph column from house.tex. Use it instead of
`p{}` in reference tables: justified text in a narrow column produces rivers.

**Sizing a column that holds code.** A monospace token of roughly 33 characters
at `\small` needs about 6.2cm. Measure the longest entry and give the column that
much, rather than discovering it as an overfull box later. Numeric columns take
`r`, not `L{}`.

## Figures

Always `[H]`, always captioned, always labelled:

```latex
\begin{figure}[H]
\centering
... tikzpicture ...
\caption{What the reader should take from this, in one sentence.}
\label{fig:thing}
\end{figure}
```

A caption that just repeats the title of the diagram is wasted. Say the thing the
picture implies but does not state.

See [DIAGRAMS.md](DIAGRAMS.md) for the flowchart kit and its layout rules.

## Quality gate

The build script reports these automatically. Treat all three as build failures
in a document you are going to hand over.

| Signal | Means | Fix |
|---|---|---|
| `Overfull \hbox` | text is running past the margin | reword the line, or widen the column. Under about 1pt is invisible and can be ignored, but zero is achievable |
| A `.pk` font was used | a bitmap font got generated, and it will look furry on screen and print | a font package did not resolve; see the font troubleshooting in [REFERENCE.md](REFERENCE.md) |
| `Reference ... undefined` | a `\ref` or `\cite` never resolved | usually needs another pass, which the script does automatically; if it persists the label is missing or misspelt |

Then look at the thing. Rasterise a page and zoom in before declaring it done:

```bash
pdftoppm -png -r 400 -f 17 -l 17 doc.pdf page
```

Page-scale previews hide collisions, clipped descenders and hairline overlaps.
Most of the defects worth fixing in a finished document are invisible until you
are looking at 400 dpi or better.

## Writing rules that show up in the output

- **No em dashes.** House rule, enforced by grep: `grep -rn -- '---' *.tex`
  should come back empty. Use a comma, a colon, parentheses, or a full stop. In a
  table cell meaning "nothing", `--` or `n/a`.
- **Ban the symbol the reader does not have.** See the notation section in
  DIAGRAMS.md. This applies to prose too: define a term on first use or use a
  plainer one.
- **A heading that says what happens beats one that says what it is.** "Step 2:
  dry-goods delivery" over "Dry goods".
