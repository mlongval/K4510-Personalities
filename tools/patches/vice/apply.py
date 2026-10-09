# K4510 placement for VICE 3.10's SDL2 UI (run from the source tree by
# build-vice.sh): K4510_PLACEMENT=left draws the picture flush left at full
# height, leaving the right of the screen free (for a sidebar);
# K4510_SCALE=integer scales by whole multiples.  Unset: VICE as it was.
import sys
P = "src/arch/sdl/video_sdl2.c"
s = open(P).read()
def edit(old, new, count=1):
    global s
    if s.count(old) != count:
        sys.exit(f"vice/apply.py: expected {count}x {old!r}, found {s.count(old)}")
    s = s.replace(old, new)

HELPER = r'''
/* K4510 (BMC64Port): the picture's rect in output pixels when
 * K4510_PLACEMENT=left and/or K4510_SCALE=integer; 0 = VICE's own centring.
 * The logical size is switched off for the frame and given back after it. */
static int k4510_place(SDL_Renderer *r, SDL_Rect *d, int *lw, int *lh)
{
    static int left = -1, whole = 0;
    int W, H, w, h;
    if (left < 0) {
        const char *e = getenv("K4510_PLACEMENT");
        left = e && !strcmp(e, "left");
        e = getenv("K4510_SCALE");
        whole = e && !strcmp(e, "integer");
    }
    if (!left && !whole) {
        return 0;
    }
    SDL_RenderGetLogicalSize(r, lw, lh);
    if (*lw <= 0 || *lh <= 0) {
        return 0;
    }
    SDL_RenderSetLogicalSize(r, 0, 0);
    SDL_GetRendererOutputSize(r, &W, &H);
    h = H;
    if (whole && H >= *lh) {
        h = H / *lh * *lh;
    }
    w = (int)((double)h * *lw / *lh);
    if (w > W) {
        w = W;
        h = (int)((double)w * *lh / *lw);
    }
    d->x = left ? 0 : (W - w) / 2;
    d->y = (H - h) / 2;
    d->w = w;
    d->h = h;
    return 1;
}

void video_canvas_refresh('''
edit("\nvoid video_canvas_refresh(", HELPER)
edit("    /* Render. */\n    SDL_RenderClear(canvas->container->renderer);\n",
     "    /* Render. */\n"
     "    k4510 = canvas->videoconfig->rotate ? 0 : k4510_place(canvas->container->renderer, &k4510_rect, &k4510_lw, &k4510_lh);\n"
     "    SDL_RenderClear(canvas->container->renderer);\n")
edit("SDL_RenderCopyEx(canvas->container->renderer, canvas->previous_frame_texture, NULL, NULL, angle, NULL, flip);",
     "SDL_RenderCopyEx(canvas->container->renderer, canvas->previous_frame_texture, NULL, k4510 ? &k4510_rect : NULL, angle, NULL, flip);")
edit("        SDL_RenderCopyEx(canvas->container->renderer, canvas->texture, NULL, NULL, angle, NULL, flip);\n    }\n\n    SDL_RenderPresent(canvas->container->renderer);\n",
     "        SDL_RenderCopyEx(canvas->container->renderer, canvas->texture, NULL, k4510 ? &k4510_rect : NULL, angle, NULL, flip);\n    }\n\n    SDL_RenderPresent(canvas->container->renderer);\n"
     "    if (k4510) {\n        SDL_RenderSetLogicalSize(canvas->container->renderer, k4510_lw, k4510_lh);\n    }\n")
edit("    double angle = 0;\n", "    double angle = 0;\n    SDL_Rect k4510_rect;\n    int k4510 = 0, k4510_lw = 0, k4510_lh = 0;\n")
edit('#include "vice.h"\n', '#include "vice.h"\n\n#include <stdlib.h>\n#include <string.h>\n')
open(P, "w").write(s)
print("vice/apply.py: placement patch in")
