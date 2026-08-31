# This script generates the twiddle factors for an N-point FFT and writes them to a mem file.

import math
 
def real_to_q15(x):
    v = round(x * 32768)
    return max(-32768, min(32767, v))
 
def make_twiddles(N):
    twiddles = []
    for k in range(N // 2):
        angle = -2.0 * math.pi * k / N
        re = real_to_q15(math.cos(angle)) & 0xFFFF
        im = real_to_q15(math.sin(angle)) & 0xFFFF
        twiddles.append((re << 16) | im)
    return twiddles
 
def write_mem_file(N, filename):
    twiddles = make_twiddles(N)
    with open(filename, "w") as f:
        for packed in twiddles:
            f.write("%08X\n" % packed)
 
N = 256     # CHANGE THIS FOR A DIFFERENT N-POINT FFT
write_mem_file(N, "twiddle_N%d.mem" % N)