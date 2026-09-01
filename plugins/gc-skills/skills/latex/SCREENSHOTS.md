# Annotated screenshots

A screenshot on its own says "here is a screen". An annotated screenshot says "look at
this part of this screen, because of that sentence you just read". The second is worth
the effort; the first rarely is.

The kit draws the annotations in TikZ, over the raster, on coordinates normalised to the
image box. Two things follow from that, and they are the whole reason for the approach:

1. The annotations are vector, so they stay sharp at any zoom while the capture behind
   them does not.
2. A coordinate of `0.72` means "72% of the way up this image", not "48mm from the
   bottom". Resize the figure from `0.6` to `0.5` of `\linewidth` and every band, badge
   and leader moves with it. Nothing to re-tune.

Annotations are drawn in `accent`, the house style's one loud colour, so they read as
commentary rather than as part of the captured interface.

## The kit

| Macro | Does |
|---|---|
| `\shotimg{width}{file}` | Places `figures/<file>` at `width` x `\linewidth`, as a node always named `(img)` |
| `shotscope` environment | Remaps coordinates so `(0,0)` is the image's bottom left and `(1,1)` its top right |
| `\hilite{x0}{y0}{x1}{y1}` | A highlight rectangle, in normalised coordinates |
| `\pt{name}{x}{y}` | A named coordinate on the image, to aim a leader at |
| `\sidelbl{name}{dx}{dy}{width}{text}` | A label outside the frame, offset from the image's east edge |
| `\leadto{label}{point}` | A leader line from a side label to a point |
| `\shotbadgeat{y}{n}` | A numbered badge in the left gutter, at normalised height `y` |
| `\shotkey{n}` | The matching numbered badge, inline in a key entry below the figure |

Styles, if you need to draw something the macros do not cover: `shotframe`, `shothi`,
`shotbadge`, `shotlead`, `shotlabel`.

**`\shotimg` looks in `figures/`.** Keep captures in a `figures/` directory next to the
document.

## Which pattern

**Default to side labels.** They put the explanation beside the thing, so a reader
following a sentence in the body text lands on the right region immediately.

**Use badges and a key only when a figure genuinely has four or more points.** Past
three, side labels start colliding with each other and the page gets crowded; a numbered
key stays readable at any count. Below four, a key makes the reader do a lookup that the
side label would have saved them.

### Pattern B: side labels and leaders

```latex
\begin{figure}[H]
\centering
\begin{tikzpicture}
  \shotimg{0.60}{settings-rates.png}
  \begin{shotscope}
    \hilite{0.004}{0.72}{0.996}{0.99}
    \hilite{0.004}{0.02}{0.996}{0.26}
    \pt{a}{0.99}{0.86}
    \pt{b}{0.99}{0.14}
  \end{shotscope}
  \sidelbl{l1}{12mm}{11mm}{34mm}{Two livestock rates, chosen by \textbf{postcode}.}
  \sidelbl{l2}{12mm}{-13mm}{34mm}{Charged \textbf{per item}, instead of the flat rate.}
  \leadto{l1}{a}
  \leadto{l2}{b}
\end{tikzpicture}
\caption{Every field here excludes VAT.}
\label{fig:settings-rates}
\end{figure}
```

Points to note:

- `\hilite` and `\pt` go **inside** `shotscope`; `\sidelbl` and `\leadto` go **outside**
  it, because their offsets are real distances, not fractions of the image.
- Aim `\pt` at `x = 0.99`, the image's right edge, so the leader has the shortest
  possible run and never crosses the capture.
- Give the image about `0.60\linewidth`, which leaves roughly a third of the measure for
  labels. Wider than that and the labels start wrapping to four lines.
- `dy` offsets are measured from the image's vertical centre, so they run positive above
  and negative below. Two labels need roughly 24mm between them to clear.

### Pattern A: gutter badges and a key

