# The K4510's changes to VICE 3.10's SDL2 UI (run from the source tree by
# build-vice.sh), all in src/arch/sdl/video_sdl2.c:
#   K4510_PLACEMENT=left  the picture flush left at full height, the right of
#                         the screen free; K4510_SCALE=integer: whole multiples
#   the sidebar           in that free area: the K4510's scene
#                         (libk4510side.so via k4510host.c), or on the C128
#                         its other display, live (K4510_C128_DUAL=0: off),
#                         the VDC's borders cropped off (K4510_VDC_CROP=0: kept)
# and in src/vdc/vdc.c the area the VDC displayed, for that crop; in
# src/arch/sdl/menu_video.c the 40/80 key in the C128's Video menu.
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

/* x128 only (vdc.c): the area the VDC displayed last frame, raster coords. */
extern int k4510_vdc_area(struct video_canvas_s *canvas, unsigned int *x0, unsigned int *y0,
                          unsigned int *x1, unsigned int *y1) __attribute__((weak));

/* The part of the other canvas's texture to show: all of it, or for the VDC
 * its text area with a margin of 8 pixels, without the wide borders. */
static void k4510_side_crop(struct video_canvas_s *o, SDL_Rect *s)
{
    const char *e = getenv("K4510_VDC_CROP");
    unsigned int x0, y0, x1, y1, m = 8;
    int sx = o->videoconfig->scalex, sy = o->videoconfig->scaley;
    s->x = s->y = 0;
    s->w = o->width;
    s->h = o->height;
    if ((e && !strcmp(e, "0")) || !k4510_vdc_area || !k4510_vdc_area(o, &x0, &y0, &x1, &y1)) {
        return;
    }
    x0 = x0 > o->viewport->first_x + m ? x0 - m - o->viewport->first_x : 0;
    y0 = y0 > o->viewport->first_line + m ? y0 - m - o->viewport->first_line : 0;
    x1 = x1 + m - o->viewport->first_x;
    y1 = y1 + m - o->viewport->first_line;
    s->x = (int)x0 * sx;
    s->y = (int)y0 * sy;
    s->w = MIN((int)x1 * sx, (int)o->width) - s->x;
    s->h = MIN((int)y1 * sy, (int)o->height) - s->y;
    if (s->w < 64 || s->h < 64) {
        s->x = s->y = 0;
        s->w = o->width;
        s->h = o->height;
    }
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
            SDL_Rect d, s;
            double aw, ah;
            k4510_side_crop(o, &s);
            aw = s.w * par;
            ah = s.h;
            d.w = area.w;
            d.h = (int)(area.w * ah / aw);
            if (d.h > H) {
                d.h = H;
                d.w = (int)(H * aw / ah);
            }
            d.x = area.x + (area.w - d.w) / 2;
            d.y = (H - d.h) / 2;
            SDL_RenderCopy(r, k4510_side_tex[i], &s, &d);
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

P = "src/vdc/vdc.c"
s = open(P).read()
edit("\nvdc_t vdc;\n", r'''
vdc_t vdc;

/* K4510 (BMC64Port): the raster lines the VDC displayed in the last frame,
 * for x128's sidebar to crop the borders off (src/arch/sdl/video_sdl2.c). */
static unsigned int k4510_y0 = ~0u, k4510_y1, k4510_top, k4510_bottom;

int k4510_vdc_area(struct video_canvas_s *canvas, unsigned int *x0, unsigned int *y0,
                   unsigned int *x1, unsigned int *y1);
int k4510_vdc_area(struct video_canvas_s *canvas, unsigned int *x0, unsigned int *y0,
                   unsigned int *x1, unsigned int *y1)
{
    if (canvas != vdc.raster.canvas || k4510_bottom <= k4510_top) {
        return 0;
    }
    *x0 = vdc.border_width;
    *x1 = vdc.border_width + vdc.charwidth * vdc.screen_text_cols;
    *y0 = k4510_top;
    *y1 = k4510_bottom + 1;
    return 1;
}
''')
edit("    static unsigned int stable_size_count = 0;\n",
     "    static unsigned int stable_size_count = 0;\n\n"
     "    if (vdc.display_enable) {\n"
     "        k4510_y0 = MIN(k4510_y0, vdc.raster.current_line);\n"
     "        k4510_y1 = MAX(k4510_y1, vdc.raster.current_line);\n"
     "    }\n")
edit("        if (vdc.row_counter == vdc.regs[7]) {\n            vdc.vsync = 1;\n",
     "        if (vdc.row_counter == vdc.regs[7]) {\n"
     "            if (k4510_y0 <= k4510_y1) {\n"
     "                k4510_top = k4510_y0;\n"
     "                k4510_bottom = k4510_y1;\n"
     "            }\n"
     "            k4510_y0 = ~0u;\n"
     "            k4510_y1 = 0;\n"
     "            vdc.vsync = 1;\n")
open(P, "w").write(s)

P = "src/arch/sdl/menu_video.c"
s = open(P).read()
edit("const ui_menu_entry_t c128_video_menu[] = {\n", r'''/* K4510 (BMC64Port): the 40/80 DISPLAY key, latched like the real one.  The
 * C128 reads it at reset: down = start in 80 columns. */
static UI_MENU_CALLBACK(k4510_column_key_callback)
{
    int up = 1;

    resources_get_int("C128ColumnKey", &up);
    if (activated) {
        resources_set_int("C128ColumnKey", !up);
        return NULL;
    }
    return up ? "up (40 cols at reset)" : "down (80 cols at reset)";
}

const ui_menu_entry_t c128_video_menu[] = {
''')
edit("        .data     = (ui_callback_data_t)VIDEO_OUTPUT_DUAL_WINDOW\n    },\n#endif\n    SDL_MENU_ITEM_SEPARATOR,\n",
     "        .data     = (ui_callback_data_t)VIDEO_OUTPUT_DUAL_WINDOW\n    },\n#endif\n"
     "    {   .string   = \"40/80 key\",\n"
     "        .type     = MENU_ENTRY_OTHER,\n"
     "        .callback = k4510_column_key_callback\n"
     "    },\n"
     "    SDL_MENU_ITEM_SEPARATOR,\n")
open(P, "w").write(s)
print("vice/apply.py: placement, sidebar, C128 dual display, VDC crop, 40/80 key in")
