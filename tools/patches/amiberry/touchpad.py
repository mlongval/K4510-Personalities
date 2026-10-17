# The touchpad on the bare console (Doc, 2026-10-17: "trackpad does not
# work in amiga 1200"), run by apply.py from the Amiberry source tree.  On
# KMSDRM SDL3 reads evdev itself and reports a touchpad as FINGERS (its
# SDL_evdev.c: "for now, we just treat a touchpad like a touchscreen"), and
# Amiberry's finger code moved the mouse only for finger id 0 -- an id SDL3
# never gives -- and pressed the button on every touch.  Here, as the K4532's
# own sdl/main.c does it: the first finger's motion moves the Amiga's mouse,
# a short tap that hardly moved is a click (two fingers: the right button),
# and a tap then a finger held down drags.  run/amiga sets
# SDL_TOUCH_MOUSE_EVENTS=0, so SDL makes no mouse of its own out of them.
import sys
P = "src/osdep/amiberry.cpp"
s = open(P).read()
def cut(start, end_marker):
    global s
    i = s.index(start); j = s.index(end_marker, i)
    return i, j
TP = r'''// K4510 (K4532-Personalities): the touchpad as a mouse (vice/../amiberry/touchpad.py)
static int k4510_tp_fingers, k4510_tp_most, k4510_tp_drag, k4510_tp_up_button = -1;
static SDL_FingerID k4510_tp_first;
static Uint64 k4510_tp_down_at, k4510_tp_tap_at, k4510_tp_release_at;
static float k4510_tp_moved, k4510_tp_rx, k4510_tp_ry;
static void k4510_tp_tick()                       // a tap's button let go a little after it went down
{
	if (k4510_tp_up_button >= 0 && SDL_GetTicksNS() >= k4510_tp_release_at) {
		setmousebuttonstate(0, k4510_tp_up_button, 0);
		k4510_tp_up_button = -1;
	}
}
static void handle_finger_event(const SDL_Event& event)
{
	if (!mouseactive || isfocus() <= 0)
		return;
#ifndef LIBRETRO
	if (pen_in_proximity && currprefs.input_tablet > 0)
		return;
#endif
	const Uint64 t = event.tfinger.timestamp;
	if (event.type == SDL_EVENT_FINGER_DOWN) {
		if (k4510_tp_fingers++ == 0) {
			k4510_tp_first = event.tfinger.fingerID;
			k4510_tp_down_at = t; k4510_tp_moved = 0; k4510_tp_most = 1;
			if (k4510_tp_tap_at && t - k4510_tp_tap_at < 300000000ULL) {   // a tap, then down again: drag
				k4510_tp_tick();
				setmousebuttonstate(0, 0, 1);
				k4510_tp_drag = 1;
			}
		} else if (k4510_tp_fingers > k4510_tp_most)
			k4510_tp_most = k4510_tp_fingers;
		return;
	}
	if (event.type != SDL_EVENT_FINGER_UP || k4510_tp_fingers == 0)
		return;
	if (--k4510_tp_fingers)
		return;
	k4510_tp_tap_at = 0;
	if (k4510_tp_drag) {
		setmousebuttonstate(0, 0, 0);
		k4510_tp_drag = 0;
	} else if (t - k4510_tp_down_at < 250000000ULL && k4510_tp_moved < 0.02f) {
		const int b = k4510_tp_most >= 2 ? 1 : 0;
		k4510_tp_tick();
		setmousebuttonstate(0, b, 1);
		k4510_tp_up_button = b;
		k4510_tp_release_at = SDL_GetTicksNS() + 60000000ULL;
		if (!b)
			k4510_tp_tap_at = t;
	}
}
'''
i, j = cut("static void handle_finger_event(const SDL_Event& event)\n", "\n}\n")
s = s[:i] + TP + s[j + 3:]
MOTION = r'''static void handle_finger_motion_event(const SDL_Event& event, int window_width, int window_height)
{
#ifndef LIBRETRO
	if (pen_in_proximity && currprefs.input_tablet > 0)
		return;
#endif
	if (!mouseactive || isfocus() <= 0 || k4510_tp_fingers == 0 || event.tfinger.fingerID != k4510_tp_first)
		return;
	if (window_width <= 0 || window_height <= 0) {
		window_width = 640;
		window_height = 480;
	}
	k4510_tp_moved += SDL_fabsf(event.tfinger.dx) + SDL_fabsf(event.tfinger.dy);
	if (k4510_tp_fingers > 1)                     // two fingers: a right click in the making, not a move
		return;
	// one sweep of the pad: the window's width; the fractions kept for the next motion
	k4510_tp_rx += event.tfinger.dx * window_width;
	k4510_tp_ry += event.tfinger.dy * window_height;
	const int relX = static_cast<int>(k4510_tp_rx), relY = static_cast<int>(k4510_tp_ry);
	k4510_tp_rx -= relX; k4510_tp_ry -= relY;
	setmousestate(0, 0, relX, 0); // 0 = relative
	setmousestate(0, 1, relY, 0);
}
'''
i, j = cut("static void handle_finger_motion_event(const SDL_Event& event, int window_width, int window_height)\n", "\n}\n")
s = s[:i] + MOTION + s[j + 3:]
old = "\twhile (SDL_PollEvent(&event))\n\t{\n\t\tgot_event = 1;\n\t\tprocess_event(event);\n\t}\n"
if s.count(old) != 1:
    sys.exit(f"amiberry/touchpad.py: expected 1x the event loop, found {s.count(old)}")
s = s.replace(old, old + "#ifndef __ANDROID__\n\tk4510_tp_tick();\n#endif\n")
open(P, "w").write(s)
print("amiberry/touchpad.py: the touchpad in")
