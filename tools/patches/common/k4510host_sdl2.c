/* k4510host_sdl2.c -- see k4510host_sdl2.h. */
#include "k4510host_sdl2.h"

void
k4510host_sdl2(SDL_Renderer *r, SDL_Rect area)
{
	static SDL_Renderer *tr;
	static SDL_Texture *t;
	static int tw, th;
	uint32_t *px;
	int w, h, k, fresh;
	if (!k4510host_frame(area.w, area.h, &px, &w, &h, &k, &fresh)) return;
	if (!t || tr != r || tw != w || th != h) {
		if (t && tr == r) SDL_DestroyTexture(t);
		t = SDL_CreateTexture(r, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, w, h);
		if (!t) return;
		SDL_SetTextureScaleMode(t, SDL_ScaleModeNearest);
		SDL_SetTextureBlendMode(t, SDL_BLENDMODE_NONE);
		tr = r; tw = w; th = h; fresh = 1;
	}
	if (fresh) SDL_UpdateTexture(t, NULL, px, w * 4);
	SDL_Rect d = { area.x, area.y + (area.h - h * k) / 2, w * k, h * k };
	SDL_RenderCopy(r, t, NULL, &d);
}
