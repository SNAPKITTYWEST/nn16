"""
NN/16 reference simulation.
Exact integer contract that mirrors the Pascal limb algorithms and
the 6502 two's-complement kernels. Golden vectors come from here.
"""

import json, os

SHIFT=8; ROUND=128; AMAX=255; AMIN=-256; LR=32
P2=[1<<k for k in range(15)]

# ---------- limb accumulator (sign + two 15-bit magnitude limbs) ----------
def acc_zero():
    return [False, 0, 0]  # [NEG, L, H]

def acc_iszero(a):
    return a[1] == 0 and a[2] == 0

def acc_norm(a):
    if a[1] == 0 and a[2] == 0:
        a[0] = False
    return a

def acc_from_int(v):
    a = acc_zero()
    if v >  2**30-1: v =  2**30-1
    if v < -(2**30-1): v = -(2**30-1)
    a[0] = v < 0
    m = abs(v)
    a[1] = m % 32768
    a[2] = m // 32768
    return acc_norm(a)

def acc_val(a):
    return (-1 if a[0] else 1) * (a[2] * 32768 + a[1])

def acc_addacc(a, b):
    s = acc_val(a) + acc_val(b)
    if s >  2**30-1: s =  2**30-1
    if s < -(2**30-1): s = -(2**30-1)
    a[0] = s < 0
    m = abs(s)
    a[1] = m % 32768
    a[2] = m // 32768
    return acc_norm(a)

def acc_sat(a):
    return max(-32768, min(32767, acc_val(a)))

def acc_shift(a):
    """>>8 round-half-away-from-zero on magnitude, then sat16."""
    m = a[2] * 32768 + a[1]
    r = (m + ROUND) >> SHIFT
    r = -r if a[0] else r
    return max(-32768, min(32767, r))

# ---------- fixed point ----------
def clamp_op(a):
    return max(a, -32767) if a < 0 else min(a, 32767)

def fxmul(a, b):
    p = clamp_op(a) * clamp_op(b)
    m = abs(p)
    r = (m + ROUND) >> SHIFT
    r = -r if p < 0 else r
    return max(-32768, min(32767, r))

def dot_acc(x, w, n):
    a = acc_zero()
    for i in range(n):
        acc_addacc(a, acc_from_int(clamp_op(x[i]) * clamp_op(w[i])))
    return a

def dot(x, w, n):
    return acc_sat(dot_acc(x, w, n))

def act(p):
    return max(AMIN, min(AMAX, p))

def actderiv(a, s):
    return 0 if (a == AMAX and s > 0) or (a == AMIN and s < 0) else 1

