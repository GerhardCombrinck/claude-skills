# claude-skills

Claude Code skills, packaged as a plugin marketplace.

## Install

```bash
claude
```

Then, inside Claude Code:

```
/plugin marketplace add GerhardCombrinck/claude-skills
/plugin install gc-skills@invisionsoft
```

Restart Claude Code (or run `/plugin` and reload) and the skill is live. Claude picks it
up automatically when a task calls for a PDF; you can also invoke it with `/latex`.

To update later:

```
/plugin marketplace update invisionsoft
```

## Plugins

### `gc-skills`

Ships the **`latex`** skill. Compiles `.tex` to PDF through LuaLaTeX and applies one
shared house style, so every document out of it looks like the same document family:
Source Sans 3, a muted palette, booktabs tables, consistent title blocks and footers.

What you get:

- **`scripts/build.ps1`** (Windows) and **`scripts/build.sh`** (macOS/Linux) — one
  command from `.tex` to PDF. Handles `\ref`/TOC reruns, `makeindex`, aux cleanup, and
  prints just the error lines when a build fails instead of the 2000-line log.
- **`style/house.tex`** — every colour, macro and package in one file. Edit it once and
  every document restyles.
- **`style/fonts/`** — Source Sans 3 ships with the plugin, so there is no font install
  step on a new machine.
- **`DIAGRAMS.md`** — a TikZ flowchart kit: node shapes, edge routing, swimlanes and
  the spacing rules that keep a diagram from colliding with its caption.
- **`LONGDOC.md`** — chapters, callout boxes, captioned figures and cross-referencing
  for anything longer than a one-pager.
- **`EDITORS.md`** — wiring the house style into TeXworks, VS Code or Overleaf, which
  otherwise launch LuaLaTeX with a bare environment and cannot find `house.tex`.

**Requirements:** a TeX distribution with LuaLaTeX.

| OS | Install |
|---|---|
| Windows | `winget install MiKTeX.MiKTeX --scope user` |
| macOS | `brew install --cask mactex-no-gui` |
| Debian/Ubuntu | `apt install texlive-luatex texlive-latex-extra texlive-fonts-extra` |

The build script finds the engine on `PATH`, in the default MiKTeX user install, or in
`/Library/TeX/texbin`. If yours lives elsewhere, set `LATEX_BIN` to that directory.

MiKTeX installs missing packages on first build. TeX Live users should install the full
scheme or the `-extra` packages above, since `tcolorbox` and `pgfplots` are not in the
base install.

First build on a new machine is slow while LuaLaTeX builds its font cache. Later builds
are fast.

## Licence

Skill code and styles: MIT (see [LICENSE](LICENSE)).
Bundled Source Sans 3 fonts: SIL Open Font License 1.1, Copyright Adobe
(see [OFL.txt](plugins/gc-skills/skills/latex/style/fonts/OFL.txt)).
