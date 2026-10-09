# The K4510's changes to VICE 3.10's SDL2 UI (run from the source tree by
# build-vice.sh), all in src/arch/sdl/video_sdl2.c:
#   K4510_PLACEMENT=left  the picture flush left at full height, the right of
#                         the screen free; K4510_SCALE=integer: whole multiples
#   the sidebar           in that free area: the K4510's scene
#                         (libk4510side.so via k4510host.c), or on the C128
#                         its other display, live (K4510_C128_DUAL=0: off)
# Unset: VICE as it was.
import os, shutil, sys
here = os.path.dirname(os.path.abspath(__file__))
for f in ("k4510host.c", "k4510host.h", "k4510host_sdl2.c", "k4510host_sdl2.h"):
    shutil.copy(os.path.join(here, "..", "common", f), "src/arch/sdl/" + f)
P = "src/arch/sdl/video_sdl2.c"
s = open(P).read()
def edit(old, new, count=1):
    global s
    if s.count(old) != count:
        sys.exit(f"vice/apply.py: expected {count}x {old!r}, found {s.count(old)}")
    s = s.replace(old, new)

HELPER = r'''
/* K4510 (BMC64Port) ------------------------------------------------------ */
static int k4510_left = -1, k4510_whole = 0;

static void k4510_env(void)
{
    if (k4510_left < 0) {
        const char *e = getenv("K4510_PLACEMENT");
        k4510_left = e && !strcmp(e, "left");
        e = getenv("K4510_SCALE");
        k4510_whole = e && !strcmp(e, "integer");
    }
}

/* The picture's rect in output pixels when placed left and/or scaled by whole
 * multiples; 0 = VICE's own centring.  The logical size is switched off for
 * the frame and given back after it. */
static int k4510_place(SDL_Renderer *r, SDL_Rect *d, int *lw, int *lh)
{
    int W, H, w, h;
    k4510_env();
    if (!k4510_left && !k4510_whole) {
        return 0;
    }
    SDL_RenderGetLogicalSize(r, lw, lh);
    if (*lw <= 0 || *lh <= 0) {
        return 0;
    }
    SDL_RenderSetLogicalSize(r, 0, 0);
    SDL_GetRendererOutputSize(r, &W, &H);
    h = H;
    if (k4510_whole && H >= *lh) {
        h = H / *lh * *lh;
    }
    w = (int)((double)h * *lw / *lh);
    if (w > W) {
        w = W;
        h = (int)((double)w * *lh / *lw);
    }
    d->x = k4510_left ? 0 : (W - w) / 2;
    d->y = (H - h) / 2;
    d->w = w;
    d->h = h;
    return 1;
}

#include "k4510host.c"
#include "k4510host_sdl2.c"

static SDL_Texture *k4510_side_tex[2];
static SDL_Renderer *k4510_side_ren[2];
static int k4510_side_w[2], k4510_side_h[2];

/* The C128 with placement=left shows both chips: the active one's picture on
 * the left, the other live in the free area; VICE's own switch swaps them. */
static int k4510_dual(struct video_canvas_s *canvas)
{
    const char *e = getenv("K4510_C128_DUAL");
    k4510_env();
    return k4510_left && machine_class == VICE_MACHINE_C128 && sdl_num_screens == 2
        && !(e && !strcmp(e, "0"))
        && canvas->container == sdl_canvaslist[canvas->index ^ 1]->container;
}

/* The inactive canvas: render its frame and keep it in its own texture. */
static void k4510_side_refresh(struct video_canvas_s *canvas, unsigned int xs, unsigned int ys,
                               unsigned int xi, unsigned int yi, unsigned int w, unsigned int h)
{
    int i = canvas->index & 1;
    SDL_Renderer *r;
    if (!canvas->screen || !canvas->container || !(r = canvas->container->renderer)) {
        return;
    }
    xi *= canvas->videoconfig->scalex;
    w *= canvas->videoconfig->scalex;
    yi *= canvas->videoconfig->scaley;
    h *= canvas->videoconfig->scaley;
    w = MIN(w, canvas->width);
    h = MIN(h, canvas->height);
    if ((xi + w > canvas->width) || (yi + h > canvas->height)) {
        return;
    }
    video_canvas_render(canvas, (uint8_t *)canvas->screen->pixels, w, h, xs, ys, xi, yi, canvas->screen->pitch);
    if (!k4510_side_tex[i] || k4510_side_ren[i] != r
        || k4510_side_w[i] != canvas->screen->w || k4510_side_h[i] != canvas->screen->h) {
        if (k4510_side_tex[i] && k4510_side_ren[i] == r) {
            SDL_DestroyTexture(k4510_side_tex[i]);
        }
        k4510_side_tex[i] = SDL_CreateTexture(r, canvas->screen->format->format, SDL_TEXTUREACCESS_STREAMING,
                                              canvas->screen->w, canvas->screen->h);
        k4510_side_ren[i] = r;
        k4510_side_w[i] = canvas->screen->w;
        k4510_side_h[i] = canvas->screen->h;
        if (!k4510_side_tex[i]) {
            return;
        }
        SDL_SetTextureBlendMode(k4510_side_tex[i], SDL_BLENDMODE_NONE);
    }
    SDL_UpdateTexture(k4510_side_tex[i], NULL, canvas->screen->pixels, canvas->screen->pitch);
}

/* Fill the free area beside the active canvas's picture. */
static void k4510_sidebar(struct video_canvas_s *canvas, SDL_Renderer *r, SDL_Rect *pic)
{
    int W, H;
    SDL_Rect area;
    SDL_GetRendererOutputSize(r, &W, &H);
    area.x = pic->x + pic->w;
    area.y = 0;
    area.w = W - area.x;
    area.h = H;
    if (area.w < 16) {
        return;
    }
    if (k4510_dual(canvas)) {
        struct video_canvas_s *o = sdl_canvaslist[canvas->index ^ 1];
        int i = o->index & 1;
        if (k4510_side_tex[i] && k4510_side_ren[i] == r && o->height > 0 && o->width > 0) {
            double par = o->videoconfig->aspect_mode == VIDEO_ASPECT_MODE_NONE ? 1.0
                       : o->videoconfig->aspect_mode == VIDEO_ASPECT_MODE_CUSTOM ? o->videoconfig->aspect_ratio
                       : o->geometry->pixel_aspect_ratio;
            double aw = o->width * par, ah = o->height;
            SDL_Rect d;
            d.w = area.w;
            d.h = (int)(area.w * ah / aw);
            if (d.h > H) {
                d.h = H;
                d.w = (int)(H * aw / ah);
            }
            d.x = area.x + (area.w - d.w) / 2;
            d.y = (H - d.h) / 2;
            SDL_RenderCopy(r, k4510_side_tex[i], NULL, &d);
        }
        return;
    }
    k4510host_sdl2(r, area);
}
/* ------------------------------------------------------------------------- */

void video_canvas_refresh('''
edit("\nvoid video_canvas_refresh(", HELPER)
edit("    double angle = 0;\n", "    double angle = 0;\n    SDL_Rect k4510_rect;\n    int k4510 = 0, k4510_lw = 0, k4510_lh = 0;\n")
edit("    if (sdl_canvas_is_visible(canvas) == 0) {\n        return;\n    }\n",
     "    if (sdl_canvas_is_visible(canvas) == 0) {\n"
     "        if (k4510_dual(canvas)) {\n"
     "            k4510_side_refresh(canvas, xs, ys, xi, yi, w, h);\n"
     "        }\n"
     "        return;\n    }\n")
