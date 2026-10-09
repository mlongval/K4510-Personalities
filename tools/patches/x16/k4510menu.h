#ifndef K4510MENU_H
#define K4510MENU_H
#include <SDL.h>
#include <stdbool.h>
#include <stdint.h>
void k4510_init(int logical_w, int logical_h);
void k4510_present_copy(SDL_Renderer *r, SDL_Texture *t);
bool k4510_menu(SDL_Renderer *r, SDL_Texture *t, const uint8_t *frame);
SDL_Rect k4510_sidebar_rect(void);
#endif
