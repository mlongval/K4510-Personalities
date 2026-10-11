# STARTUP.BAT -- the K4532's: runs at power-on, and it is yours to edit
# (a newer K4532 image never overwrites a copy you changed).
# /SYSTEM/ETC/STARTUP.SAMPLE has more: CP/M aliases, colours, palettes.

# a login on the Linux beneath, as on the K4510
ALIAS HOST TELNET 127.0.0.1 23

# (40 columns at the smallest text size: the lines are kept short)
ECHO K4532: the K4510 with a RISC-V CPU,
ECHO the 4532 (RV32IMFD, 32-bit, flat).
ECHO K/OS-32 starts next. Try HELLO, FPU,
ECHO VICKY, DIR. EXIT: the 4510's shell,
ECHO KOS32 goes back. F12 > Machine >
ECHO Quit: the Chooser.
