"""Capture the manual's figures from screens.html, at 2x.

This is the recipe SCREENSHOTS.md documents, applied to a local mock instead of
a live application:

  * screenshot a CSS SELECTOR, not the viewport, so the crop is exact and
    survives the page reflowing;
  * device_scale_factor=2, so an element placed at half \\linewidth lands near
    420dpi rather than a soft 190;
  * clip the element's bounding box plus a little padding, because a bare
    element screenshot cuts flush to the border and clips text sitting in the
    element's own padding;
  * wrap each capture, so one bad selector does not abandon the rest.

There is no login step here only because the mock needs none. Against a real
application that is the first thing to add: an interesting screen is usually
behind one, and a guest sees an empty shell.

Run:  python capture.py [name ...]
      with no arguments it captures everything in SHOTS.
"""

from __future__ import annotations

import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
PAGE = (HERE / "screens.html").as_uri()
OUT = HERE.parent / "figures"
SCALE = 2
PAD = 10  # CSS px of breathing room around each captured element

# figure name -> CSS selector in screens.html
SHOTS = {
    "settings-rates": "#rates",
    "settings-packaging": "#packaging",
    "product-fields": "#product",
    "cart-totals": "#cart",
    "order-breakdown": "#order",
    "admin-log": "#log",
}


def capture(page, name: str, selector: str) -> bool:
    try:
        node = page.locator(selector).first
        if node.count() == 0:
            print(f"  MISS {name}: nothing matched {selector!r}")
            return False

        node.scroll_into_view_if_needed(timeout=10_000)
        box = node.bounding_box()
        if box is None:
            node.screenshot(path=str(OUT / f"{name}.png"), timeout=20_000)
        else:
            page_w = page.evaluate("document.documentElement.scrollWidth")
            page_h = page.evaluate("document.documentElement.scrollHeight")
            x = max(0.0, box["x"] - PAD)
            y = max(0.0, box["y"] - PAD)
            page.screenshot(
                path=str(OUT / f"{name}.png"),
                clip={
                    "x": x,
                    "y": y,
                    "width": min(box["width"] + 2 * PAD, page_w - x),
                    "height": min(box["height"] + 2 * PAD, page_h - y),
                },
                timeout=20_000,
            )
    except Exception as exc:  # one bad shot must not abandon the others
        print(f"  FAIL {name}: {type(exc).__name__}: {str(exc).splitlines()[0][:90]}")
        return False

    print(f"  ok   {name}.png")
    return True


def main() -> int:
    wanted = sys.argv[1:] or list(SHOTS)
    OUT.mkdir(parents=True, exist_ok=True)
    failures = 0

    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context(
            viewport={"width": 1200, "height": 1000},
            device_scale_factor=SCALE,
        )
        page = context.new_page()
        page.goto(PAGE, wait_until="networkidle")

        for name in wanted:
            if name not in SHOTS:
                print(f"  ??   unknown shot {name!r}")
                failures += 1
                continue
            if not capture(page, name, SHOTS[name]):
                failures += 1

        context.close()
        browser.close()

    print(f"\n{len(wanted) - failures}/{len(wanted)} captured at {SCALE}x into {OUT}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
