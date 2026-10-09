#!/bin/sh
# Curate a small, organized C64/C128 software library from a local collection
# (C64_COLLECTION in local.cfg: a TOSEC C64 set and a few folders, laid out as
# below) into work/library/{c64,c128}, for ~/personalities/<name> on the
# K4510's disk (p4), where VICE's file browser starts.
#
#   tools/curate-c64.sh            -> work/library/c64/GAMES ...  + MANIFEST.txt
#
# READ-ONLY from the collection: zips are read with python's
# zipfile, nothing is written there.  Re-runnable: work/library is rebuilt.
# Picks one version per title: TOSEC names, no alternates ([a]), no bad dumps
# ([b]), no hacks ([h]), English, fewest extra flags; all sides of a
# multi-disk game come from the same release.  PETSCII Robots is not here
# (the shareware builds come from the 8-Bit Guy, see make-images.sh).
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$HERE/local.cfg" ] && . "$HERE/local.cfg"
[ -d "${C64_COLLECTION:-}" ] || { echo "curate-c64.sh: set C64_COLLECTION in local.cfg"; exit 1; }
exec python3 -I - "$HERE/work/library" "$C64_COLLECTION" <<'PY'
import os, re, sys, zipfile, shutil, glob

OUT = sys.argv[1]
EMU = sys.argv[2]
TOSEC = EMU + '/Commodore64/C64-Ultimate-Software-Collection/TOSEC.2016.11.11.Commodore.C64.AlphaBot'
CARTS = EMU + '/Commodore64/C64_Carts'
def T(kind, fmt): return f'{TOSEC}/Commodore C64 - {kind} - [{fmt}]'
GAMES = [T('Games', 'D64'), T('Games', 'CRT'), T('Games', 'T64'), T('Games', 'PRG')]
DEMOS = [T('Demos', 'D64'), T('Demos', 'PRG'), T('Demos', 'D81')]
APPS  = [T('Applications', 'D64'), T('Applications', 'CRT'), T('Applications', 'PRG'), T('Applications', 'T64')]
IMAGES = ('.d64', '.d71', '.d81', '.crt', '.t64', '.prg', '.g64')