# ---------- LFSR (15-bit, taps 15,14) ----------
def rnd_next(seed):
    b14 = (seed // 16384) % 2
    b13 = (seed // 8192) % 2
    seed = (seed * 2 + (b14 ^ b13)) % 32768
    return seed

def rnd_weight(seed, scale=96):
    seed = rnd_next(seed)
    return seed, (seed // 256) - scale

# ---------- network ----------
def net_init(ni, nh, no, seed, scale=96):
    W1 = [[0]*ni for _ in range(nh)]
    B1 = [0]*nh
    W2 = [0]*nh
    B2 = 0
    for j in range(nh):
        for i in range(ni):
            seed, v = rnd_weight(seed, scale)
            W1[j][i] = v
    for j in range(nh):
        seed, v = rnd_weight(seed, scale)
        W2[j] = v
    return dict(ni=ni, nh=nh, no=no, W1=W1, B1=B1, W2=W2, B2=B2)

def forward(net, x):
    nh, ni = net['nh'], net['ni']
    pre = []; ah = []
    for j in range(nh):
        p = acc_shift(dot_acc(x, net['W1'][j], ni))
        a = act(p + net['B1'][j])
        pre.append(p); ah.append(a)
    po = acc_shift(dot_acc(ah, net['W2'], nh))
    out = act(po + net['B2'])
    return pre, ah, po, out

# ---------- dataset: majority of 3 ----------
def mkds(tval=224):
    out = []
    for bits in range(8):
        b = [(bits >> 2) & 1, (bits >> 1) & 1, bits & 1]
        x = [64 if b[0] else -64, 64 if b[1] else -64,
             64 if b[2] else -64, 0]
        t = tval if (b[0]+b[1]+b[2]) >= 2 else -tval
        out.append((x, t))
    return out

def train(net, ds, epochs, lr=LR):
    hist = []; histcls = []
    for ep in range(1, epochs+1):
        metric = 0; mis = 0
        for (x, t) in ds:
            pre, ah, po, out = forward(net, x)
            e = t - out; metric += abs(e)
            if (out >= 0) != (t >= 0): mis += 1
            dO = actderiv(out, e) * e
            gH = [fxmul(dO, net['W2'][j]) for j in range(net['nh'])]
            dH = [actderiv(ah[j], gH[j]) * gH[j] for j in range(net['nh'])]
            for j in range(net['nh']):
                for i in range(net['ni']):
                    net['W1'][j][i] = max(-32768, min(32767,
                        net['W1'][j][i] + fxmul(fxmul(lr, dH[j]), x[i])))
                net['B1'][j] = max(-32768, min(32767,
                    net['B1'][j] + fxmul(lr, dH[j])))
                net['W2'][j] = max(-32768, min(32767,
                    net['W2'][j] + fxmul(fxmul(lr, dO), ah[j])))
            net['B2'] = max(-32768, min(32767,
                net['B2'] + fxmul(lr, dO)))
        hist.append(metric); histcls.append(mis)
        if mis == 0: break
    return hist, histcls

def fletcher(words):
    s1 = s2 = 0
    for v in words:
        for byte in [(v & 0xFF00) >> 8, v & 0xFF]:
            s1 = (s1 + byte) % 255
            s2 = (s2 + s1) % 255
    return (s2 << 8) | s1

def bank_words(net):
    w = []
    for j in range(net['nh']):
        for i in range(net['ni']): w.append(net['W1'][j][i])
    w += net['B1']
    w += net['W2']
    w.append(net['B2'])
    return w

if __name__ == '__main__':
    DS = mkds(224)

    # Arithmetic goldens
    print('dot_simple =', dot([1,2,3,4],[5,6,7,8],4))
    print('dot_zero =', dot([0,0,0,0],[1,2,3,4],4))
    a_mixed = dot_acc([-128,127,-1,0],[32767,32767,256,-32768],4)
    print('dot_mixed =', acc_sat(a_mixed))
    print('dot_shifted_mixed =', acc_shift(a_mixed))
    print('fxmul_300_200 =', fxmul(300,200))
    print('fxmul_neg300_200 =', fxmul(-300,200))
    print('act_pos =', act(200), 'act_neg =', act(-200))

    # LFSR
    s = 12345; seq = []
    for _ in range(8): s = rnd_next(s); seq.append(s)
    print('lfsr_seq =', seq)

    s = 12345; wseq = []
    for _ in range(6): s, v = rnd_weight(s, 96); wseq.append(v)
    print('init_weights_s96 =', wseq)

    # Demo training
    net = net_init(4, 3, 1, 12345, 96)
    print('bank0_fletcher =', fletcher(bank_words(net)))
    _, _, _, o0 = forward(net, DS[0][0])
    print('out0_untrained =', o0)

    h, c = train(net, DS, 2000, LR)
    print('metric_e1 =', h[0])
    print('metric_e10 =', h[9] if len(h) > 9 else None)
    print('metric_e50 =', h[49] if len(h) > 49 else None)
    print('metric_final =', h[-1], 'epochs =', len(h))
    print('bankF_fletcher =', fletcher(bank_words(net)))
    print('outputs_final =', [forward(net,x)[3] for x,_ in DS])
    print('cls_final =', sum(1 for (x,t) in DS if (forward(net,x)[3]>=0)==(t>=0)))
    print('W1 =', net['W1'])
    print('B1 =', net['B1'])
    print('W2 =', net['W2'])
    print('B2 =', net['B2'])
