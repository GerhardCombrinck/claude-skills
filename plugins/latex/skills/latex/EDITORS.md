# Using the house style from a LaTeX editor

The build scripts set `TEXINPUTS` (so `\input{house}` resolves) and `OPENTYPEFONTS`
(so the bundled Source Sans 3 resolves) before calling LuaLaTeX. A GUI editor launches
the engine with a bare environment, so it does neither, and you get:

```
! LaTeX Error: File `house.tex' not found.
```

followed by every `\house...` macro being undefined.

Two ways to fix it. **Option A is the better one** — it reuses the build script, so you
also get the `makeindex`/rerun handling, the aux cleanup, and the short error summary.

## First: find the installed skill

The active copy is version-pinned, e.g.
`...\plugins\cache\invisionsoft\latex\1.0.0\skills\latex\`. **That path changes every
time the plugin updates.** Never type it from memory. Print it:

```powershell
$skill = (Get-ChildItem "$env:USERPROFILE\.claude\plugins" -Recurse -Filter house.tex |
          Select-Object -First 1).DirectoryName | Split-Path -Parent
$skill
```

macOS/Linux:

```bash
skill=$(dirname "$(dirname "$(find ~/.claude/plugins -name house.tex | head -1)")")
echo "$skill"
```

## Option A — call the build script from TeXworks (recommended)

`Edit ▸ Preferences ▸ Typesetting ▸ Processing tools ▸ +`

| Field | Value |
|---|---|
| Name | `House LuaLaTeX` |
| Program | `powershell.exe` |
| Arguments | `-NoProfile`, `-ExecutionPolicy`, `Bypass`, `-File`, `<skill>\scripts\build.ps1`, `$fullname` |
| View PDF after running | ✔ |

Each argument goes on **its own line** in the arguments list — TeXworks does not split a
single line on spaces, so one long string will fail.

Then `Preferences ▸ Typesetting ▸ Default` → `House LuaLaTeX`.

Because build.ps1 sets the environment itself, nothing else needs configuring, and a
plugin update only means re-pointing this one path.

If PowerShell refuses to run the script, that is machine execution policy, not the
plugin. `-ExecutionPolicy Bypass` above already covers it for this invocation.

**Trade-off:** the script deletes aux files after every successful build, so SyncTeX
reverse-search (double-click PDF → jump to source) will not work. If you want SyncTeX,
use Option B instead, or add `-KeepAux` as another argument line.

## Option B — set the environment variables permanently

Set them once as user environment variables, then **restart the editor** — it reads the
environment at launch, so an already-open TeXworks will not see them.

```powershell
$style = (Get-ChildItem "$env:USERPROFILE\.claude\plugins" -Recurse -Filter house.tex |
          Select-Object -First 1).DirectoryName
setx TEXINPUTS "$style;"
setx OPENTYPEFONTS "$style\fonts;"
```

The **trailing `;` is required**. Without it you replace the default TeX search path
instead of extending it, and unrelated documents stop building.

macOS/Linux, in `~/.zshrc` or `~/.bashrc` (trailing `:` there):

```bash
export TEXINPUTS="$skill/style:"
export OPENTYPEFONTS="$skill/style/fonts:"
```

**Re-run this after every plugin update**, because the version directory in the path
changes. Symptom of a stale value: `house.tex not found` returns out of nowhere on a
document that built fine last week.

## Make LuaLaTeX the default engine

house.tex uses `fontspec`, which pdfLaTeX cannot load. TeXworks defaults to pdfLaTeX,
so a fresh install fails with:

```
! Package fontspec Error: The fontspec package requires either XeTeX or LuaTeX.
```

Fix globally: `Edit ▸ Preferences ▸ Typesetting ▸ Default` → `LuaLaTeX` (or
`House LuaLaTeX` from Option A).

Fix per document, which also survives sharing the `.tex` with someone else — make the
**first line** of the file:

```latex
% !TeX program = lualatex
```

TeXworks, TeXstudio, VS Code + LaTeX Workshop and Overleaf all honour that comment. Put
it in every document built with this skill; it costs one line and removes a whole class
of "works on my machine".

## Other editors

Same two ideas apply. Either point the editor's build command at `scripts/build.ps1` /
`scripts/build.sh`, or export the two variables in the environment the editor inherits.

**VS Code + LaTeX Workshop** — a recipe calling the script, in `settings.json`:

```json
"latex-workshop.latex.tools": [
  {
    "name": "house",
    "command": "powershell.exe",
    "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
             "<skill>/scripts/build.ps1", "%DOC_EXT%"]
  }
],
"latex-workshop.latex.recipes": [
  { "name": "House LuaLaTeX", "tools": ["house"] }
]
```

Use `%DOC_EXT%`, not `%DOC%` — LaTeX Workshop strips the extension from `%DOC%` and the
script expects a real filename.

**Overleaf** cannot use this skill as-is: there is no way to set `OPENTYPEFONTS`. Upload
`house.tex` next to your document (so `\input{house}` finds it in the same directory),
upload the OTFs from `style/fonts/` alongside it, and set the compiler to LuaLaTeX in
Menu ▸ Compiler.