# (folder, title, [dirs]) -- title is the TOSEC name up to " (year)"; a regex.
G = 'c64/GAMES'
SPEC = [(G, t, GAMES) for t in [
    'Impossible Mission', 'Elite',
    'Maniac Mansion', 'Zak McKracken and the Alien Mindbenders', 'Wizball', 'Paradroid',
    'International Karate', 'IK\\+', 'Great Giana Sisters, The', 'Bruce Lee', 'Lode Runner',
    'Archon', 'Archon 2 - Adept', 'M\\.U\\.L\\.E\\.', 'Summer Games', 'Summer Games II',
    'Winter Games', 'California Games', 'World Games', 'Pitstop II', 'Ultima IV.*',
    'Last Ninja, The', 'Last Ninja 2.*', 'Turrican', 'Turrican II.*', 'Mayhem in Monsterland',
    'Bubble Bobble', 'Commando', 'Ghosts\'n Goblins', 'Green Beret', 'Uridium', 'Nebulus',
    'Head over Heels', 'Spy vs Spy', 'Raid on Bungeling Bay', 'Choplifter!?', 'Jumpman',
    'Pac-Man', 'Ms\\. Pac-Man', 'Donkey Kong', 'Defender', 'Dig Dug', 'Galaxian', 'Frogger',
    'Q-Bert', 'Bounty Bob Strikes Back!?', 'Miner 2049er', 'Manic Miner', 'Jet Set Willy',
    'Hunter\'s Moon', 'Delta', 'Armalyte', 'Katakis', 'R-Type', 'Salamander', 'Gauntlet',
    'Barbarian', 'Way of the Exploding Fist, The',
    'Zork I - .*', 'Hitchhiker\'s Guide to the Galaxy, The', 'Pirates!',
    'Defender of the Crown', 'Bard\'s Tale, The.*', 'Pool of Radiance', 'Wasteland',
    'Little Computer People', 'Skate or Die!', 'Marble Madness', 'Paperboy', 'Out Run',
    'Kick Off', 'Emlyn Hughes International Soccer', 'Microprose Soccer', 'Hat Trick',
    'Leaderboard Golf', 'World Class Leaderboard', 'Racing Destruction Set',
    'Dropzone', 'Sentinel, The', 'Mercenary.*', 'Thing on a Spring', 'Monty on the Run',
    'Auf Wiedersehen Monty', 'Rambo - First Blood Part II', 'Cauldron', 'Cauldron II.*',
    'Forbidden Forest', 'Beach Head 1', 'Blue Max', 'Fort Apocalypse', 'Seven Cities of Gold',
    'Ghostbusters', 'Rescue on Fractalus!?', 'Ballblazer', 'Koronis Rift', 'Stunt Car Racer',
    'Creatures', 'Lemmings', 'Prince of Persia', 'Tetris', 'Arkanoid',
    'Batty', 'Hawkeye', 'Citadel', 'Druid', 'Thrust', 'Ghettoblaster', 'Zybex',
    'Bomb Jack', 'Yie Ar Kung-Fu', 'Kung-Fu Master', 'Popeye', 'Mr\\. Do!', 'Tapper',
    'Spelunker', 'Montezuma\'s Revenge',
]] + [
    (G, t, [T('Games - Boulder Dash', 'D64')]) for t in ['Boulder Dash 01', 'Boulder Dash 02']
] + [
    ('c64/DEMOS', t, DEMOS) for t in [
    'Edge of Disgrace', 'Deus Ex Machina', 'Royal Arte', 'Andropolis', 'Mekanix',
    'Natural Wonders', 'Uncensored', 'Dutch Breeze', 'Boogie Factor', 'Dawnfall',
    'Vicious Sid', 'Real', 'Insomnia', 'Coma Light', 'Error 23']
] + [
    ('c64/UTILS', 'Fast Hack\'em', APPS), ('c64/UTILS', 'Print Shop, The', APPS),
    ('c64/UTILS', 'Koala Paint', APPS), ('c64/UTILS', 'Advanced Art Studio v1\\.2b', APPS),
    ('c64/UTILS', 'Music Shop, The', APPS), ('c64/UTILS', 'Sound Monitor v1\\.0', APPS),
    ('c64/UTILS', 'Easy Script 64', APPS), ('c64/UTILS', 'Paperclip Publisher', APPS),
    ('c64/UTILS', 'Disk Doctor', APPS), ('c64/UTILS', 'Kwik Load', APPS),
    ('c64/UTILS', 'Garry Kitchen\'s Gamemaker', APPS),
    ('c64/UTILS', 'Shoot.Em.Up Construction Kit', APPS + GAMES),
    ('c64/LANGUAGES', 'Turbo Assembler V3', APPS), ('c64/LANGUAGES', 'Blitz Compiler', APPS),
    ('c64/LANGUAGES', 'Ultra Basic', APPS),
]
# Cartridges, No-Intro names (one dump each, already clean): copied as they are.
CARTS_SPEC = [
    ('c64/UTILS', 'Action Replay Professional (Europe) (v6.0) (Program).crt'),
    ('c64/UTILS', 'Final Cartridge III, The (USA, Europe) (Dec 88) (Program).crt'),
    ('c64/UTILS', 'Super Snapshot 5 (USA) (Program).crt'),
    ('c64/UTILS', '64MON (USA, Europe) (v1.03) (Program).crt'),
    ('c64/UTILS', 'HES Mon 64 (USA, Europe) (Program).crt'),
    ('c64/UTILS', 'Commodore 64 Diagnostic (USA, Europe) (Program).crt'),
    ('c64/UTILS', 'Magic Desk I - Type and File (USA, Europe) (VICE) (Program).crt'),
    ('c64/LANGUAGES', 'COMAL 80 (USA, Europe) (Program).crt'),
    ('c64/LANGUAGES', 'C64-FORTH (USA, Europe) (Program).crt'),
    ('c64/LANGUAGES', 'Super Expander 64 (USA, Europe) (Program).crt'),
    ('c64/LANGUAGES', 'ExBASIC Level II (USA, Europe) (v64.1) (Program).crt'),
]
# Doc's own folder, as he left it (files picked by hand).
C = EMU + '/C64'
DOC = [
    ('c64/GAMES', C + '/Rogue64/rogue64_v1.03.crt', 'Rogue64 v1.03.crt'),
    ('c64/DOCS',  C + '/Rogue64/Rogue64_manual.pdf', 'Rogue64 manual.pdf'),
    ('c64/GAMES', C + '/EOB/eob v1.00 20221121.crt', 'Eye of the Beholder v1.00 (EasyFlash).crt'),
    ('c64/DOCS',  C + '/EOB/Eye.of.the.Beholder-Manual.pdf', 'Eye of the Beholder manual.pdf'),
    ('c64/UTILS', C + '/EpyxFastLoad/Epyx Fast Load Cartridge (USA, Europe) (Program).crt', 'Epyx Fast Load.crt'),
    ('c64/DOCS',  C + '/EpyxFastLoad/Epyx_FastLoad_Manual.pdf', 'Epyx Fast Load manual.pdf'),
    ('c64/LANGUAGES', C + '/SimonsBasic/Simons_BASIC.crt', 'Simons BASIC.crt'),
    ('c64/LANGUAGES', C + '/SimonsBasic/SimonsBasicStuff.d81', 'Simons BASIC - Doc\'s programs.d81'),
    ('c64/LANGUAGES', C + '/SimonsBasic/3d_function_simons_basic.d64', 'Simons BASIC - 3D function.d64'),
    ('c64/DOCS',  C + '/SimonsBasic/Simons_BASIC.pdf', 'Simons BASIC manual.pdf'),
    ('c64/LANGUAGES', C + '/VisionBasic/Vision BASIC 1.0.d64', 'Vision BASIC 1.0.d64'),
    ('c64/LANGUAGES', C + '/VisionBasic/VisionBasic_Work_disk1.d64', 'Vision BASIC - work disk.d64'),
    ('c64/LANGUAGES', C + '/VisionBasic/The Spreditor SE.d64', 'Vision BASIC - The Spreditor SE.d64'),
    ('c64/DOCS',  C + '/VisionBasic/Vision BASIC Quick Start Guide.txt', 'Vision BASIC quick start.txt'),
    ('c64/LANGUAGES', C + '/Basic3.5/c64-basic-v3.5.d64', 'BASIC 3.5 for the C64.d64'),
    ('c64/DOCS',  C + '/Books/JiffyDOS_V6_User_Manual_(searchable).pdf', 'JiffyDOS 6 manual.pdf'),
    ('c128',      EMU + '/C128/josephrose128.d64', 'Joseph Rose 128.d64'),
] + [('c128/DEMOS', EMU + '/C128/vdcmodemania/' + f, 'VDC Mode Mania - ' + f) for f in
     ('vmm 1a.d64', 'vmm 1b.d64', 'vmm 2a.d64', 'vmm 2b.d64')] + [
    ('c128/DEMOS', EMU + '/C128/vdcmodemania/readme.txt', 'VDC Mode Mania - readme.txt'),
]

