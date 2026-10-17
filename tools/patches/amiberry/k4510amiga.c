/* k4510amiga.c -- the A1200's own sidebar (K4532-Personalities, 2026-10-17):
 * with placement=left the free area beside the picture shows the Amiga
 * itself instead of a K4532 scene, in the A1200's off-white, lettered in its
 * own Topaz 8 (taken from the Kickstart by tools/topaz.py, K4510_TOPAZ):
 *
 *   the LEDs       power, floppy and hard drive, as on the A1200's strip
 *   DF0:           the disk in the drive, its motor, the head's track
 *   DH0: DH1:      the hard drives (Workbench; Work, 20 MB)
 *   the touchpad   how it clicks (amiberry.cpp's finger handling, below)
 *   KEYS           the Amiga's keys on the PC's (Amiberry's keyboard.cpp)
 *
 * It only shows: the mouse belongs to the Amiga.  K4510_AMIGA_PANEL=0 gives
 * the K4532 scene back.  Included at the end of sdl_renderer.cpp
 * (amiberry/apply.py); k4510_sidebar there calls k4510amiga_draw first. */
#include "gui.h"
#include "options.h"

static int ap_on = -1, ap_w, ap_h;
static uint32_t *ap_px, ap_last;
static uint8_t ap_font[256 * 8];
static SDL_Texture* ap_tex;
static SDL_Renderer* ap_ren;

#define AP_BG     0xd9d5c8u   /* the A1200's case */
#define AP_SHADE  0xb5b0a2u
#define AP_LIGHT  0xeceadfu
#define AP_TEXT   0x34342fu   /* its keys' lettering */
#define AP_DIM    0x77746bu

static void ap_fill(int x, int y, int w, int h, uint32_t c)
{
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > ap_w) w = ap_w - x;
    if (y + h > ap_h) h = ap_h - y;
    for (int j = 0; j < h; j++)
        for (int i = 0; i < w; i++) ap_px[(size_t)(y + j) * ap_w + x + i] = 0xff000000u | c;
}
static void ap_text(int col, int row, const char* s, uint32_t fg, uint32_t bg, int rev)
{
    for (; *s && col < ap_w / 8; s++, col++) {
        const uint8_t* g = ap_font + (uint8_t)*s * 8;
        int x = col * 8, y = row * 8;
        if (y + 8 > ap_h) return;
        for (int j = 0; j < 8; j++)
            for (int i = 0; i < 8; i++) {
                int on = (g[j] & (0x80 >> i)) != 0;
                ap_px[(size_t)(y + j) * ap_w + x + i] = 0xff000000u | ((on != rev) ? fg : bg);
            }
    }
}
static void ap_led(int x, int y, const char* label, uint32_t on, int lit)
{
    ap_fill(x, y, 14, 4, AP_SHADE);
    ap_fill(x + 1, y + 1, 12, 2, lit ? on : 0x55524a);
    ap_text(x / 8, y / 8 + 1, label, AP_DIM, AP_BG, 0);
}
static const char* ap_base(const char* p)
{
    const char* b = strrchr(p, '/');
    return b ? b + 1 : p;
}

