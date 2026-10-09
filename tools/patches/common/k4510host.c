/* k4510host.c -- see k4510host.h. */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "k4510host.h"

static int (*s_init)(const char *);
static void (*s_draw)(uint32_t *, int, int, int, uint32_t);
static void (*s_quit)(void);
static int loaded, running;
static char scene[128] = "none";
static uint32_t *buf;
static int bw, bh, last_ms = -1000;

static uint32_t
now_ms(void)
{
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000);
}

static void
stop(void)
{
	if (running && s_quit) s_quit();
	running = 0;
}

static void
load(void)
{
	loaded = 1;
	const char *lib = getenv("K4510_SIDEBAR_LIB");
	void *h = lib && *lib ? dlopen(lib, RTLD_NOW | RTLD_LOCAL) : NULL;
	if (!h) {
		if (lib && *lib) fprintf(stderr, "k4510host: %s: %s\n", lib, dlerror());
		return;
	}
	int (*api)(void) = (int (*)(void))dlsym(h, "k4510side_api");
	s_init = (int (*)(const char *))dlsym(h, "k4510side_init");
	s_draw = (void (*)(uint32_t *, int, int, int, uint32_t))dlsym(h, "k4510side_draw");
	s_quit = (void (*)(void))dlsym(h, "k4510side_quit");
	if (!api || api() != 1 || !s_init || !s_draw || !s_quit) {
		fprintf(stderr, "k4510host: %s is not API 1\n", lib);
		s_init = NULL; s_draw = NULL; s_quit = NULL;
		return;
	}
	atexit(stop);
	k4510host_set(getenv("K4510_SIDEBAR"));
}

void
k4510host_set(const char *config)
{
	if (!loaded) load();
	stop();
	snprintf(scene, sizeof scene, "%s", config && *config ? config : "none");
	if (!s_init || !strncmp(scene, "none", 4)) return;
	if (s_init(scene) == 0) running = 1;
	else fprintf(stderr, "k4510host: no sidebar scene \"%s\"\n", scene);
	last_ms = -1000;
}

const char *
k4510host_scene(void)
{
	return scene;
}

int
k4510host_frame(int area_w, int area_h, uint32_t **px, int *w, int *h, int *k, int *fresh)
{
	if (!loaded) load();
	if (!running || area_w < 16 || area_h < 16) return 0;
	/* machine pixels: a whole number k that brings the height to 400 or less */
	int kk = (area_h + 399) / 400;
	int nw = area_w / kk, nh = area_h / kk;
	*fresh = 0;
	if (nw != bw || nh != bh) {
		free(buf);
		buf = (uint32_t *)calloc((size_t)nw * nh, 4);
		if (!buf) { bw = bh = 0; return 0; }
		bw = nw; bh = nh; last_ms = -1000;
	}
	uint32_t ms = now_ms();
	if ((int)(ms - (uint32_t)last_ms) >= 33 || last_ms == -1000) {
		s_draw(buf, bw, bh, bw, ms);
		last_ms = (int)ms;
		*fresh = 1;
	}
	*px = buf; *w = bw; *h = bh; *k = kk;
	return 1;
}
