/* k4510c64.c -- the C64's, the C128's and the PET's own sidebar
 * (K4532-Personalities, 2026-10-17): on x64sc, x128 and xpet with
 * placement=left, the free area beside the picture shows the machine itself
 * instead of a K4532 scene, in its case's colour -- the breadbin's brown
 * beige, the C128's light beige; the PET's in its screen's own two colours,
 * read from the palette each frame, so a palette chosen in F12 (green, amber,
 * white) is followed -- and lettered in its own character ROM, whole
 * characters on an 8x8 grid:
 *
 *   the drive      a drawing of the 1541 (the C128: the 1571, the PET: its
 *                  Drive8Type, the 2031 at first): its LED
 *                  lit while it works, the head's track, the lever down when
 *                  a disk is in
 *   the directory  as LOAD"$",8 lists it; click a program: it is loaded
 *                  and run (VICE's autostart)
 *   DISKS          the disks in ~/personalities/<name> (VICE's starting
 *                  directory) and its folders; click one: it goes in drive 8
 *                  (a .PRG, .T64 or .CRT runs at once); EJECT takes it out
 *   SD #9          the SD volume (a folder, VICE's filesystem device, as an
 *                  SD2IEC is); BROWSE runs Dir Browser (DB64 / DB128) on it;
 *                  not on the PET
 *   KEYS           the machine's keys on the PC's (-keymap 0, sdl_sym.vkm;
 *                  the PET's too, sdl_grus_sym.vkm)
 *
 * On the C128 the screen it is not showing (the VDC or the VIC-II) is drawn
 * along the bottom of the sidebar, below this (video_sdl2.c, c64panel.py).
 *
 * Interactive by the mouse: VICE shows no pointer in fullscreen, so the
 * sidebar draws its own while the mouse is over it; the wheel scrolls a list.
 * K4510_C64_PANEL=0: the K4532 scene as before; K4510_C64_DEBUG=1 logs each
 * click and where it fell.  Included by video_sdl2.c
 * (vice/apply.py); ui.c hands it the mouse's events (k4510c64_event). */
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include "attach.h"
#include "autostart.h"
#include "charset.h"
#include "diskimage.h"
#include "drive.h"
#include "driveimage.h"
#include "drivetypes.h"
#include "imagecontents.h"
#include "diskcontents.h"

extern uint8_t mem_chargen_rom[] __attribute__((weak));   /* the C64s, the C128 and the PET have it; not every VICE program */
static int c64p_stride = 8;                      /* a character's bytes in it: the PET's are 16 apart (petrom.c) */

/* the machine: its case, its lettering, its drive, its keys */
typedef struct {
    const char *title, *drive, *browser;
    uint32_t bg, shade, light, text, dim, folder;   /* the case, its shadow and edge, the keys' lettering, a quieter one, a folder */
    uint32_t dbody, dshade;                         /* the drive's case */
    uint32_t power, led, ledoff;                    /* its lights */
    int rainbow, wide;                              /* the C64 badge's stripes; the 1571's wider front */
    const char *const (*keys)[2];
} c64p_theme_t;

static const char *const c64p_keys64[][2] = {
    { "ESC", "RUN/STOP" }, { "PGUP", "RESTORE" }, { "TAB", "C=" }, { "CTRL", "CTRL" },
    { "CAPS", "SHIFT LOCK" }, { "HOME", "CLR/HOME" }, { "INS", "INST" }, { "\\", "`" },
    { "~ OR END", "~" }, { "PGDN", "^" }, { "F12", "VICE'S MENU" }, { NULL, NULL } };
static const char *const c64p_keys128[][2] = {
    { "ESC", "RUN/STOP" }, { "PGUP", "RESTORE" }, { "TAB", "C=" }, { "CTRL", "CTRL" },
    { "F9", "ESC" }, { "F11", "ALT" }, { "END", "HELP" }, { "PGDN", "LINE FEED" },
    { "HOME", "CLR/HOME" }, { "KEYPAD /", "40/80" }, { "KEYPAD *", "NO SCROLL" },
    { "\\", "`" }, { "~", "~" }, { "F12", "VICE'S MENU" }, { NULL, NULL } };
static const char *const c64p_keyspet[][2] = {     /* the graphics keyboard by symbol (sdl_grus_sym.vkm) */
    { "ESC", "RUN/STOP" }, { "HOME", "CLR/HOME" }, { "TAB", "RVS ON/OFF" }, { "CAPS", "SHIFT LOCK" },
    { "BACKSPACE", "INST/DEL" }, { "INS", "INST" }, { "END OR ~", "~" }, { "PGDN", "^" },
    { "F12", "VICE'S MENU" }, { NULL, NULL } };

