// k4510menu.c -- the K4510 personality's additions to x16emu (BMC64Port,
// tools/build-x16.sh compiles it in and hooks it into video.c):
//
//   F12        a menu, like VICE's and the K4510's: Resume, Reset, Warp,
//              Placement, Scale, Exit to the K4510.  The machine stops
//              while it is open.  Alt+F4 and POWEROFF still quit as before.
//   placement  the picture centred (x16emu's own way), or flush LEFT at full
//              height, which leaves a rect on the right free for a sidebar.
//   scale      fit the screen, or whole multiples of 480 lines (sharp).
//   sidebar    the K4510's scene in the free area (libk4510side.so, found
//              by K4510_SIDEBAR_LIB; K4510_SIDEBAR names the scene).
//
// Placement and scale start from K4510_PLACEMENT=left|centre and
// K4510_SCALE=fit|integer, and what the menu sets is kept in the file named
// by K4510_X16_SETTINGS (run/x16 points it into ~/personalities/x16).
#include <SDL.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "k4510menu.h"
#include "timing.h"
#include "k4510host_sdl2.h"

extern unsigned char fontdata[];        // rendertext.c's 5x7 font, 0x20..0x7f
extern bool warp_mode;
void machine_reset(void);
void machine_toggle_warp(void);
void main_shutdown(void);

static int place_left = 0, scale_int = 0;
static int lw = 640, lh = 480;           // the picture's logical size
static SDL_Rect sidebar;                 // the free area, w == 0 when none

static void
save_settings(void)
{
	const char *p = getenv("K4510_X16_SETTINGS");
	if (!p) return;
	// keep the lines that are not ours (vdcborders=, written by the C128)
	char keep[2048] = "", line[256], tmp[512];
	size_t n = 0;
	FILE *f = fopen(p, "r");
	if (f) {
		while (fgets(line, sizeof line, f)) {
			if (!strncmp(line, "placement=", 10) || !strncmp(line, "scale=", 6) || !strncmp(line, "sidebar=", 8)) continue;
			if (n + strlen(line) >= sizeof keep) break;
			strcpy(keep + n, line);
			n += strlen(line);
		}
		fclose(f);
	}
	snprintf(tmp, sizeof tmp, "%s.tmp", p);
	if (!(f = fopen(tmp, "w"))) return;
	char name[32] = "none";
	sscanf(k4510host_scene(), "%31s", name);
	fprintf(f, "placement=%s\nscale=%s\nsidebar=%s\n%s", place_left ? "left" : "centre", scale_int ? "integer" : "fit", name, keep);
	if (fclose(f) == 0) rename(tmp, p);
}

void
k4510_init(int logical_w, int logical_h)
{
	lw = logical_w; lh = logical_h;
	const char *e;
	if ((e = getenv("K4510_PLACEMENT"))) place_left = !strcmp(e, "left");
	if ((e = getenv("K4510_SCALE"))) scale_int = !strcmp(e, "integer");
	const char *p = getenv("K4510_X16_SETTINGS");
	FILE *f = p ? fopen(p, "r") : NULL;
	if (f) {
		char line[64];
		while (fgets(line, sizeof line, f)) {
			if (!strncmp(line, "placement=", 10)) place_left = !strncmp(line + 10, "left", 4);
			if (!strncmp(line, "scale=", 6)) scale_int = !strncmp(line + 6, "integer", 7);
		}
		fclose(f);
	}
}

// The free rect beside the picture, in output pixels (w == 0: none).  For a
// sidebar to draw into later; see BMC64Port's README.
SDL_Rect
k4510_sidebar_rect(void)
{
	return sidebar;
}

// Replaces video.c's SDL_RenderCopy(renderer, sdlTexture, NULL, NULL).
void
k4510_present_copy(SDL_Renderer *r, SDL_Texture *t)
{
	if (!place_left && !scale_int) {
		int w, h;
		SDL_RenderGetLogicalSize(r, &w, &h);
		if (w != lw || h != lh) SDL_RenderSetLogicalSize(r, lw, lh);
		sidebar.w = 0;
		SDL_RenderCopy(r, t, NULL, NULL);
		return;
	}
	SDL_RenderSetLogicalSize(r, 0, 0);
	SDL_RenderSetViewport(r, NULL);
	int W, H;
	SDL_GetRendererOutputSize(r, &W, &H);
	int h = H;
	if (scale_int && H >= lh) h = H / lh * lh;
	int w = h * lw / lh;
	if (w > W) { w = W; h = w * lh / lw; }
	SDL_Rect d = { place_left ? 0 : (W - w) / 2, (H - h) / 2, w, h };
	SDL_RenderCopy(r, t, NULL, &d);
	sidebar = (SDL_Rect){ d.x + d.w, 0, W - (d.x + d.w), H };
	if (!place_left) sidebar.w = 0;
	else k4510host_sdl2(r, sidebar);
}

// --- the menu: drawn into a copy of the frame, 2x the debugger's 5x7 font
#define FW 640
#define FH 480
static uint8_t menubuf[FW * FH * 4];

static void
put_char(int x, int y, int ch, uint32_t rgb, int s)
{
	if (ch < 0x20 || ch > 0x7f) ch = '?';
	for (int cx = 0; cx < 5; cx++) {
		int bits = fontdata[(ch - 0x20) * 5 + cx];
		for (int cy = 0; cy < 7; cy++, bits >>= 1) {
			if (!(bits & 1)) continue;
			for (int dy = 0; dy < s; dy++) for (int dx = 0; dx < s; dx++) {
				int px = x + cx * s + dx, py = y + cy * s + dy;
				if (px < 0 || py < 0 || px >= FW || py >= FH) continue;
				uint8_t *p = &menubuf[(py * FW + px) * 4];
				p[0] = rgb; p[1] = rgb >> 8; p[2] = rgb >> 16;
			}
		}
	}
}

