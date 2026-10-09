# Hook k4510menu.c into x16emu's source (run from the source tree by
# build-x16.sh).  Each edit must find its anchor, or the build stops.
import shutil, sys, os
here = os.path.dirname(os.path.abspath(__file__))
for f in ("k4510menu.c", "k4510menu.h"):
    shutil.copy(os.path.join(here, f), "src/" + f)
for f in ("k4510host.c", "k4510host.h", "k4510host_sdl2.c", "k4510host_sdl2.h"):
    shutil.copy(os.path.join(here, "..", "common", f), "src/" + f)
def edit(path, old, new, count=1):
    s = open(path).read()
    if s.count(old) != count:
        sys.exit(f"apply.py: {path}: expected {count}x {old!r}, found {s.count(old)}")
    open(path, "w").write(s.replace(old, new))
edit("Makefile", "_X16_OBJS = cpu/fake6502.o ", "_X16_OBJS = k4510menu.o k4510host.o k4510host_sdl2.o cpu/fake6502.o ")
edit("src/rendertext.c", "static unsigned char fontdata[]", "unsigned char fontdata[]")
edit("src/video.c", '#include "video.h"\n', '#include "video.h"\n#include "k4510menu.h"\n')
edit("src/video.c", "SDL_RenderSetLogicalSize(renderer, SCREEN_WIDTH * screen_x_scale, SCREEN_HEIGHT);\n",
     "SDL_RenderSetLogicalSize(renderer, SCREEN_WIDTH * screen_x_scale, SCREEN_HEIGHT);\n"
     "\tk4510_init(SCREEN_WIDTH * screen_x_scale, SCREEN_HEIGHT);\n")
edit("src/video.c", "SDL_RenderCopy(renderer, sdlTexture, NULL, NULL);", "k4510_present_copy(renderer, sdlTexture);")
edit("src/video.c", "\t\tif (event.type == SDL_KEYDOWN) {\n\t\t\tbool consumed = false;\n",
     "\t\tif (event.type == SDL_KEYDOWN) {\n"
     "\t\t\tif (event.key.keysym.sym == SDLK_F12 && !debugger_enabled) {\n"
     "\t\t\t\tif (!k4510_menu(renderer, sdlTexture, framebuffer)) {\n"
     "\t\t\t\t\tprintf(\"Exit to the K4510 (F12 menu)\\n\");\n"
     "\t\t\t\t\tmain_shutdown();\n"
     "\t\t\t\t\texit(0);\n"
     "\t\t\t\t}\n"
     "\t\t\t\tcontinue;\n"
     "\t\t\t}\n"
     "\t\t\tbool consumed = false;\n")
print("apply.py: x16emu patched (F12 menu, placement)")
