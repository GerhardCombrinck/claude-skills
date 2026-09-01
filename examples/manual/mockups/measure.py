"""Read row boundaries off a captured PNG, so \\hilite coordinates are measured
rather than guessed. This is the technique described in SCREENSHOTS.md.

Run:  python measure.py ../figures/settings-rates.png [frac] [dark]

  frac  how much of the row must be non-background to count as a rule (0.60)
  dark  the grey level below which a pixel counts as non-background (240)

Raise `dark` for an interface with very light separators: a #f0f0f1 rule is
grey 240, so the default cutoff misses it entirely and only the heavy borders
come back.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image


def edges(path: Path, frac: float = 0.60, dark: int = 240) -> list[tuple[int, float]]:
    a = np.array(Image.open(path).convert("L"))
    h, w = a.shape

    # A separator rule is a row where most pixels are darker than the background.
    faint = (a < dark).sum(axis=1)
    rows = [y for y in range(h) if faint[y] > w * frac]

    # Collapse runs of adjacent rows into one boundary each.
    out, prev = [], -10
    for y in rows:
        if y - prev > 3:
            out.append((y, 1 - y / h))  # TikZ y runs from the bottom
        prev = y
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    frac = float(sys.argv[2]) if len(sys.argv) > 2 else 0.60
    dark = int(sys.argv[3]) if len(sys.argv) > 3 else 240

    found = edges(path, frac, dark)
    print(f"{path.name}  frac={frac} dark={dark}")
    if not found:
        print("  no separator rules found; lower the threshold")
        return 1
    for y, norm in found:
        print(f"  y={y:5d}   normalised={norm:.3f}")
    print("\n  bands between consecutive boundaries:")
    for (y0, n0), (y1, n1) in zip(found, found[1:]):
        print(f"    \\hilite{{0.01}}{{{n1:.3f}}}{{0.99}}{{{n0:.3f}}}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
