import math

WIDTH = 32
GRID_ROWS = 480

# mag_approx = max(|re|,|im|) + min(|re|,|im|)/2 can slightly exceed 1.0, so truncate the ROM address
ROW_ADDR_BITS = 8
ROM_SIZE = 1 << ROW_ADDR_BITS

FULL_SCALE = 1 << (WIDTH // 2 - 1)   # Q1.15 full scale = 32768
FLOOR_DB = -48.0                     # magnitudes below this map to row 0

with open("mag_to_row.mem", "w") as f:
    for addr in range(ROM_SIZE):
        # addr represents the top ROW_ADDR_BITS bits of a (WIDTH/2 + 1)-bit unsigned mag_approx value
        mag = addr << ((WIDTH // 2 + 1) - ROW_ADDR_BITS)
        if mag == 0:
            row = 0
        else:
            db = 20 * math.log10(mag / FULL_SCALE)
            db = max(FLOOR_DB, min(0.0, db))
            row = int((db - FLOOR_DB) / (0.0 - FLOOR_DB) * (GRID_ROWS - 1))
        f.write(f"{row:02x}\n")