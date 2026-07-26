"""Cut static instances out of the Nunito Sans / Inter variable fonts.

Offline, like `dailymed_extract.py` — never deployed, never run at runtime. Its
output is the seven `.ttf` files in `CareAid/Resources/Fonts/`, which are
committed. You only need this if a weight has to be added or a family replaced.

**Why static instances at all.** Google Fonts ships both families as variable
fonts, and SwiftUI's `.weight()` modifier does not drive OpenType variation
axes. A registered variable TTF therefore renders its default instance for
every weight you ask for — the type all looks subtly wrong and nothing errors.
Pinning each weight to its own file is what makes `Font.custom("Inter-SemiBold")`
actually semibold on device.

Usage:

    python3 -m venv venv && ./venv/bin/pip install fonttools
    curl -sSL -o NunitoSans.ttf \\
      'https://raw.githubusercontent.com/google/fonts/main/ofl/nunitosans/NunitoSans%5BYTLC%2Copsz%2Cwdth%2Cwght%5D.ttf'
    curl -sSL -o Inter.ttf \\
      'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf'
    ./venv/bin/python instance_fonts.py ../CareAid/Resources/Fonts

Both families are SIL Open Font License 1.1.

Adding a weight means three edits, not one: a line in `JOBS` here, a line in
`UIAppFonts` in `Info.plist`, and a constant in `Theme.Face`. Miss the plist and
the font silently falls back to San Francisco.
"""

import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

OUT = sys.argv[1]

JOBS = [
    # (source, axis pins, output basename)
    #
    # `wdth` is pinned for Nunito Sans and `opsz` for Inter so the instance is
    # fully static — an unpinned axis would leave a variable font behind and put
    # us back where we started. opsz 20 is the middle of our type scale.
    ("NunitoSans.ttf", {"wght": 400, "wdth": 100}, "NunitoSans-Regular"),
    ("NunitoSans.ttf", {"wght": 600, "wdth": 100}, "NunitoSans-SemiBold"),
    ("NunitoSans.ttf", {"wght": 700, "wdth": 100}, "NunitoSans-Bold"),
    ("NunitoSans.ttf", {"wght": 800, "wdth": 100}, "NunitoSans-ExtraBold"),
    ("Inter.ttf", {"wght": 400, "opsz": 20}, "Inter-Regular"),
    ("Inter.ttf", {"wght": 500, "opsz": 20}, "Inter-Medium"),
    ("Inter.ttf", {"wght": 600, "opsz": 20}, "Inter-SemiBold"),
    ("Inter.ttf", {"wght": 700, "opsz": 20}, "Inter-Bold"),
]

for source, pins, basename in JOBS:
    font = TTFont(source)
    instancer.instantiateVariableFont(
        font, pins, inplace=True, updateFontNames=True, static=True
    )

    # Force the PostScript name (id 6) so the Swift call site is predictable.
    # `updateFontNames` derives names from the STAT table and does not reliably
    # land on the Family-Weight form that `Theme.Face` refers to.
    name = font["name"]
    family, _, style = basename.partition("-")
    name.setName(f"{family} {style}", 1, 3, 1, 0x409)
    name.setName(style, 2, 3, 1, 0x409)
    name.setName(f"{family} {style}", 4, 3, 1, 0x409)
    name.setName(basename, 6, 3, 1, 0x409)

    font.save(f"{OUT}/{basename}.ttf")
    print(f"{basename:26} postscript={name.getDebugName(6)}")
