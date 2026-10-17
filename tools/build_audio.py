"""Generate original, quiet toy-piano sounds using only Python's standard library."""
import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 22050

def write(name, notes, duration):
    samples = [0.0] * int(RATE * duration)
    for start, frequency, length, amp in notes:
        for j in range(min(int(length * RATE), len(samples) - int(start * RATE))):
            t = j / RATE
            attack = min(1, t / .008)
            release = max(0, 1 - t / length) ** 2
            tone = math.sin(2*math.pi*frequency*t) + .20*math.sin(2*math.pi*frequency*2*t)*math.exp(-t*8)
            samples[int(start*RATE)+j] += tone * attack * release * amp
    with wave.open(str(OUT/f'{name}.wav'), 'wb') as wav:
        wav.setparams((1,2,RATE,0,'NONE','not compressed'))
        wav.writeframes(b''.join(struct.pack('<h', int(max(-.95,min(.95,s)) * 32767)) for s in samples))

write('pick', [(0,659,.24,.35)], .3)
write('star', [(0,880,.35,.35),(.09,1318,.4,.25)], .6)
write('hop', [(0,392,.17,.3),(.07,523,.22,.3),(.14,784,.3,.24)], .5)
write('bump', [(0,196,.25,.25),(.07,261,.22,.2)], .4)
write('start', [(0,523,.4,.3),(.14,659,.4,.3),(.28,784,.5,.3)], .9)
write('finish', [(i*.16,f,.7,.3) for i,f in enumerate([523,659,784,1047])], 1.4)
melody = [659,0,784,880,784,0,659,523,587,0,659,784,659,0,523,0,
          659,0,784,1047,880,0,784,659,587,659,523,0,587,0,523,0]
notes = [(i*.55,f,1.2,.21) for i,f in enumerate(melody) if f]
for i,f in enumerate([131,175,196,131,131,175,196,131]):
    notes += [(i*2.2,f,2.0,.1),(i*2.2,f*1.5,2.0,.06)]
write('snow_day',notes,17.6)
print('Original sound effects and music generated.')