edit("    /* Render. */\n    SDL_RenderClear(canvas->container->renderer);\n",
     "    /* Render. */\n"
     "    k4510 = canvas->videoconfig->rotate ? 0 : k4510_place(canvas->container->renderer, &k4510_rect, &k4510_lw, &k4510_lh);\n"
     "    SDL_RenderClear(canvas->container->renderer);\n")
edit("SDL_RenderCopyEx(canvas->container->renderer, canvas->previous_frame_texture, NULL, NULL, angle, NULL, flip);",
     "SDL_RenderCopyEx(canvas->container->renderer, canvas->previous_frame_texture, NULL, k4510 ? &k4510_rect : NULL, angle, NULL, flip);")
edit("        SDL_RenderCopyEx(canvas->container->renderer, canvas->texture, NULL, NULL, angle, NULL, flip);\n    }\n\n    SDL_RenderPresent(canvas->container->renderer);\n",
     "        SDL_RenderCopyEx(canvas->container->renderer, canvas->texture, NULL, k4510 ? &k4510_rect : NULL, angle, NULL, flip);\n    }\n\n"
     "    if (k4510 && k4510_left) {\n        k4510_sidebar(canvas, canvas->container->renderer, &k4510_rect);\n    }\n"
     "    SDL_RenderPresent(canvas->container->renderer);\n"
     "    if (k4510) {\n        SDL_RenderSetLogicalSize(canvas->container->renderer, k4510_lw, k4510_lh);\n    }\n")
edit('#include "vice.h"\n', '#include "vice.h"\n\n#include <stdlib.h>\n#include <string.h>\n')
open(P, "w").write(s)
print("vice/apply.py: placement, sidebar, C128 dual display in")
