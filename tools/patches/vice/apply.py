# The K4510's changes to VICE 3.10's SDL2 UI (run from the source tree by
# build-vice.sh), all in src/arch/sdl/video_sdl2.c:
#   K4510_PLACEMENT=left  the picture flush left at full height, the right of
#                         the screen free; K4510_SCALE=integer: whole multiples
#   the sidebar           in that free area: the K4510's scene
#                         (libk4510side.so via k4510host.c), or on the C128
#                         its other display, live (K4510_C128_DUAL=0: off),
#                         the VDC's borders cropped off (K4510_VDC_CROP=0: kept)
# and in src/vdc/vdc.c the area the VDC displayed, for that crop; in
# src/arch/sdl/menu_video.c the 40/80 key and VDC borders on/off (saved as
# vdcborders= in K4510_DISPLAY_CFG) in the C128's Video menu.
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
static int k4510_left = -1, k4510_whole = 0, k4510_borders = 1;

static void k4510_env(void)
{
    if (k4510_left < 0) {
        const char *e = getenv("K4510_PLACEMENT");
        k4510_left = e && !strcmp(e, "left");
        e = getenv("K4510_SCALE");
        k4510_whole = e && !strcmp(e, "integer");
        e = getenv("K4510_VDC_BORDERS");
        k4510_borders = !(e && !strcmp(e, "off"));
    }
}

/* x128 only (vdc.c): the area the VDC displayed last frame, raster coords. */
extern int k4510_vdc_area(struct video_canvas_s *canvas, unsigned int *x0, unsigned int *y0,
                          unsigned int *x1, unsigned int *y1) __attribute__((weak));

/* The VDC's text area with a margin of 8 pixels, without its wide borders,
 * in the canvas's pixels; 0 when the canvas is not the VDC's. */
static int k4510_vdc_crop(struct video_canvas_s *o, SDL_Rect *s)
{
    unsigned int x0, y0, x1, y1, m = 8;
    int sx = o->videoconfig->scalex, sy = o->videoconfig->scaley;
    if (!k4510_vdc_area || !k4510_vdc_area(o, &x0, &y0, &x1, &y1)) {
        return 0;
    }
    x0 = x0 > o->viewport->first_x + m ? x0 - m - o->viewport->first_x : 0;
    y0 = y0 > o->viewport->first_line + m ? y0 - m - o->viewport->first_line : 0;
    x1 = x1 + m - o->viewport->first_x;
    y1 = y1 + m - o->viewport->first_line;
    s->x = (int)x0 * sx;
    s->y = (int)y0 * sy;
    s->w = MIN((int)x1 * sx, (int)o->width) - s->x;
    s->h = MIN((int)y1 * sy, (int)o->height) - s->y;
    return s->w >= 64 && s->h >= 64;
}

/* F12 -> Video settings -> VDC borders (menu_video.c): with them off, the VDC
 * as the main display shows its text area only, scaled up.  The choice is
 * kept in display.cfg (K4510_DISPLAY_CFG) as vdcborders=on|off. */
int k4510_vdc_borders(int toggle);
int k4510_vdc_borders(int toggle)
{
    const char *p = getenv("K4510_DISPLAY_CFG");
    char buf[4096], tmp[4096 + 16], line[256];
    size_t n = 0;
    FILE *f;
    k4510_env();
    if (!toggle) {
        return k4510_borders;
    }
    k4510_borders = !k4510_borders;
    if (!p) {
        return k4510_borders;
    }
    buf[0] = 0;
    if ((f = fopen(p, "r"))) {
        while (fgets(line, sizeof line, f)) {
            if (strncmp(line, "vdcborders=", 11) && n + strlen(line) < sizeof buf - 32) {
                strcpy(buf + n, line);
                n += strlen(line);
            }
        }
        fclose(f);
    }
    snprintf(tmp, sizeof tmp, "%s.tmp", p);
    if ((f = fopen(tmp, "w"))) {
        fprintf(f, "%svdcborders=%s\n", buf, k4510_borders ? "on" : "off");
        if (fclose(f) == 0) {
            rename(tmp, p);
        }
    }
    return k4510_borders;
}

/* The picture's rect in output pixels when placed left and/or scaled by whole
 * multiples, and the part of the canvas shown (all of it, or the VDC without
 * its borders); 0 = VICE's own centring.  The logical size is switched off
 * for the frame and given back after it. */