```latex
\begin{figure}[H]
\centering
\begin{tikzpicture}
  \shotimg{0.68}{order-breakdown.png}
  \begin{shotscope}
    \hilite{0.004}{0.585}{0.996}{0.668}
    \hilite{0.004}{0.336}{0.996}{0.585}
    \shotbadgeat{0.627}{1}
    \shotbadgeat{0.460}{2}
  \end{shotscope}
\end{tikzpicture}
\caption{Order confirmation, as the customer sees it.}
\label{fig:order-breakdown}
\end{figure}

\vspace{-8pt}
\begin{description}[leftmargin=1.6em,labelindent=0pt,itemsep=2pt,parsep=0pt,
                    topsep=2pt,font=\normalfont]
  \item \shotkey{1} \textbf{The shipping row}, the transport components added together.
  \item \shotkey{2} \textbf{The breakdown}, shown only when there is more than one.
\end{description}
```

Points to note:

- Put the badge at the **vertical centre of the band it marks**, not at the band's top
  edge. Centre the number on what it names.
- `\vspace{-8pt}` before the key closes the gap left by the caption. Without it the key
  floats away from the figure it belongs to.
- `font=\normalfont` on the `description` stops the badge inheriting a bold label font
  and rendering at the wrong weight.
- `leftmargin` must leave room for the badge. At `0pt` the first line indents but every
  wrapped line falls back to the margin, so a two-line entry looks broken. `1.6em`
  hangs the text under itself.

## Placing bands by measurement, not by eye

The slow way to align a highlight band is to guess a coordinate, rebuild, squint at the
PDF, and adjust. It takes several rounds and still lands a row out.

The fast way is to measure the PNG. Most interfaces worth annotating are tables or forms
with horizontal separator rules, and those rules are exactly the row boundaries you want:

```python
from PIL import Image
import numpy as np

a = np.array(Image.open('figures/settings-rates.png').convert('L'))
h, w = a.shape

# A separator rule is a row where most pixels are darker than the background.
faint = (a < 240).sum(axis=1)
rows = [y for y in range(h) if faint[y] > w * 0.60]

# Collapse runs of adjacent rows into one boundary each.
edges, prev = [], -10
for y in rows:
    if y - prev > 3:
        edges.append(y)
    prev = y

# TikZ y runs from the bottom; image y runs from the top.
for y in edges:
    print(f"y={y:5d}  normalised={1 - y / h:.3f}")
```

Feed two consecutive values straight into `\hilite`. One measurement replaces the whole
guess-and-rebuild loop.

Tune `0.60` if the interface has full-width shading rather than rules: lower it to catch
faint separators, raise it to ignore text lines that happen to be dense.

## Capturing

`\shotimg` will place whatever you give it. Getting a capture worth placing is a separate
job, and these are the parts that are not obvious.

**Drive a real browser, not a headless screenshot flag.** Playwright, Puppeteer or
Selenium. Anything that authenticates, because an interesting screen is usually behind a
login, and a guest sees an empty shell.

**Screenshot a CSS selector, not the viewport.** The crop is then exact and survives the
page reflowing. There are no pixel coordinates to re-tune when the page changes.

**Set `device_scale_factor=2`.** A 2x element crop lands around 420dpi once placed at
half `\linewidth`. A 1x capture lands near 190dpi and looks soft next to vector text on
the same page.

**Capture the element's bounding box plus about 10 CSS px, not the bare element.** A bare
element screenshot cuts flush to the border and clips any text sitting in the element's
own padding.

```python
box = node.bounding_box()
page.screenshot(path=out, clip={
    "x": max(0, box["x"] - PAD),
    "y": max(0, box["y"] - PAD),
    "width":  box["width"]  + 2 * PAD,
    "height": box["height"] + 2 * PAD,
})
```

**Wrap each capture in try/except.** One selector that stopped matching must not abandon
the other nine.

**Reset state between runs.** If the app persists anything for a logged-in user, a cart
or a filter, it accumulates across runs and the figures quietly stop matching the worked
example in the text.

## Before you call it done

- Every capture is at 2x, and no image is placed wider than it was captured.
- No annotation covers text the reader needs to read.
- Band coordinates were measured, not guessed.
- Side labels do not overlap each other or run past the text block.
- Every badge has a key entry, and every key entry has a badge.
- The caption says what the reader should take away, not what the screen is called.
- Look at the page at 400 to 600dpi, not at page scale:
  `pdftoppm -png -r 600 -f 12 -l 12 out.pdf page`