static const c64p_theme_t c64p_c64 = {
    " COMMODORE 64 ", "1541 #8", "DB64",
    0xa89c86, 0x8a7f6c, 0xbcb19b, 0x3a2f28, 0x6b5e50, 0x7a3b26,
    0xb3a891, 0x7e7363, 0x3fbf3f, 0xff3020, 0x5a2018, 1, 0, c64p_keys64 };
static const c64p_theme_t c64p_c128 = {
    " COMMODORE 128 ", "1571 #8", "DB128",
    0xd8d0bc, 0xb8af9b, 0xe8e2d2, 0x3e3833, 0x7a7268, 0x6e3a2a,
    0xe4ddcb, 0xa69d89, 0x3fbf3f, 0xff3020, 0x5a2018, 0, 1, c64p_keys128 };
static c64p_theme_t c64p_pet = {                /* its colours: the screen's (c64p_pet_colours) */
    " COMMODORE PET ", NULL, NULL,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, c64p_keyspet };
static char c64p_petdrive[16];
static const c64p_theme_t *c64p_t = &c64p_c64;

static int c64p_on = -1;
static uint32_t *c64p_px, c64p_last_ms, c64p_move_ms;
static int c64p_w, c64p_h, c64p_k, c64p_mx = -1, c64p_my = -1;
static SDL_Rect c64p_area;                       /* the buffer on the screen, output pixels */
static SDL_Texture *c64p_tex;
static SDL_Renderer *c64p_ren;
static int c64p_tw, c64p_th;
static char c64p_sd[1024];                       /* the SD volume, drive 9 (K4510_SD) */

/* what the mouse can click, as the last frame drew it (machine pixels) */
enum { H_ENTRY = 1, H_DISKS, H_BACK, H_EJECT, H_FILE, H_UP, H_DOWN, H_BROWSE };
#define C64P_HITS 128
static struct { int x, y, w, h, what, arg; } c64p_hit[C64P_HITS];
static int c64p_nhit;

/* the directory of the disk in drive 8: screen codes, a line each */
#define C64P_LINES 300
static uint8_t c64p_line[C64P_LINES][32];
static int c64p_len[C64P_LINES], c64p_prg[C64P_LINES], c64p_nline, c64p_free = -1;
static char c64p_disk[1024];
static time_t c64p_disk_mtime;
static off_t c64p_disk_size;
static int c64p_disk_ok;

/* the disk chooser */
static int c64p_view, c64p_scroll[2];
static char c64p_root[1024], c64p_cwd[1024];
#define C64P_FILES 512
static struct { char name[128]; int dir; } c64p_file[C64P_FILES];
static int c64p_nfile;

static uint32_t
c64p_now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000);
}

int k4510c64_active(void);
int
k4510c64_active(void)
{
    if (c64p_on < 0) {
        const char *e = getenv("K4510_C64_PANEL"), *sd = getenv("K4510_SD");
        int c64 = machine_class == VICE_MACHINE_C64SC || machine_class == VICE_MACHINE_C64;
        int pet = machine_class == VICE_MACHINE_PET;
        c64p_on = (c64 || pet || machine_class == VICE_MACHINE_C128) && mem_chargen_rom && !(e && !strcmp(e, "0"));
        c64p_t = c64 ? &c64p_c64 : pet ? &c64p_pet : &c64p_c128;
        c64p_stride = pet ? 16 : 8;
        if (c64p_on && getcwd(c64p_root, sizeof c64p_root)) {
            snprintf(c64p_cwd, sizeof c64p_cwd, "%s", c64p_root);
        }
        snprintf(c64p_sd, sizeof c64p_sd, "%s", sd ? sd : "");
    }
    return c64p_on;
}

/* the PET: the screen's background and phosphor, from the palette VICE draws
 * with now, and the shades between them; its drive, whatever Drive8Type is */
