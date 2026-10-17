# The C64's own sidebar (k4510c64.c), run by apply.py from the VICE source
# tree: the file beside video_sdl2.c, drawn there instead of the K4532's
# scene on x64sc, and the mouse's events handed to it first in ui.c.
import os, shutil, sys
here = os.path.dirname(os.path.abspath(__file__))
shutil.copy(os.path.join(here, "k4510c64.c"), "src/arch/sdl/k4510c64.c")
def patch(path, edits):
    s = open(path).read()
    for old, new in edits:
        if s.count(old) != 1:
            sys.exit(f"vice/c64panel.py: {path}: expected 1x {old!r}, found {s.count(old)}")
        s = s.replace(old, new)
    open(path, "w").write(s)
patch("src/arch/sdl/video_sdl2.c", [
    ('#include "k4510host_sdl2.c"\n', '#include "k4510host_sdl2.c"\n#include "k4510c64.c"\n'),
    ("        return;\n    }\n    k4510host_sdl2(r, area);\n",
     "        return;\n    }\n"
     "    if (k4510c64_active()) {\n        k4510c64_draw(canvas, r, area);\n        return;\n    }\n"
     "    k4510host_sdl2(r, area);\n"),
])
patch("src/arch/sdl/ui.c", [
    ("/* Main event handler */\nvoid ui_dispatch_events(void)\n",
     "/* K4510: the C64's sidebar takes the mouse's events over it (k4510c64.c) */\n"
     "int k4510c64_event(SDL_Event *e);\n\n"
     "/* Main event handler */\nvoid ui_dispatch_events(void)\n"),
    ("    while (SDL_PollEvent(&e)) {\n        joystick_device_t *joydev = NULL;\n",
     "    while (SDL_PollEvent(&e)) {\n        joystick_device_t *joydev = NULL;\n"
     "        if (k4510c64_event(&e)) {\n            continue;\n        }\n"),
])
print("vice/c64panel.py: the C64's sidebar in")
