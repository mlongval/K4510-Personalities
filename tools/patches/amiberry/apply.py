# K4510 placement for Amiberry 8.3.0's SDL3 renderer (run from the source
# tree by build-amiberry.sh): K4510_PLACEMENT=left draws the Amiga picture
# flush left at full height, leaving the right of the screen free (for a
# sidebar); K4510_SCALE=integer scales by whole multiples.  Unset: Amiberry
# as it was.  Native chipset screens only (not RTG).
import sys
P = "src/osdep/sdl_renderer.cpp"
s = open(P).read()
def edit(old, new, count=1):
    global s
    if s.count(old) != count:
        sys.exit(f"amiberry/apply.py: expected {count}x {old!r}, found {s.count(old)}")
    s = s.replace(old, new)

old = "        SDL_RenderTextureRotated(mon->amiga_renderer, m_amiga_texture, &f_crop, &f_quad, 0, nullptr, SDL_FLIP_NONE);\n"
new = r'''        // K4510 (BMC64Port): the picture flush left and/or whole-multiple
        // scaled, in output pixels; the logical presentation is set aside
        // for this one copy and given back.
        static int k4510_left = -1, k4510_whole = 0;
        if (k4510_left < 0) {
            const char* e = getenv("K4510_PLACEMENT");
            k4510_left = e && !strcmp(e, "left");
            e = getenv("K4510_SCALE");
            k4510_whole = e && !strcmp(e, "integer");
        }
        int k_lw = 0, k_lh = 0;
        SDL_RendererLogicalPresentation k_mode = SDL_LOGICAL_PRESENTATION_DISABLED;
        SDL_GetRenderLogicalPresentation(mon->amiga_renderer, &k_lw, &k_lh, &k_mode);
        if ((k4510_left || k4510_whole) && !ad->picasso_on && k_lw > 0 && k_lh > 0) {
            // the window's whole output (the "current" size is the letterbox)
            SDL_SetRenderLogicalPresentation(mon->amiga_renderer, 0, 0, SDL_LOGICAL_PRESENTATION_DISABLED);
            SDL_SetRenderViewport(mon->amiga_renderer, nullptr);
            SDL_SetRenderScale(mon->amiga_renderer, 1.0f, 1.0f);
            int W, H;
            SDL_GetRenderOutputSize(mon->amiga_renderer, &W, &H);
            float sc = std::min(static_cast<float>(W) / k_lw, static_cast<float>(H) / k_lh);
            if ((k4510_whole || k_mode == SDL_LOGICAL_PRESENTATION_INTEGER_SCALE) && sc >= 1.0f)
                sc = std::floor(sc);
            const float ox = k4510_left ? 0.0f : (W - k_lw * sc) / 2.0f;
            const float oy = (H - k_lh * sc) / 2.0f;
            SDL_FRect k_quad = { ox + f_quad.x * sc, oy + f_quad.y * sc, f_quad.w * sc, f_quad.h * sc };
            if (getenv("K4510_DEBUG")) {
                static Uint64 k_last = 0;
                if (SDL_GetTicks() - k_last > 1000) {
                    k_last = SDL_GetTicks();
                    fprintf(stderr, "k4510: out %dx%d logical %dx%d mode %d sc %.3f quad %.0f,%.0f %.0fx%.0f crop %.0f,%.0f %.0fx%.0f -> %.0f,%.0f %.0fx%.0f\n",
                        W, H, k_lw, k_lh, (int)k_mode, sc, f_quad.x, f_quad.y, f_quad.w, f_quad.h,
                        f_crop.x, f_crop.y, f_crop.w, f_crop.h, k_quad.x, k_quad.y, k_quad.w, k_quad.h);
                }
            }
            SDL_RenderClear(mon->amiga_renderer);
            SDL_RenderTextureRotated(mon->amiga_renderer, m_amiga_texture, &f_crop, &k_quad, 0, nullptr, SDL_FLIP_NONE);
            SDL_SetRenderLogicalPresentation(mon->amiga_renderer, k_lw, k_lh, k_mode);
        } else
        SDL_RenderTextureRotated(mon->amiga_renderer, m_amiga_texture, &f_crop, &f_quad, 0, nullptr, SDL_FLIP_NONE);
'''
edit(old, new)
if "#include <cmath>" not in s:
    s = "#include <cmath>\n#include <cstdio>\n#include <cstdlib>\n#include <cstring>\n#include <algorithm>\n" + s
open(P, "w").write(s)
print("amiberry/apply.py: placement patch in")