static uint32_t
c64p_mix(uint32_t a, uint32_t b, int t)          /* t/256 of the way from a to b */
{
    uint32_t c = 0;
    int i;
    for (i = 0; i < 24; i += 8) {
        int x = (int)((a >> i) & 255), y = (int)((b >> i) & 255);
        c |= (uint32_t)(x + (y - x) * t / 256) << i;
    }
    return c;
}
static void
c64p_pet_colours(struct video_canvas_s *canvas)
{
    uint32_t bg = 0x000000, fg = 0x41ff00;
    int type = 0;
    if (canvas && canvas->palette && canvas->palette->num_entries >= 2) {
        const palette_entry_t *p = canvas->palette->entries;
        bg = ((uint32_t)p[0].red << 16) | ((uint32_t)p[0].green << 8) | p[0].blue;
        fg = ((uint32_t)p[1].red << 16) | ((uint32_t)p[1].green << 8) | p[1].blue;
    }
    if (bg != c64p_pet.bg || fg != c64p_pet.text || !c64p_pet.drive) log_message(LOG_DEFAULT, "k4510c64: the PET's colours %06x on %06x", fg, bg);
    c64p_pet.bg = bg;
    c64p_pet.text = fg;
    c64p_pet.dim = c64p_mix(bg, fg, 150);
    c64p_pet.shade = c64p_mix(bg, fg, 70);
    c64p_pet.light = c64p_mix(bg, fg, 110);
    c64p_pet.folder = c64p_mix(bg, fg, 200);
    c64p_pet.dbody = c64p_mix(bg, fg, 45);
    c64p_pet.dshade = c64p_mix(bg, fg, 25);
    c64p_pet.power = fg;
    c64p_pet.led = fg;
    c64p_pet.ledoff = c64p_mix(bg, fg, 60);
    resources_get_int("Drive8Type", &type);
    snprintf(c64p_petdrive, sizeof c64p_petdrive, type ? "%d #8" : "NO DRIVE 8", type);
    c64p_pet.drive = c64p_petdrive;
    c64p_pet.wide = type == DRIVE_TYPE_2040 || type == DRIVE_TYPE_3040 || type == DRIVE_TYPE_4040
                 || type == DRIVE_TYPE_8050 || type == DRIVE_TYPE_8250;   /* the two-drive cases */
}

/* ---- drawing, in machine pixels --------------------------------------------- */
static void
c64p_fill(int x, int y, int w, int h, uint32_t c)
{
    int i, j;
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > c64p_w) w = c64p_w - x;
    if (y + h > c64p_h) h = c64p_h - y;
    c |= 0xff000000u;
    for (j = 0; j < h; j++) {
        uint32_t *p = c64p_px + (size_t)(y + j) * c64p_w + x;
        for (i = 0; i < w; i++) p[i] = c;
    }
}
static void
c64p_char(int x, int y, uint8_t sc, uint32_t fg, uint32_t bg)   /* screen code sc (128-255: reversed, as the ROM has them) */
{
    const uint8_t *g = mem_chargen_rom + sc * c64p_stride;
    int i, j;
    if (x < 0 || y < 0 || x + 8 > c64p_w || y + 8 > c64p_h) return;
    fg |= 0xff000000u; bg |= 0xff000000u;
    for (j = 0; j < 8; j++) {
        uint32_t *p = c64p_px + (size_t)(y + j) * c64p_w + x;
        for (i = 0; i < 8; i++) p[i] = (g[j] & (0x80 >> i)) ? fg : bg;
    }
}
static uint8_t
c64p_sc(char c)                                  /* ASCII to a screen code: ^ is the up arrow, ~ the left one, ` the pound */
{
    if (c >= 'a' && c <= 'z') return (uint8_t)(c - 'a' + 1);
    if (c >= 'A' && c <= 'Z') return (uint8_t)(c - 'A' + 1);
    if (c >= 0x20 && c <= 0x3f) return (uint8_t)c;
    switch (c) {
    case '@': return 0;
    case '[': return 27;
    case '`': return 28;
    case ']': return 29;
    case '^': return 30;
    case '~': return 31;
    case '\\': return 0x4d;                      /* the graphic diagonal, the nearest the ROM has */
    }
    return '?';
}
static void
c64p_text(int col, int row, const char *s, uint32_t fg, uint32_t bg, int rev)
{
    for (; *s && col < c64p_w / 8; s++, col++) c64p_char(col * 8, row * 8, (uint8_t)(c64p_sc(*s) | (rev ? 0x80 : 0)), fg, bg);
}
static void
c64p_hitbox(int x, int y, int w, int h, int what, int arg)
{
    if (c64p_nhit < C64P_HITS) {
        c64p_hit[c64p_nhit].x = x; c64p_hit[c64p_nhit].y = y;
        c64p_hit[c64p_nhit].w = w; c64p_hit[c64p_nhit].h = h;
        c64p_hit[c64p_nhit].what = what; c64p_hit[c64p_nhit].arg = arg;
        c64p_nhit++;
    }
}
static int
c64p_over(int x, int y, int w, int h)
{
    return c64p_mx >= x && c64p_mx < x + w && c64p_my >= y && c64p_my < y + h;
}
/* a button: a key, lettered reversed; the case's own light while the mouse is on it */
static int
c64p_button(int col, int row, const char *s, int what)
{
    int n = (int)strlen(s);
    int on = c64p_over(col * 8, row * 8, n * 8, 8);
    c64p_text(col, row, s, on ? c64p_t->folder : c64p_t->text, c64p_t->bg, 1);
    c64p_hitbox(col * 8, row * 8, n * 8, 8, what, 0);
    return col + n + 1;
}