LANG = re.compile(r'\((de|fr|it|es|nl|pl|sv|da|fi|no|hu|cs|pt|ru|tr|el|de-en|en-de)\)', re.I)
SIDE = re.compile(r'\((Disk \d+ of \d+(?: Side [AB])?|Side [A-D]|Disk \d+|Tape \d+.*?)\)', re.I)
BAD = re.compile(r'\[(a\d*|b\d*|h[^\]]*|o\d*|f[^\]]*|p[^\]]*|m[^\]]*)\]')

def score(flags):
    s = len(flags) * 2
    for f in flags:
        if f == '!': s -= 10
        elif f.startswith('t'): s += 3      # trainers: a cracked menu in front
        elif f.startswith('cr'): s += 1
    return s

def clean(name):
    name = name.replace('&', 'and').replace('$', 'S')
    name = re.sub(r"[^A-Za-z0-9 ()._+,'-]", '', name)
    return re.sub(r'\s+', ' ', name).strip()

manifest, missing, incomplete = [], [], []
def put(folder, src, dest_name, data=None):
    d = os.path.join(OUT, folder); os.makedirs(d, exist_ok=True)
    p = os.path.join(d, clean(dest_name))
    if data is None: shutil.copyfile(src, p)
    else: open(p, 'wb').write(data)
    manifest.append(f'{folder}/{os.path.basename(p)}\t{src}')

