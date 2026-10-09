/* The sidebar drawn by an SDL2 program into the free area (output pixels,
 * with the logical size off).  Nothing happens without a scene. */
#ifndef K4510HOST_SDL2_H
#define K4510HOST_SDL2_H
#include <SDL.h>
#include "k4510host.h"
#ifdef __cplusplus
extern "C" {
#endif
void k4510host_sdl2(SDL_Renderer *r, SDL_Rect area);
#ifdef __cplusplus
}
#endif
#endif
