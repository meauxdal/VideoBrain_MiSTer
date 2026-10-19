"""Check a held MT1 note for premature interrupts near the field boundary."""
import csv
import statistics
import sys


with open(sys.argv[1], newline="") as source:
    events = [event for event in csv.DictReader(source)
              if 340 <= int(event["frame"]) < 410]
assert len(events) > 100, "No sustained MT1 note in frames 340..409"
intervals = [int(b["cycle"]) - int(a["cycle"])
             for a, b in zip(events, events[1:])]
premature = []
for event in events:
    target = int(event["yint"])
    high = int(event["cmd"], 16) & 0x80
    # The UV201 counter advances at leading HBLANK, before output vpos.
    current = int(event["vpos"]) + (int(event["hpos"]) >= 222)
    if not high and target <= 16 and current < target:
        premature.append(event)

print(f"MT1 DAC events: {len(events)}; interval ticks min/median/max: "
      f"{min(intervals)}/{statistics.median(intervals):g}/{max(intervals)}")
print(f"Premature field-start interrupts: {len(premature)}")
for event in premature[:3]:
    print(f"  frame {event['frame']}: Y={event['vpos']} "
          f"before target {event['yint']}")
assert not premature, "Sound ISR ran before its programmed Y position"
