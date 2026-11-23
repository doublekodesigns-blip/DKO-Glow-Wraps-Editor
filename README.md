DKO Glow Wraps Editor - source for review
=========================================
This is the full human-readable source of the program whose .exe was quarantined.
The flag is a false positive on the small launcher .exe. Here is exactly what it does.

THE .EXE ("DKO Glow Wraps Editor.exe")
  - Full source: "launcher (the .exe)\launcher.c"  (a ~170 KB native Windows program, no installer).
  - All it does: start the copy of Windows PowerShell that ships with Windows and hand it the bundled
    script "engine\DKO_Glow_Wraps_Editor.ps1" on standard input (powershell.exe -NoProfile -NonInteractive
    -STA -Command -). The script's folder is passed in the DKO_ENGINE_DIR environment variable.
  - It does NOT use "-ExecutionPolicy Bypass" or "-WindowStyle Hidden" (the usual malware launcher flags).
  - It makes NO network connections, installs nothing, writes only inside its own folder and
    %LOCALAPPDATA%\DKO_Glow_Wraps_Editor (logs/settings).
  - It is unsigned, which is why a generic .exe heuristic flags it. The command line it runs is fixed and
    visible in launcher.c.

WHAT THE PROGRAM DOES
  - It is a GUI tool (Windows Forms via PowerShell) that lets a user design color variants of an existing
    Cyberpunk 2077 clothing item and builds a normal Cyberpunk mod (.archive + TweakXL/ArchiveXL files),
    zipped for the Vortex mod manager.
  - The build step edits mesh/material JSON (Python) and serializes it with the bundled WolvenKit CLI
    (the standard, open-source Cyberpunk modding tool, GPL-3.0). WolvenKit is included, not installed.

SOURCE FILES
  launcher (the .exe)\launcher.c         - the entire .exe
  launcher (the .exe)\app.manifest, app.rc - the icon/version info/manifest built into the .exe
  engine scripts\DKO_Glow_Wraps_Editor.ps1 - the editor window and all of its logic
  engine scripts\dko_glowwraps_colors.py   - builds the mod files (colors, materials, item entries)
  engine scripts\dko_gwc_mesh.py           - strap mesh / UV helpers
  engine scripts\dko_item.py, dko_store.py - item appearance + Virtual Atelier store helpers
  engine scripts\ui\gwc_preview.cs         - the in-editor live preview (compiled at runtime by PowerShell)

HOW THE .EXE IS BUILT (for anyone who wants to reproduce it)
  Built with MinGW-w64 (x86_64-w64-mingw32-gcc). From the "launcher (the .exe)" folder:
     x86_64-w64-mingw32-windres app.rc -O coff -o app.res
     x86_64-w64-mingw32-gcc -O2 -mwindows -municode \
       -DAPP_TITLE="L\"DKO Glow Wraps Editor\"" -DAPP_SCRIPT="L\"DKO_Glow_Wraps_Editor.ps1\"" \
       -DAPP_DIR="L\"DKO_Glow_Wraps_Editor\"" launcher.c app.res -o "DKO Glow Wraps Editor.exe" -s -luser32 -lkernel32
  (app.rc also needs the program icon "dko.ico" beside it.)

Contact: Double K.O. Designs
