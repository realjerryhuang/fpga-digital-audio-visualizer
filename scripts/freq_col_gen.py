import math

N = 1024
GRID_COLS = 128   # Pick a divisor of 640 for even division (e.g., 128 -> 5px bars, 64 -> 10px, 32 -> 20px, ...)

# (bin = 0 or DC dropped)
NUM_BINS = N / 2

with open(f"freq_to_col_N{N}_cols{GRID_COLS}.mem", "w") as f:
    for i in range(NUM_BINS):
        k = i + 1
        # Map log2(k) linearly across log2(1)=0, ..., log2(NUM_BINS) to columns 0, ..., GRID_COLS-1
        col = int(math.log2(k) / math.log2(NUM_BINS) * (GRID_COLS - 1))
        col = max(0, min(GRID_COLS - 1, col))
        f.write(f"{col:02x}\n")