/* ---- the drive ---------------------------------------------------------------- */
static void
c64p_drive(int x, int y)                          /* the 1541's front, 112 x 40 (the 1571's: its slot higher, the lever right) */
{
    drive_t *d = diskunit_context[0] ? diskunit_context[0]->drives[0] : NULL;
    const char *disk = file_system_get_disk_name(8, 0);
    int led = d && d->led_status, in = disk && *disk;
    c64p_fill(x, y, 112, 40, c64p_t->dbody);            /* the case */
    c64p_fill(x, y + 38, 112, 2, c64p_t->dshade);
    c64p_fill(x + 111, y, 1, 40, c64p_t->dshade);
    c64p_fill(x, y, 112, 1, c64p_t->light);
    if (!c64p_t->wide) {
        c64p_fill(x + 6, y + 10, 100, 18, c64p_t->dshade);   /* the door's recess */
        c64p_fill(x + 8, y + 17, 96, 4, 0x000000);     /* the slot */
        if (in) {
            c64p_fill(x + 52, y + 8, 8, 22, c64p_t->text);   /* the lever turned down: closed on a disk */
            c64p_fill(x + 54, y + 10, 4, 18, c64p_t->dim);
        } else {
            c64p_fill(x + 42, y + 15, 28, 8, c64p_t->text);  /* across: open */
            c64p_fill(x + 44, y + 17, 24, 4, c64p_t->dim);
        }
    } else {
        c64p_fill(x + 6, y + 8, 100, 12, c64p_t->dshade);
        c64p_fill(x + 10, y + 12, 80, 4, 0x000000);
        if (in) c64p_fill(x + 92, y + 6, 8, 16, c64p_t->text);
        else c64p_fill(x + 86, y + 10, 18, 8, c64p_t->text);
    }
    c64p_fill(x + 8, y + 31, 7, 3, c64p_t->power);      /* power, green */
    c64p_fill(x + 18, y + 31, 7, 3, led ? c64p_t->led : c64p_t->ledoff);   /* drive, red while it works */
    c64p_fill(x + 82, y + 30, 22, 5, c64p_t->dshade);   /* the badge */
}
static void
c64p_track(int col, int row)
{
    drive_t *d = diskunit_context[0] ? diskunit_context[0]->drives[0] : NULL;
    char b[24];
    int ht = d ? d->current_half_track : 36, x = col * 8, y = row * 8 + 2, i, type = 0, n = 35;
    resources_get_int("Drive8Type", &type);
    if (type == DRIVE_TYPE_8050 || type == DRIVE_TYPE_8250 || type == DRIVE_TYPE_1001) n = 77;   /* the PET's big drives */
    snprintf(b, sizeof b, "TRACK %2d%s", ht / 2, ht & 1 ? "+" : " ");
    c64p_text(col, row - 1, b, c64p_t->text, c64p_t->bg, 0);
    c64p_fill(x, y, 72, 4, c64p_t->shade);              /* 35 tracks, two pixels each (77: as many as fit) */
    for (i = 0; i < n; i += 5) c64p_fill(x + 1 + i * 70 / n, y + 4, 1, 2, c64p_t->shade);
    if (ht > 2 * n) ht = 2 * n;
    c64p_fill(x + (ht - 2) * 35 / n, y - 1, 2, 6, c64p_t->text);   /* the head */
}

/* ---- the directory ------------------------------------------------------------ */
static void
c64p_put(int n, const uint8_t *petscii, int len, int prg)
{
    int i;
    if (c64p_nline >= C64P_LINES) return;
    for (i = 0; i < len && i < 32; i++) {
        uint8_t c = petscii[i] == 0xa0 ? ' ' : petscii[i];   /* the name's padding: a space, as LIST shows it */
        c64p_line[c64p_nline][i] = charset_petscii_to_screencode(c, 0);
    }
    c64p_len[c64p_nline] = i;
    c64p_prg[c64p_nline] = prg ? n : 0;
    c64p_nline++;
}
static void
c64p_read_dir(void)
{
    const char *disk = file_system_get_disk_name(8, 0);
    struct stat st;
    image_contents_t *c;
    image_contents_file_list_t *p;
    uint8_t raw[64];
    int n = 0;
    if (!disk || !*disk) {
        if (c64p_disk_ok || c64p_disk[0]) { c64p_disk[0] = 0; c64p_nline = 0; c64p_disk_ok = 0; }
        return;
    }
    if (stat(disk, &st)) return;
    if (c64p_disk_ok && !strcmp(disk, c64p_disk) && st.st_mtime == c64p_disk_mtime && st.st_size == c64p_disk_size) return;
    snprintf(c64p_disk, sizeof c64p_disk, "%s", disk);
    c64p_disk_mtime = st.st_mtime; c64p_disk_size = st.st_size; c64p_disk_ok = 1;
    c64p_nline = 0; c64p_free = -1; c64p_scroll[0] = 0;
    if (!(c = diskcontents_filesystem_read(disk))) return;
    snprintf((char *)raw, sizeof raw, "%d \"%-16.16s\" %s", c->partition, (const char *)c->name, (const char *)c->id);
    c64p_put(0, raw, (int)strlen((char *)raw), 0);
    for (p = c->file_list; p; p = p->next) {
        int i;
        n++;
        int q;                                     /* the blocks in 3 (LIST gives 5): 27 columns hold a line */
        snprintf((char *)raw, sizeof raw, "%-3u \"", p->size);
        q = (int)strlen((char *)raw);
        memset(raw + q, ' ', IMAGE_CONTENTS_FILE_NAME_LEN + 2);
        memcpy(raw + q, p->name, IMAGE_CONTENTS_FILE_NAME_LEN);
        for (i = 0; i < IMAGE_CONTENTS_FILE_NAME_LEN && raw[q + i] != 0xa0 && raw[q + i]; i++) ;
        raw[q + i] = '"';
        for (i++; i < IMAGE_CONTENTS_FILE_NAME_LEN + 1; i++) raw[q + i] = ' ';
        memcpy(raw + q + IMAGE_CONTENTS_FILE_NAME_LEN + 2, p->type, 5);
        raw[q + IMAGE_CONTENTS_FILE_NAME_LEN + 7] = 0;
        c64p_put(n, raw, (int)strlen((char *)raw), strstr((const char *)p->type, "PRG") != NULL);
    }
    if (c->blocks_free >= 0) {
        c64p_free = c64p_nline;
        snprintf((char *)raw, sizeof raw, "%d BLOCKS FREE.", c->blocks_free);
        c64p_put(0, raw, (int)strlen((char *)raw), 0);
    }
    image_contents_destroy(c);
}