listing = {}
def files_in(d):
    if d not in listing:
        listing[d] = os.listdir(d) if os.path.isdir(d) else []
    return listing[d]

def flags_score(tail):
    return score(re.findall(r'\[([^\]]*)\]', tail))

def pick(folder, title, dirs):
    """One release of a title: per directory (best format first), the files
    are grouped by name and by how they are split (one file, sides, disks of
    N); within a group each side/disk gets its cleanest file, the same crack
    as side A where there is one.  A whole set beats a partial one, one
    file beats several, clean flags beat many."""
    rx = re.compile('^' + title + r' \((?:19|20)[0-9x]{2}', re.I)
    for d in dirs:
        groups = {}
        for f in files_in(d):
            if not rx.match(f) or not f.lower().endswith('.zip'): continue
            base = f[:-4]; i = base.find('[')
            head, tail = (base, '') if i < 0 else (base[:i], base[i:])
            if LANG.search(head) or BAD.search(tail): continue
            if re.search(r'\((Preview|Demo|Hack)\)', head, re.I): continue
            m = SIDE.search(head)
            if m:
                name, slot = head[:m.start()].strip(), m.group(1)
                n = re.search(r' of (\d+)', slot)
                kind = 'of' + n.group(1) if n else 'sides'
            else:
                name, slot, kind = head.strip(), '', 'one'
            groups.setdefault((name, kind), {}).setdefault(slot, []).append((flags_score(tail), tail, f))
        if not groups: continue
        def choose(k):
            slots = groups[k]; out = {}
            first = sorted(slots)[0]
            best = min(slots[first]); out[first] = best
            for sl in slots:
                if sl == first: continue
                same = [c for c in slots[sl] if c[1] == best[1]]
                out[sl] = min(same) if same else min(slots[sl])
            return out
        def whole(k):
            sl = list(groups[k]); kind = k[1]
            if kind == 'one': return True
            if kind == 'sides': return any(x.lower() in ('side a', 'disk 1') for x in sl)
            n = int(kind[2:])
            disks = {int(re.match(r'Disk (\d+)', x).group(1)) for x in sl}
            return disks == set(range(1, n + 1))
        def rank(k):
            ch = choose(k)
            vague = ('(19xx)' in k[0]) + ('(-)' in k[0])
            return (not whole(k), k[1] != 'one', sum(c[0] for c in ch.values()) / len(ch) + 3 * vague, len(k[0]))
        key = min(groups, key=rank)
        if rank(key)[0]: incomplete.append(f'{folder}: {key[0]} ({len(groups[key])} part(s))')
        for slot, (_, _, f) in sorted(choose(key).items()):
            z = zipfile.ZipFile(os.path.join(d, f))
            imgs = [n for n in z.namelist() if n.lower().endswith(IMAGES)]
            for n in imgs:
                ext = os.path.splitext(n)[1].lower()
                nm = key[0] + (' - ' + slot if slot else '')
                if len(imgs) > 1: nm += ' - ' + os.path.splitext(os.path.basename(n))[0]
                put(folder, os.path.join(d, f) + ':' + n, nm + ext, z.read(n))
        return True
    missing.append(f'{folder}: {title}')
    return False

shutil.rmtree(OUT, ignore_errors=True)
seen = set()
for folder, title, dirs in SPEC:
    if (folder, title) in seen: continue
    seen.add((folder, title)); pick(folder, title, dirs)
for folder, f in CARTS_SPEC:
    src = os.path.join(CARTS, f)
    if os.path.exists(src): put(folder, src, re.sub(r' \((USA|Europe|USA, Europe)\)| \(Program\)', '', f))
    else: missing.append(f'{folder}: {f}')
for folder, src, nm in DOC:
    if os.path.exists(src): put(folder, src, nm)
    else: missing.append(f'{folder}: {src}')

open(os.path.join(OUT, 'MANIFEST.txt'), 'w').write(
    'dest\tsource (zip:member for TOSEC zips)\n' + '\n'.join(manifest) + '\n')
if missing: print('not found:\n  ' + '\n  '.join(missing))
if incomplete: print('incomplete sets:\n  ' + '\n  '.join(incomplete))
print(f'{len(manifest)} files')
PY