static void ap_render(void)
{
    static const char* const keys[][2] = {
        { "L.Win, Ins", "Left Amiga" }, { "R.Win, Home", "Right Amiga" }, { "Menu", "Right Amiga" },
        { "PgDn", "Help" }, { "Del", "Del" }, { "Ctrl", "Ctrl" }, { "Alt", "Alt" },
        { "F12", "Amiberry's menu" }, { nullptr, nullptr } };
    static const uint32_t tick[6] = { 0xe0282c, 0xf2861b, 0xf7d11e, 0x3ea544, 0x2b6cb5, 0x7b3c96 };
    int cols = ap_w / 8, rows = ap_h / 8, r, i, n;
    char b[96];
    const gui_info_drive& df0 = gui_data.drives[0];
    ap_fill(0, 0, ap_w, ap_h, AP_BG);
    ap_fill(0, 0, 2, ap_h, AP_LIGHT);
    ap_text(1, 1, " AMIGA 1200 ", AP_TEXT, AP_BG, 1);
    for (i = 0; i < 6; i++) ap_fill(14 * 8 + i * 6, 7 + (5 - i), 5, 2 + i, tick[i]);   /* the checkmark's stripes, rising */
    /* the LED strip */
    ap_fill(8, 24, ap_w - 16, 22, AP_SHADE);
    ap_fill(9, 25, ap_w - 18, 20, AP_LIGHT);
    ap_led(16, 28, "Power", 0x3fbf3f, gui_data.powerled);
    ap_led(16 + 9 * 8, 28, "Floppy", 0xffb020, df0.drive_motor);
    ap_led(16 + 18 * 8, 28, "HD", 0xffb020, gui_data.hd > 0);
    /* the drives */
    r = 7;
    ap_text(1, r, "DF0:", AP_TEXT, AP_BG, 1);
    if (df0.df[0]) snprintf(b, sizeof b, "%.*s", cols - 7, ap_base(df0.df));
    else snprintf(b, sizeof b, "no disk");
    ap_text(6, r, b, df0.df[0] ? AP_TEXT : AP_DIM, AP_BG, 0);
    snprintf(b, sizeof b, "track %2d%s", df0.drive_track, df0.drive_motor ? "  turning" : "");
    ap_text(6, r + 1, b, AP_DIM, AP_BG, 0);
    ap_fill(6 * 8, (r + 2) * 8 + 2, 80 + 2, 4, AP_SHADE);    /* 80 cylinders */
    ap_fill(6 * 8 + df0.drive_track, (r + 2) * 8 + 1, 2, 6, AP_TEXT);
    r += 4;
    ap_text(1, r, "DH0:", AP_TEXT, AP_BG, 1);
    ap_text(6, r, "Workbench", AP_TEXT, AP_BG, 0);
    ap_text(1, r + 1, "DH1:", AP_TEXT, AP_BG, 1);
    ap_text(6, r + 1, "Work, 20 MB", AP_TEXT, AP_BG, 0);
    r += 3;
    /* the touchpad */
    ap_text(1, r, " Touchpad ", AP_TEXT, AP_BG, 1);
    ap_text(1, r + 1, "tap: click", AP_TEXT, AP_BG, 0);
    ap_text(1, r + 2, "two fingers: right", AP_TEXT, AP_BG, 0);
    ap_text(1, r + 3, "tap, then hold: drag", AP_TEXT, AP_BG, 0);
    /* the keys, at the bottom */
    for (n = 0; keys[n][0]; n++) ;
    r = rows - n - 2;
    if (r > 0) {
        ap_fill(8, r * 8 + 3, ap_w - 16, 1, AP_SHADE);
        ap_text(1, r + 1, " Keys ", AP_TEXT, AP_BG, 1);
        for (i = 0; i < n; i++) {
            ap_text(1, r + 2 + i, keys[i][0], AP_DIM, AP_BG, 0);
            ap_text(14, r + 2 + i, keys[i][1], AP_TEXT, AP_BG, 0);
        }
    }
}

/* the free area right of ax, W x H output pixels: 1 drawn, 0 not ours */
static int k4510amiga_draw(SDL_Renderer* r, int ax, int W, int H)
{
    if (ap_on < 0) {
        const char* e = getenv("K4510_AMIGA_PANEL");
        const char* f = getenv("K4510_TOPAZ");
        FILE* fp = f ? fopen(f, "rb") : nullptr;
        ap_on = fp && !(e && !strcmp(e, "0")) && fread(ap_font, 1, sizeof ap_font, fp) == sizeof ap_font;
        if (fp) fclose(fp);
    }
    if (!ap_on || W - ax < 64) return 0;
    int aw = W - ax, k = aw / (27 * 8);
    if (k < 1) k = 1;
    if (k > 4) k = 4;
    int w = aw / k, h = H / k;
    if (w != ap_w || h != ap_h) {
        free(ap_px);
        ap_px = static_cast<uint32_t*>(calloc(static_cast<size_t>(w) * h, 4));
        if (!ap_px) { ap_w = ap_h = 0; return 0; }
        ap_w = w; ap_h = h; ap_last = 0;
    }
    const uint32_t now = SDL_GetTicks();
    int fresh = 0;
    if (now - ap_last >= 33 || !ap_last) { ap_render(); ap_last = now ? now : 1; fresh = 1; }
    if (!ap_tex || ap_ren != r || ap_tex->w != w || ap_tex->h != h) {
        if (ap_tex && ap_ren == r) SDL_DestroyTexture(ap_tex);
        ap_tex = SDL_CreateTexture(r, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, w, h);
        if (!ap_tex) return 0;
        SDL_SetTextureScaleMode(ap_tex, SDL_SCALEMODE_NEAREST);
        SDL_SetTextureBlendMode(ap_tex, SDL_BLENDMODE_NONE);
        ap_ren = r; fresh = 1;
    }
    if (fresh) SDL_UpdateTexture(ap_tex, nullptr, ap_px, w * 4);
    SDL_SetRenderDrawColor(r, (AP_BG >> 16) & 255, (AP_BG >> 8) & 255, AP_BG & 255, 255);
    SDL_FRect all = { static_cast<float>(ax), 0.0f, static_cast<float>(aw), static_cast<float>(H) };
    SDL_RenderFillRect(r, &all);
    SDL_FRect d = { static_cast<float>(ax), 0.0f, static_cast<float>(w * k), static_cast<float>(h * k) };
    SDL_RenderTexture(r, ap_tex, nullptr, &d);
    return 1;
}