/* ---- the disk chooser ----------------------------------------------------------- */
static int
c64p_ext(const char *n, const char *const *list)
{
    const char *e = strrchr(n, '.');
    if (!e) return 0;
    for (; *list; list++) if (!strcasecmp(e, *list)) return 1;
    return 0;
}
static const char *const c64p_disks[] = { ".d64", ".d71", ".d81", ".g64", ".x64", ".d80", ".d82", ".d67", NULL };
static const char *const c64p_runs[] = { ".prg", ".t64", ".crt", ".p00", NULL };
static int
c64p_cmp(const void *a, const void *b)
{
    const char *x = (const char *)a, *y = (const char *)b;
    int dx = *(const int *)(x + 128), dy = *(const int *)(y + 128);
    if (dx != dy) return dy - dx;                 /* folders first */
    return strcasecmp(x, y);
}
static void
c64p_read_files(void)
{
    DIR *d = opendir(c64p_cwd);
    struct dirent *e;
    c64p_nfile = 0; c64p_scroll[1] = 0;
    if (strcmp(c64p_cwd, c64p_root)) {            /* up a folder, not past where VICE started */
        snprintf(c64p_file[0].name, sizeof c64p_file[0].name, "..");
        c64p_file[0].dir = 2;
        c64p_nfile = 1;
    }
    if (!d) return;
    while ((e = readdir(d)) && c64p_nfile < C64P_FILES) {
        char path[2048];
        struct stat st;
        if (e->d_name[0] == '.' || strlen(e->d_name) >= sizeof c64p_file[0].name) continue;
        snprintf(path, sizeof path, "%s/%s", c64p_cwd, e->d_name);
        if (stat(path, &st)) continue;
        if (!S_ISDIR(st.st_mode) && !c64p_ext(e->d_name, c64p_disks) && !c64p_ext(e->d_name, c64p_runs)) continue;
        snprintf(c64p_file[c64p_nfile].name, sizeof c64p_file[0].name, "%s", e->d_name);
        c64p_file[c64p_nfile].dir = S_ISDIR(st.st_mode);
        c64p_nfile++;
    }
    closedir(d);
    qsort(c64p_file + (c64p_file[0].dir == 2), (size_t)(c64p_nfile - (c64p_file[0].dir == 2)), sizeof c64p_file[0], c64p_cmp);
}
static void
c64p_attach(const char *path)                     /* in drive 8, the drive made a type that reads it */
{
    struct disk_image_s *di;
    if (file_system_attach_disk(8, 0, path) < 0) return;
    di = file_system_get_image(8, 0);
    if (di && drive_check_image_format(di->type, 0) < 0) {
        int t = drive_image_type_to_drive_type(di->type);
        if (machine_class == VICE_MACHINE_PET && t == DRIVE_TYPE_1541II) t = DRIVE_TYPE_2031;   /* a .D64 on the PET's bus */
        resources_set_int("Drive8Type", t);
        file_system_detach_disk(8, 0);
        file_system_attach_disk(8, 0, path);
    }
}
static void
c64p_choose(int i)
{
    char path[2048];
    if (i < 0 || i >= c64p_nfile) return;
    if (c64p_file[i].dir == 2) {
        char *s = strrchr(c64p_cwd, '/');
        if (s && s != c64p_cwd) *s = 0;
        c64p_read_files();
        return;
    }
    snprintf(path, sizeof path, "%s/%s", c64p_cwd, c64p_file[i].name);
    if (c64p_file[i].dir) {
        if (strlen(path) < sizeof c64p_cwd) { snprintf(c64p_cwd, sizeof c64p_cwd, "%s", path); c64p_read_files(); }
        return;
    }
    log_message(LOG_DEFAULT, "k4510c64: %s %s", c64p_ext(path, c64p_runs) ? "run" : "drive 8:", path);
    if (c64p_ext(path, c64p_runs)) autostart_autodetect(path, NULL, 0, AUTOSTART_MODE_RUN);
    else c64p_attach(path);
    c64p_view = 0;
}
static void
c64p_browse(void)                                 /* Dir Browser, from the SD volume */
{
    char path[1100];
    snprintf(path, sizeof path, "%s/%s", c64p_sd, c64p_t->browser);
    log_message(LOG_DEFAULT, "k4510c64: browse: %s", path);
    autostart_autodetect(path, NULL, 0, AUTOSTART_MODE_RUN);
}

