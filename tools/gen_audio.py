"""Generate small SFX + a tileable music loop as 22050Hz mono 16-bit WAV (numpy)."""
import os, wave, struct
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 22050


def write(name, sig):
    sig = np.clip(sig, -1, 1)
    data = (sig * 32000).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data)
    print("  ->", name, "%.2fs" % (len(sig)/SR))


def tone(freq, dur, shape="sine", vol=0.5):
    t = np.linspace(0, dur, int(SR*dur), endpoint=False)
    if shape == "sine":
        s = np.sin(2*np.pi*freq*t)
    elif shape == "square":
        s = np.sign(np.sin(2*np.pi*freq*t))
    elif shape == "tri":
        s = 2*np.abs(2*(t*freq - np.floor(t*freq+0.5)))-1
    else:
        s = np.sin(2*np.pi*freq*t)
    return s*vol


def env(sig, a=0.005, d=0.1):
    n = len(sig); e = np.ones(n)
    na = int(a*SR); nd = int(d*SR)
    if na > 0: e[:na] = np.linspace(0, 1, na)
    if nd > 0: e[-nd:] = np.linspace(1, 0, nd)
    return sig*e


def coin():
    a = env(tone(880, 0.06, "square", 0.35), 0.002, 0.03)
    b = env(tone(1320, 0.09, "square", 0.35), 0.002, 0.06)
    return np.concatenate([a, b])


def jump():
    dur = 0.25; t = np.linspace(0, dur, int(SR*dur))
    f = np.linspace(300, 720, len(t))
    return env(np.sin(2*np.pi*f*t)*0.4, 0.005, 0.12)


def roll():
    dur = 0.3; n = int(SR*dur)
    noise = np.random.randn(n)*0.3
    # simple lowpass
    for _ in range(6):
        noise = np.convolve(noise, np.ones(8)/8, mode="same")
    return env(noise, 0.01, 0.2)


def hit():
    dur = 0.35; n = int(SR*dur)
    noise = np.random.randn(n)*0.6
    tail = env(tone(90, dur, "sine", 0.5), 0.001, 0.3)
    return env(noise*np.linspace(1, 0, n)*0.5 + tail, 0.001, 0.3)


def powerup():
    notes = [523, 659, 784, 1047]
    segs = [env(tone(f, 0.08, "square", 0.3), 0.002, 0.05) for f in notes]
    return np.concatenate(segs)


def click():
    return env(tone(660, 0.05, "square", 0.3), 0.001, 0.03)


def gameover():
    notes = [523, 440, 349, 262]
    segs = [env(tone(f, 0.18, "tri", 0.4), 0.005, 0.12) for f in notes]
    return np.concatenate(segs)


def music():
    """~8s tileable upbeat loop: bassline + arpeggio + light percussion."""
    bpm = 120; beat = 60/bpm
    bars = 4; total = bars*4*beat
    n = int(SR*total)
    out = np.zeros(n)
    # bass (root notes per bar): Am F C G
    roots = [220, 174.6, 130.8, 196]
    for bar in range(bars):
        f = roots[bar]/2
        for b in range(4):
            start = int((bar*4+b)*beat*SR)
            seg = env(tone(f, beat*0.9, "tri", 0.28), 0.005, 0.1)
            out[start:start+len(seg)] += seg[:len(out)-start]
    # arpeggio (eighth notes) pentatonic-ish
    arp = [440, 523, 659, 587, 523, 659, 784, 659]
    eig = beat/2
    for i in range(int(total/eig)):
        f = arp[i % len(arp)]
        start = int(i*eig*SR)
        seg = env(tone(f, eig*0.8, "square", 0.12), 0.003, eig*0.5)
        out[start:start+len(seg)] += seg[:len(out)-start]
    # kick on beats
    for i in range(int(total/beat)):
        start = int(i*beat*SR)
        d = 0.12; tt = np.linspace(0, d, int(SR*d))
        fk = np.linspace(120, 45, len(tt))
        kick = env(np.sin(2*np.pi*fk*tt)*0.5, 0.001, 0.09)
        out[start:start+len(kick)] += kick[:len(out)-start]
    # hats on off-beats
    for i in range(int(total/(beat/2))):
        if i % 2 == 1:
            start = int(i*(beat/2)*SR)
            d = 0.04; hn = int(SR*d)
            hat = env(np.random.randn(hn)*0.08, 0.001, 0.03)
            out[start:start+len(hat)] += hat[:len(out)-start]
    out = out/np.max(np.abs(out)+1e-6)*0.7
    return out


if __name__ == "__main__":
    print("audio:")
    np.random.seed(7)
    write("coin", coin())
    write("jump", jump())
    write("roll", roll())
    write("hit", hit())
    write("powerup", powerup())
    write("click", click())
    write("gameover", gameover())
    write("music", music())
    print("done.")
