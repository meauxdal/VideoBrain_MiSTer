#!/usr/bin/env python3
"""Compare shared timer mappings using retained measurement scaling."""

from joystick_gain_check import gain


def raw(ticks):
    return ticks // 4 - 5


def results(ticks):
    low, center, high = map(raw, ticks)
    bios_low = min(831, low)
    span = max(851, high) - bios_low
    bios = min(199, (center - bios_low) * gain(span) // 16)
    delta = center - min(640, low)
    tennis = min(214, 70 + 3 * (delta // 32))
    return bios, tennis, span, gain(span)


def main():
    print("mapping          BIOS Tennis span gain")
    for step in (6, 7, 18, 23, 30, 38):
        values = results([2580 + pot * step for pot in (0, 128, 255)])
        print(f"2580:{step:<10} {values[0]:4} {values[1]:6} {values[2]:4} {values[3]:4}")
    values = results((1620, 4564, 11295))
    print(f"1620:23/53       {values[0]:4} {values[1]:6} {values[2]:4} {values[3]:4}")

    best = None
    count = 0
    for step in range(1, 65):
        for base in range(20, 16384 - 255 * step):
            bios, tennis, span, selected = results(
                [base + pot * step for pot in (0, 128, 255)])
            if 124 <= tennis <= 154:
                count += 1
                row = (bios, abs(tennis - 138), base, step, tennis, span, selected)
                if best is None or row < best:
                    best = row
    print(f"Affine pairs with Tennis124..154: {count}")
    print(f"Lowest BIOS: {best}")


if __name__ == "__main__":
    main()