static void
c64p_click(int x, int y)
{
    int i;
    for (i = 0; i < c64p_nhit; i++) {
        if (x < c64p_hit[i].x || x >= c64p_hit[i].x + c64p_hit[i].w || y < c64p_hit[i].y || y >= c64p_hit[i].y + c64p_hit[i].h) continue;
        switch (c64p_hit[i].what) {
        case H_ENTRY:
            log_message(LOG_DEFAULT, "k4510c64: %s, program %d: load and run", c64p_disk, c64p_hit[i].arg);
            autostart_disk(8, 0, c64p_disk, NULL, (unsigned int)c64p_hit[i].arg, AUTOSTART_MODE_RUN);
            break;
        case H_DISKS: c64p_view = 1; c64p_read_files(); log_message(LOG_DEFAULT, "k4510c64: disks in %s, %d", c64p_cwd, c64p_nfile); break;
        case H_BACK:  c64p_view = 0; break;
        case H_EJECT: log_message(LOG_DEFAULT, "k4510c64: eject"); file_system_detach_disk(8, 0); break;
        case H_FILE:  c64p_choose(c64p_hit[i].arg); break;
        case H_UP:    c64p_scroll[c64p_view] -= 5; break;
        case H_DOWN:  c64p_scroll[c64p_view] += 5; break;
        case H_BROWSE: c64p_browse(); break;
        }
        return;
    }
}

