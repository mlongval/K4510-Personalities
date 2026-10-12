# STARTUP.BAT -- the K4532's: runs at power-on, and it is yours to edit
# (a newer K4532 image never overwrites a copy you changed).
# /SYSTEM/ETC/STARTUP.SAMPLE has more: CP/M aliases, colours, palettes.

# a login on the Linux beneath, as on the K4510
ALIAS HOST TELNET 127.0.0.1 23

# (40 columns at the smallest text size: the lines are kept short)
ECHO K4532: K/OS on the 4532, a RISC-V
ECHO CPU (RV32IMFD, 32-bit, flat).
ECHO Try HELLO, FPU, VICKY, DIR, HELP.
ECHO CHOOSER (or F12 > Machine > Quit):
ECHO the Chooser.