static int k4510_place(struct video_canvas_s *canvas, SDL_Renderer *r, SDL_Rect *d, SDL_Rect *src, int *lw, int *lh)
{
    int W, H, w, h, crop;
    double cw, ch;
    k4510_env();
    crop = !k4510_borders && !sdl_menu_state && k4510_vdc_crop(canvas, src);   /* the F12 menu is laid out on the whole canvas */
    if (!k4510_left && !k4510_whole && !crop) {
        return 0;
    }
    SDL_RenderGetLogicalSize(r, lw, lh);
    if (*lw <= 0 || *lh <= 0) {
        return 0;
    }
    if (!crop) {
        src->x = src->y = 0;
        src->w = canvas->width;
        src->h = canvas->height;
    }
    cw = (double)*lw * src->w / canvas->width;
    ch = (double)*lh * src->h / canvas->height;
    SDL_RenderSetLogicalSize(r, 0, 0);
    SDL_GetRendererOutputSize(r, &W, &H);
    h = H;
    if (k4510_whole && H >= (int)ch && (int)ch > 0) {
        h = H / (int)ch * (int)ch;
    }
    w = (int)(h * cw / ch);
    if (w > W) {
        w = W;
        h = (int)(w * ch / cw);
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

/* The part of the other canvas's texture to show: all of it, or for the VDC
 * its text area (K4510_VDC_CROP=0: all of it too). */
static void k4510_side_crop(struct video_canvas_s *o, SDL_Rect *s)
{
    const char *e = getenv("K4510_VDC_CROP");
    if ((e && !strcmp(e, "0")) || !k4510_vdc_crop(o, s)) {
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
edit("    double angle = 0;\n", "    double angle = 0;\n    SDL_Rect k4510_rect, k4510_src;\n    int k4510 = 0, k4510_lw = 0, k4510_lh = 0;\n")
edit("    if (sdl_canvas_is_visible(canvas) == 0) {\n        return;\n    }\n",
     "    if (sdl_canvas_is_visible(canvas) == 0) {\n"
     "        if (k4510_dual(canvas)) {\n"
     "            k4510_side_refresh(canvas, xs, ys, xi, yi, w, h);\n"
     "        }\n"
     "        return;\n    }\n")
edit("    /* Render. */\n    SDL_RenderClear(canvas->container->renderer);\n",
     "    /* Render. */\n"
     "    k4510 = canvas->videoconfig->rotate ? 0 : k4510_place(canvas, canvas->container->renderer, &k4510_rect, &k4510_src, &k4510_lw, &k4510_lh);\n"
     "    SDL_RenderClear(canvas->container->renderer);\n")
edit("SDL_RenderCopyEx(canvas->container->renderer, canvas->previous_frame_texture, NULL, NULL, angle, NULL, flip);",
     "SDL_RenderCopyEx(canvas->container->renderer, canvas->previous_frame_texture, k4510 ? &k4510_src : NULL, k4510 ? &k4510_rect : NULL, angle, NULL, flip);")
edit("        SDL_RenderCopyEx(canvas->container->renderer, canvas->texture, NULL, NULL, angle, NULL, flip);\n    }\n\n    SDL_RenderPresent(canvas->container->renderer);\n",
     "        SDL_RenderCopyEx(canvas->container->renderer, canvas->texture, k4510 ? &k4510_src : NULL, k4510 ? &k4510_rect : NULL, angle, NULL, flip);\n    }\n\n"
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

/* K4510: the VDC's borders as the main display (video_sdl2.c keeps it). */
extern int k4510_vdc_borders(int toggle);

static UI_MENU_CALLBACK(k4510_vdc_borders_callback)
{
    if (activated) {
        k4510_vdc_borders(1);
        return NULL;
    }
    return k4510_vdc_borders(0) ? "on" : "off";
}

const ui_menu_entry_t c128_video_menu[] = {
''')
edit("        .data     = (ui_callback_data_t)VIDEO_OUTPUT_DUAL_WINDOW\n    },\n#endif\n    SDL_MENU_ITEM_SEPARATOR,\n",
     "        .data     = (ui_callback_data_t)VIDEO_OUTPUT_DUAL_WINDOW\n    },\n#endif\n"
     "    {   .string   = \"40/80 key\",\n"
     "        .type     = MENU_ENTRY_OTHER,\n"
     "        .callback = k4510_column_key_callback\n"
     "    },\n"
     "    {   .string   = \"VDC borders\",\n"
     "        .type     = MENU_ENTRY_OTHER,\n"
     "        .callback = k4510_vdc_borders_callback\n"
     "    },\n"
     "    SDL_MENU_ITEM_SEPARATOR,\n")
open(P, "w").write(s)
print("vice/apply.py: placement, sidebar, C128 dual display, VDC crop, 40/80 key in")
