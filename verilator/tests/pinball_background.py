import re
import sys
from pathlib import Path

from PIL import Image


def states(path):
    parts = re.split(r"========== frame (\d+) \(t=\d+\) ==========", path.read_text())
    result = {}
    for frame, body in zip(parts[1::2], parts[2::2]):
        result[int(frame)] = body.split("-- frame ")[0]
    return result


def registers(body):
    match = re.search(r"bg=([0-9A-F]+) fmod=([0-9A-F]+)", body)
    return tuple(int(value, 16) for value in match.groups())


def rgb(index):
    off, on = (192, 255) if index & 16 else (0, 160)
    return tuple(on if index & (1 << bit) else off for bit in range(3))


root = Path(sys.argv[1])
before = states(root / "before.txt")
after = states(root / "after.txt")
assert before.keys() == after.keys(), "Frame coverage differs"
assert before == after, "CPU or UV201 state changed"
colors = set()
unchanged = changed = 0
for path in sorted(root.glob("after_f*.png")):
    frame = int(path.stem.rsplit("f", 1)[1])
    bg, modifier = registers(after[frame])
    old = Image.open(root / path.name.replace("after_", "before_")).convert("RGB")
    new = Image.open(path).convert("RGB")
    assert old.size == new.size, "Raster dimensions changed"
    if rgb(bg ^ modifier) == rgb(bg):
        assert old.tobytes() == new.tobytes(), "Unmodified frame changed"
        unchanged += 1
    elif frame > 0 and registers(after[frame - 1]) == (bg, modifier):
        expected = rgb(bg ^ modifier)
        width, height = new.size
        corners = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
        assert all(new.getpixel(point) == expected for point in corners), "Background extent wrong"
        pixels = list(new.getdata())
        assert pixels.count(expected) > len(pixels) * 0.8, "Background coverage wrong"
        differences = [(a, b) for a, b in zip(old.getdata(), pixels) if a != b]
        assert differences, "Modifier did not change background"
        assert all(a == rgb(bg) and b == expected for a, b in differences), "Object pixels changed"
        colors.add(expected)
        changed += 1
assert unchanged > 0, "No unmodified captures"
assert changed >= 3 and len(colors) >= 3, "Insufficient collision color changes"
print(f"Pinball background passed: {len(after)} matching state dumps, "
      f"{unchanged} unchanged captures, {changed} modified captures, {len(colors)} colors")