static void
c64p_render(uint32_t ms)
{
    int cols = c64p_w / 8, rows = c64p_h / 8, r, i, top, bottom, n, first, nkeys;
    char b[64];
    c64p_nhit = 0;
    c64p_fill(0, 0, c64p_w, c64p_h, c64p_t->bg);
    c64p_fill(0, 0, 2, c64p_h, c64p_t->light);          /* the case's edge, lit from the left */
    /* the title, and the C64 badge's rainbow (the C128: a plain rule) */
    c64p_text(1, 1, c64p_t->title, c64p_t->text, c64p_t->bg, 1);
    {
        int x = ((int)strlen(c64p_t->title) + 2) * 8, w = c64p_w - x - 8;
        static const uint32_t rb[5] = { 0xd02a1e, 0xe8781c, 0xf2c81a, 0x4a9a3a, 0x2a6ab8 };
        if (c64p_t->rainbow) for (i = 0; i < 5; i++) c64p_fill(x, 8 + i * 2 - 1, w, 2, rb[i]);
        else c64p_fill(x, 11, w, 2, c64p_t->text);
    }
    /* the drive */
    c64p_drive(8, 24);
    c64p_text(16, 3, c64p_t->drive, c64p_t->text, c64p_t->bg, 0);
    c64p_track(16, 6);
    /* the SD volume, drive 9 */
    r = 9;
    if (c64p_sd[0] && c64p_t->browser) {
        c64p_text(1, r, "SD #9", c64p_t->text, c64p_t->bg, 0);
        c64p_button(7, r, " BROWSE ", H_BROWSE);
        r += 2;
    }
    for (nkeys = 0; c64p_t->keys[nkeys][0]; nkeys++) ;
    if (nkeys > rows - r - 12) nkeys = rows - r - 12 > 0 ? rows - r - 12 : 0;   /* a short sidebar (the C128's): the first keys */
    top = r + 1;
    bottom = rows - nkeys - 3;
    if (c64p_view == 0) {
        c64p_read_dir();
        if (!c64p_nline) {
            c64p_text(1, r, "NO DISK IN DRIVE 8.", c64p_t->text, c64p_t->bg, 0);
            c64p_text(1, r + 2, "CLICK DISKS FOR ONE.", c64p_t->dim, c64p_t->bg, 0);
            n = 0;
        } else {
            /* the header reversed, as LIST prints it */
            for (i = 0; i < c64p_len[0] && 1 + i < cols; i++) c64p_char((1 + i) * 8, r * 8, (uint8_t)(c64p_line[0][i] | 0x80), c64p_t->text, c64p_t->bg);
            n = c64p_nline - 1;
        }
    } else {
        const char *rel = c64p_cwd + strlen(c64p_root);
        snprintf(b, sizeof b, " DISKS %s/", *rel ? rel : "");
        if ((int)strlen(b) > cols - 2) { memmove(b + 1, b + strlen(b) - (cols - 3), (size_t)(cols - 2)); b[0] = ' '; }
        c64p_text(1, r, b, c64p_t->text, c64p_t->bg, 1);
        n = c64p_nfile;
    }
    /* the list, scrolled; ^ and v when there is more */
    {
        int room = bottom - top - 1, s = c64p_scroll[c64p_view];
        if (room < 1) room = 1;
        if (s > n - room) s = n - room;
        if (s < 0) s = 0;
        c64p_scroll[c64p_view] = s;
        first = s;
        for (i = 0; i < room && first + i < n; i++) {
            int row = top + i, j = first + i, on, y = row * 8;
            if (c64p_view == 0) {
                int L = j + 1, clk = c64p_prg[L] > 0, k, skip = cols < 29 && L != c64p_free ? 4 : 0;   /* narrow: no blocks */
                on = clk && c64p_over(8, y, (cols - 2) * 8, 8);
                for (k = 0; k + skip < c64p_len[L] && 1 + k < cols; k++)
                    c64p_char((1 + k) * 8, y, (uint8_t)(c64p_line[L][k + skip] | (on ? 0x80 : 0)), on ? c64p_t->folder : (clk ? c64p_t->text : c64p_t->dim), c64p_t->bg);
                if (clk) c64p_hitbox(8, y, (cols - 2) * 8, 8, H_ENTRY, c64p_prg[L]);
            } else {
                int dir = c64p_file[j].dir;
                on = c64p_over(8, y, (cols - 2) * 8, 8);
                if (dir == 2) snprintf(b, sizeof b, "^ UP");
                else snprintf(b, sizeof b, "%.*s%s", cols - 3, c64p_file[j].name, dir ? "/" : "");
                c64p_text(1, row, b, on ? c64p_t->folder : dir ? c64p_t->folder : c64p_t->text, c64p_t->bg, on);
                c64p_hitbox(8, y, (cols - 2) * 8, 8, H_FILE, j);
            }
        }
        if (first > 0) { c64p_text(cols - 2, top - 1, "^", c64p_t->text, c64p_t->bg, 1); c64p_hitbox((cols - 2) * 8, (top - 1) * 8, 8, 8, H_UP, 0); }
        if (first + room < n) {
            snprintf(b, sizeof b, "%d MORE", n - first - room);
            c64p_text(cols - 2 - (int)strlen(b) - 1, top + room, b, c64p_t->dim, c64p_t->bg, 0);
            c64p_text(cols - 2, top + room, "V", c64p_t->text, c64p_t->bg, 1);
            c64p_hitbox(0, (top + room) * 8, c64p_w, 8, H_DOWN, 0);
        }
    }
    /* the buttons */
    {
        int col = 1, row = bottom;
        col = c64p_view ? c64p_button(col, row, " BACK ", H_BACK) : c64p_button(col, row, " DISKS ", H_DISKS);
        if (file_system_get_disk_name(8, 0)) c64p_button(col, row, " EJECT ", H_EJECT);
    }
    /* the keys */
    if (nkeys) {
        r = rows - nkeys - 2;
        c64p_fill(8, r * 8 + 3, c64p_w - 16, 1, c64p_t->shade);
        c64p_text(1, r + 1, " KEYS ", c64p_t->text, c64p_t->bg, 1);
        for (i = 0; i < nkeys; i++) {
            c64p_text(1, r + 2 + i, c64p_t->keys[i][0], c64p_t->dim, c64p_t->bg, 0);
            c64p_text(11, r + 2 + i, c64p_t->keys[i][1], c64p_t->text, c64p_t->bg, 0);
        }
    }
    /* the pointer, while the mouse is here and moving now and then */
    if (c64p_mx >= 0 && ms - c64p_move_ms < 4000) {
        static const char *const arrow[] = {
            "X.........", "XX........", "XWX.......", "XWWX......", "XWWWX.....", "XWWWWX....",
            "XWWWWWX...", "XWWWWWWX..", "XWWWWXXXX.", "XWXWWX....", "XX.XWWX...", "X...XWX...", "....XX...." };
        int j;
        for (j = 0; j < 13; j++)
            for (i = 0; i < 10; i++)
                if (arrow[j][i] != '.') c64p_fill(c64p_mx + i, c64p_my + j, 1, 1, c64p_t == &c64p_pet ? (arrow[j][i] == 'W' ? c64p_t->text : c64p_t->bg)
                                                                                     : arrow[j][i] == 'W' ? 0xffffff : 0x000000);
    }
}

