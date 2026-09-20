"""Rewrites the timing of a dwim session cast for a demo.

The model's own pace is kept. Loading the model is dropped, since the shell
draws relative to the cursor and starts the same without it. Of the
recorder's pauses, the wait before typing is capped, the typed characters are
spaced evenly, the exit is dropped, and the last frame is held.
"""
import json, re, sys

src, dst = sys.argv[1], sys.argv[2]
IDLE, KEY, THINK, HOLD = 1.0, 0.09, 1.0, 4.0

lines = open(src).read().splitlines()
ev = [json.loads(l) for l in lines[1:]]
ev = [e for e in ev if e[1] == 'o']
strip = lambda s: re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', s)

out = [[0, 'o', '\x1b[2J\x1b[H']]  # start from a clean screen
state = 'load'
for e in ev:
    s = strip(e[2]); d = e[0]
    # A redraw can arrive in pieces; only a piece that opens one moves the state.
    if not e[2].startswith('\x1b[?2026h'): pass
    elif state == 'load' and 'Loading' not in s and 'Ask anything' in s: state = 'ready'
    elif state == 'ready' and re.search(r'│ › \S', s): state = 'type'
    elif state == 'type' and 'Reading' in s: state = 'think'
    elif state == 'think' and 'Generating' in s: state = 'reply'
    elif state == 'reply' and 'Generating' not in s: state = 'done'
    elif state == 'done': break  # the exit
    if state == 'load': continue
    if state == 'type': d = KEY
    elif state == 'think':
        if d > 0.5: d = IDLE  # the pause before Enter
        else: d *= THINK
    elif d > 0.5 or state == 'ready' and not out[1:]: d = IDLE
    out.append([round(d, 4), 'o', e[2]])
out.append([HOLD, 'o', '\x1b[?25l'])
with open(dst, 'w') as fp:
    fp.write(lines[0] + '\n')
    for e in out: fp.write(json.dumps(e) + '\n')
print('%.2f' % sum(e[0] for e in out))