static void
put_str(int x, int y, const char *s, uint32_t rgb)
{
	for (; *s; s++, x += 12) put_char(x, y, *s, rgb, 2);
}

static void
fill(int x, int y, int w, int h, uint32_t rgb)
{
	for (int j = y; j < y + h; j++) for (int i = x; i < x + w; i++) {
		uint8_t *p = &menubuf[(j * FW + i) * 4];
		p[0] = rgb; p[1] = rgb >> 8; p[2] = rgb >> 16;
	}
}

enum { M_RESUME, M_RESET, M_WARP, M_PLACE, M_SCALE, M_SIDEBAR, M_EXIT, M_N };

static const char *scenes[] = { "none", "antfarm", "matrix", "space", "river", "dreamfall", "tetris", "halloween", "christmas" };
#define N_SCENES (int)(sizeof scenes / sizeof scenes[0])

static void
next_scene(int dir)
{
	char name[32] = "none";
	sscanf(k4510host_scene(), "%31s", name);
	int i = 0;
	while (i < N_SCENES && strcmp(scenes[i], name)) i++;
	i = ((i < N_SCENES ? i : 0) + dir + N_SCENES) % N_SCENES;
	char cfg[300];
	const char *home = getenv("HOME");
	if (i == 0) snprintf(cfg, sizeof cfg, "none");
	else snprintf(cfg, sizeof cfg, "%s state=%s/personalities/sidebar", scenes[i], home ? home : "/tmp");
	k4510host_set(cfg);
}

static void
draw_menu(const uint8_t *frame, int sel)
{
	for (int i = 0; i < FW * FH * 4; i++) menubuf[i] = (i & 3) == 3 ? 0 : frame[i] * 2 / 5;
	int x = 150, y = 120, w = 340, h = 40 + M_N * 26 + 34;
	fill(x - 4, y - 4, w + 8, h + 8, 0xc0c0c0);
	fill(x, y, w, h, 0x202060);
	put_str(x + 16, y + 12, "COMMANDER X16", 0xffffff);
	char line[40];
	for (int i = 0; i < M_N; i++) {
		switch (i) {
		case M_RESUME: strcpy(line, "Resume"); break;
		case M_RESET:  strcpy(line, "Reset"); break;
		case M_WARP:   sprintf(line, "Warp: %s", warp_mode ? "on" : "off"); break;
		case M_PLACE:  sprintf(line, "Placement: %s", place_left ? "left" : "centre"); break;
		case M_SCALE:  sprintf(line, "Scale: %s", scale_int ? "whole" : "fit"); break;
		case M_SIDEBAR: {
			char name[32] = "none";
			sscanf(k4510host_scene(), "%31s", name);
			snprintf(line, sizeof line, "Sidebar: %s", name);
			break;
		}
		case M_EXIT:   strcpy(line, "Exit to the K4510"); break;
		}
		int ly = y + 40 + i * 26;
		if (i == sel) fill(x + 8, ly - 4, w - 16, 22, 0xffffff);
		put_str(x + 16, ly, line, i == sel ? 0x202060 : 0xffffff);
	}
	put_str(x + 16, y + h - 22, "F12/Esc: back", 0x9090c0);
}

// Called from video.c on F12.  Runs until the menu is closed; the machine
// waits.  Returns false for Exit (the caller ends the emulator).
bool
k4510_menu(SDL_Renderer *r, SDL_Texture *t, const uint8_t *frame)
{
	int sel = M_RESUME;
	for (;;) {
		draw_menu(frame, sel);
		SDL_UpdateTexture(t, NULL, menubuf, FW * 4);
		SDL_RenderClear(r);
		k4510_present_copy(r, t);
		SDL_RenderPresent(r);
		SDL_Event e;
		if (!SDL_WaitEventTimeout(&e, 100)) continue;
		if (e.type == SDL_QUIT) return false;
		if (e.type != SDL_KEYDOWN) continue;
		SDL_Keycode k = e.key.keysym.sym;
		if (k == SDLK_F12 || k == SDLK_ESCAPE) break;
		if (k == SDLK_UP) sel = (sel + M_N - 1) % M_N;
		else if (k == SDLK_DOWN) sel = (sel + 1) % M_N;
		else if (k == SDLK_RETURN || k == SDLK_KP_ENTER || k == SDLK_LEFT || k == SDLK_RIGHT || k == SDLK_SPACE) {
			if (sel == M_RESUME) break;
			if (sel == M_RESET) { machine_reset(); break; }
			if (sel == M_EXIT) return false;
			if (sel == M_WARP) machine_toggle_warp();
			if (sel == M_PLACE) { place_left = !place_left; save_settings(); }
			if (sel == M_SCALE) { scale_int = !scale_int; save_settings(); }
			if (sel == M_SIDEBAR) { next_scene(k == SDLK_LEFT ? -1 : 1); save_settings(); }
		}
	}
	// swallow what is still queued (the F12 release, a held key's repeats)
	SDL_PumpEvents();
	SDL_FlushEvents(SDL_KEYDOWN, SDL_KEYUP);
	timing_init();      // the stop is not time to catch up on
	return true;
}