/* ---- to the screen ------------------------------------------------------------------ */
static void
k4510c64_draw(struct video_canvas_s *canvas, SDL_Renderer *r, SDL_Rect area)
{
    uint32_t ms = c64p_now();
    int k, w, h, fresh = 0;
    /* whole machine pixels, as large as leaves 24 columns of text (27 show
     * the blocks in the directory too; the PET's narrow sidebar has 24) */
    k = area.w / (24 * 8);
    if (k < 1) k = 1;
    if (k > 4) k = 4;
    w = area.w / k; h = area.h / k;
    if (w < 64 || h < 160) return;
    if (w != c64p_w || h != c64p_h) {
        free(c64p_px);
        c64p_px = (uint32_t *)calloc((size_t)w * h, 4);
        if (!c64p_px) { c64p_w = c64p_h = 0; return; }
        c64p_w = w; c64p_h = h; c64p_last_ms = ms - 1000;
        log_message(LOG_DEFAULT, "k4510c64: the panel at %d,%d, %dx%d machine pixels x%d", area.x + (area.w - w * k) / 2, area.y, w, h, k);
    }
    c64p_k = k;
    c64p_area.x = area.x + (area.w - w * k) / 2; c64p_area.y = area.y;
    c64p_area.w = w * k; c64p_area.h = h * k;
    if (ms - c64p_last_ms >= 33) {
        if (c64p_t == &c64p_pet) c64p_pet_colours(canvas);
        c64p_render(ms);
        c64p_last_ms = ms;
        fresh = 1;
    }
    if (!c64p_tex || c64p_ren != r || c64p_tw != w || c64p_th != h) {
        if (c64p_tex && c64p_ren == r) SDL_DestroyTexture(c64p_tex);
        c64p_tex = SDL_CreateTexture(r, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, w, h);
        if (!c64p_tex) return;
        SDL_SetTextureScaleMode(c64p_tex, SDL_ScaleModeNearest);
        SDL_SetTextureBlendMode(c64p_tex, SDL_BLENDMODE_NONE);
        c64p_ren = r; c64p_tw = w; c64p_th = h; fresh = 1;
    }
    if (fresh) SDL_UpdateTexture(c64p_tex, NULL, c64p_px, w * 4);
    {   /* the case's colour under the whole area, the rounding left over included */
        SDL_SetRenderDrawColor(r, (c64p_t->bg >> 16) & 255, (c64p_t->bg >> 8) & 255, c64p_t->bg & 255, 255);
        SDL_RenderFillRect(r, &area);
    }
    SDL_RenderCopy(r, c64p_tex, NULL, &c64p_area);
}

/* ui.c's event loop: the mouse over the sidebar is the sidebar's (1: taken) */
int k4510c64_event(SDL_Event *e);
int
k4510c64_event(SDL_Event *e)
{
    int wx, wy;
    if (c64p_on <= 0 || !c64p_k || sdl_menu_state || SDL_GetRelativeMouseMode()) return 0;
    if (e->type != SDL_MOUSEMOTION && e->type != SDL_MOUSEBUTTONDOWN && e->type != SDL_MOUSEBUTTONUP && e->type != SDL_MOUSEWHEEL) return 0;
    SDL_GetMouseState(&wx, &wy);
    if (e->type == SDL_MOUSEBUTTONDOWN && getenv("K4510_C64_DEBUG")) log_message(LOG_DEFAULT, "k4510c64: button at %d,%d (event %d,%d), the panel %d,%d %dx%d", wx, wy, e->button.x, e->button.y, c64p_area.x, c64p_area.y, c64p_area.w, c64p_area.h);
    if (wx < c64p_area.x || wx >= c64p_area.x + c64p_area.w || wy < c64p_area.y || wy >= c64p_area.y + c64p_area.h) {
        c64p_mx = c64p_my = -1;
        return 0;
    }
    c64p_mx = (wx - c64p_area.x) / c64p_k;
    c64p_my = (wy - c64p_area.y) / c64p_k;
    c64p_move_ms = c64p_now();
    c64p_last_ms -= 1000;                          /* the pointer, now */
    if (e->type == SDL_MOUSEBUTTONDOWN && e->button.button == SDL_BUTTON_LEFT) c64p_click(c64p_mx, c64p_my);
    else if (e->type == SDL_MOUSEWHEEL) c64p_scroll[c64p_view] -= e->wheel.y * 3;
    return e->type != SDL_MOUSEMOTION;
}
