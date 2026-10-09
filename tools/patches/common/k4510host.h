/* k4510host -- the emulators' side of the K4510 sidebar (K4510-Personalities).
 * libk4510side.so (the K4510 repo's sdl/k4510side.h) draws a scene into
 * pixels; this finds it (K4510_SIDEBAR_LIB), starts the scene named by
 * K4510_SIDEBAR ("antfarm state=DIR"), and keeps a buffer in the scene's own
 * machine-pixel size for the free area.  No SDL here: the SDL2 emulators and
 * the SDL3 one each upload the buffer and scale it up themselves. */
#ifndef K4510HOST_H
#define K4510HOST_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* For a free area of area_w x area_h output pixels: the scene's pixels
 * (*px, *w x *h, pitch = *w) and the whole number *k to scale them by, or 0
 * when there is no sidebar (no library, no scene, no area).  *fresh is 1
 * when the pixels changed since the last call (the scene runs at 30 fps). */
int k4510host_frame(int area_w, int area_h, uint32_t **px, int *w, int *h, int *k, int *fresh);
/* Change the scene ("none" or NULL: no sidebar) -- the X16's F12 menu. */
void k4510host_set(const char *config);
const char *k4510host_scene(void);
#ifdef __cplusplus
}
#endif
#endif
