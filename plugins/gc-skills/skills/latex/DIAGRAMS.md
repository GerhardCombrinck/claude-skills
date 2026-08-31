# Flowcharts and process diagrams

house.tex ships a TikZ node vocabulary (`dgbox`, `dgterm`, `dgask`, `dgflow`,
`dgstub`, `dgtag`). The styles are the easy half. The layout rules below are the
half that actually decides whether a diagram looks deliberate or homemade, and
every one of them is here because it went wrong first.

## The kit

| Style | Use for | Look |
|---|---|---|
| `dgbox=<width>` | a process step | white, grey border |
| `dgterm=<width>` | start, end, or an output | blue-tinted, blue border |
| `dgask=<width>` | a decision | amber-tinted, amber border |
| `dgflow` | an arrow between two nodes | grey, small stealth head |
| `dgstub` | a connector into a junction, **no** arrowhead | grey line |
| `dgtag` | a branch label (`yes` / `no`) | tiny, white-filled |

Width is optional and defaults to 32mm: `\node[dgbox] ...` or `\node[dgbox=48mm] ...`.

```latex
\begin{figure}[H]
\centering
\begin{tikzpicture}[node distance=8mm and 14mm]
  \node[dgterm=44mm]                       (in)   {What comes in};
  \node[dgask=44mm, below=of in]           (ask)  {Is the thing true?};
  \node[dgbox=42mm, right=of ask]          (side) {Do the side thing};
  \node[dgterm=44mm, below=of ask]         (out)  {The result};

  \draw[dgflow] (in) -- (ask);
  \draw[dgflow] (ask) -- (side) node[dgtag, pos=0.5] {yes};
  \draw[dgflow] (ask) -- (out)  node[dgtag, pos=0.5] {no};
  \draw[dgflow] (side.south) -- ++(0,-5mm) -| ([xshift=15mm]out.north);
\end{tikzpicture}
\caption{One sentence saying what the reader should take from this.}
\label{fig:example}
\end{figure}
```

`node distance=8mm and 14mm` is *vertical* then *horizontal*. Getting these the
wrong way round is the most common reason a diagram comes out squashed.

## Layout rules

### Rows of boxes must be aligned by their tops, not their centres

`right=of previous` aligns node **centres**. The moment one box in a row carries
an extra line of text it grows in both directions, its top edge rises above its
neighbours, and the arrow feeding it is visibly shorter than the others. It reads
as a mistake even to someone who cannot say why.

Anchor north and chain corner to corner instead:

```latex
\node[dgbox=29mm, below=13mm of parent, xshift=-56mm, anchor=north] (b1) {...};
\node[dgbox=29mm, anchor=north west] (b2) at ([xshift=4mm]b1.north east) {...};
\node[dgbox=29mm, anchor=north west] (b3) at ([xshift=4mm]b2.north east) {...};
```

Tops now line up, gaps are a uniform 4mm, and every arrow into the row is the
same length. Boxes with more content hang lower, which is honest.

### `-|` and `|-` are not interchangeable

- `-|` goes **horizontal first, then vertical**.
- `|-` goes **vertical first, then horizontal**.

Pick the wrong one and the path overshoots its target and re-enters from an odd
side, usually running along a box edge on the way. The symptom is a leader that
looks like it took a detour, because it did.

Rule of thumb: to enter a node from **above**, finish vertical, so use `-|`. To
enter from the **side**, finish horizontal, so use `|-`.

### Rejoin a side branch at the next node's top edge, offset from centre

The obvious move, dropping straight down out of a side box, fails as soon as
anything occupies the row below it: the line lands inside that box. Route the
branch back to the spine instead, and enter the next node's top edge offset from
the centre so it does not collide with the straight-through arrow:

```latex
\draw[dgflow] (side.south) -- ++(0,-5mm) -| ([xshift=15mm]next.north);
```

Two arrowheads meeting the same node from different x positions reads correctly
as convergence. Two arrowheads on the identical point reads as a mistake.

### Arrowheads belong on outcomes, never in mid-air

A stub from a node into a junction coordinate must not carry a head, or you get
an arrow pointing at nothing in the middle of the diagram. That is what `dgstub`
is for:

```latex
\coordinate (j) at ([xshift=8mm]gate.east);
\draw[dgstub] (gate.east) -- (j);          % no head
\draw[dgflow] (j) |- (yes.west);           % head lands on the outcome
```

### Split a path when you need a label on a specific segment

`node[midway]` attaches to the segment **immediately before it**, so on a
multi-segment `-|` path a label lands wherever the bend happens to be, typically
half inside a box. Write the segments out and the label goes where you meant:

```latex
\draw[dgflow] (j) -- (jy) -- (yes.west) node[dgtag, midway, above=1pt] {all three};
```

Branch labels also need room. Allow roughly 24mm of clear run for a two-word
label. If a label is colliding with a box, the fix is usually more space between
the gate and the outcome, not a smaller font.

### Give tall content vertical room

`dgbox` sets `inner xsep` and `inner ysep` separately, with a larger ysep, for
one reason: a single combined `inner sep` does not leave enough depth for
`\lceil`, fractions or large parentheses, and the glyph collides with the bottom
border. If you build a node style of your own, keep the split.

Add `\strut` at the end of a line of maths inside a node so the line box accounts
for the full depth.

## Notation: write it in words

Ceiling brackets are the trap worth naming. `$\lceil x \rceil$` renders `⌈x⌉`,
which has a top arm and no bottom foot **by design**. Readers who do not already
know the notation report it as a clipped or broken glyph, and they are not wrong
to: it looks like a square bracket with a piece missing.

Inside a flowchart, write `quantity / units per bag, rounded up`. Keep the formal
notation for displayed equations in the body text, where it has room and looks
deliberate, and gloss it on first use:

> The ⌈ ⌉ brackets mean *round up to the next whole number*.

The same logic applies to any symbol the audience may not carry: a diagram is
read at a glance, and anything that makes a reader stop and wonder has already
cost more than it saved.

## Checking a diagram properly

Screenshots at page scale hide exactly the problems that matter (a 0.3mm
collision, a clipped descender). Rasterise and zoom:

```bash
pdftoppm -png -r 600 -f 17 -l 17 doc.pdf out
python -c "from PIL import Image; im=Image.open('out-17.png'); im.crop((2800,3500,4250,4000)).save('crop.png')"
```

600 dpi is enough to settle any "is this clipped" question definitively. Do this
before claiming a rendering problem is fixed, and before claiming one exists.
