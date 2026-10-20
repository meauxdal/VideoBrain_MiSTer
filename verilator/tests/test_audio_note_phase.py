"""Check latch-fault detection and separation of startup polarity from IRQ modulation."""
import unittest

import numpy as np

from audio_note_phase import audit_events, audit_latches, key_intervals, measure, note_burst
from audio_irq_diagnostic import CLOCK


def latch(**values):
    row = dict(cycle=1, keys=0, reset=0, port_a_n=3, port_b_n=16,
               port_b_wr=1, clock_previous=0, held_code=0, stb=1,
               code=3, latch_ok=1)
    row.update(values)
    return {key: str(value) for key, value in row.items()}


def tone(modulation_us=0, invert=False):
    count = 900
    irq = np.rint((.01 + np.arange(count) * .0005) * CLOCK).astype(np.int64)
    latency = np.rint((20 + modulation_us * np.sin(2 * np.pi * 60 * irq / CLOCK)) *
                      CLOCK / 1e6).astype(np.int64)
    ack = irq + latency
    cycles = ack + round(90e-6 * CLOCK)
    codes = ((np.arange(count) + int(invert)) % 2) * 3
    burst = [latch(cycle=cycle, code=code) for cycle, code in zip(cycles, codes)]
    events = {int(cycle): dict(code=str(code), irq_cycle=str(request), ack_cycle=str(accept))
              for cycle, code, request, accept in zip(cycles, codes, irq, ack)}
    return burst, events


class AudioNotePhaseTest(unittest.TestCase):
    def test_pin_edge_data_and_hold(self):
        good = [latch(), latch(port_b_n=0, clock_previous=1, stb=0, code=0),
                latch(clock_previous=1, stb=0, code=0),
                latch(port_b_wr=0), latch(reset=1, stb=0, code=0)]
        self.assertEqual(audit_latches(good), [])
        for bad in (latch(stb=0), latch(code=2),
                    latch(clock_previous=1), latch(reset=1),
                    latch(port_b_wr=0, stb=0), latch(latch_ok=0)):
            self.assertEqual(audit_latches([bad]), [1])

    def test_independent_irq_and_dac_trace(self):
        rows = [latch(cycle=10, stb=0, code=0, irq=1, ack=0),
                latch(cycle=20, stb=0, code=0, irq=0, ack=1),
                latch(cycle=30, irq=0, ack=0)]
        events = {30: dict(code='3', irq_cycle='10', ack_cycle='20')}
        audit_events(rows, events)
        with self.assertRaisesRegex(ValueError, 'different latch cycles'):
            audit_events(rows[:-1], events)
        events[30]['irq_cycle'] = '9'
        with self.assertRaisesRegex(ValueError, 'independent edge trace'):
            audit_events(rows, events)

    def test_key_boundaries_and_missing_release(self):
        rows = [latch(cycle=0), latch(cycle=10, keys=32),
                latch(cycle=11, keys=32), latch(cycle=20)]
        self.assertEqual([(int(a['cycle']), int(b['cycle']))
                          for a, b in key_intervals(rows, 5)], [(10, 20)])
        with self.assertRaisesRegex(ValueError, 'final key release'):
            key_intervals(rows[:-1], 5)

    def test_reject_missing_and_multiple_bursts(self):
        burst, _ = tone()
        with self.assertRaisesRegex(ValueError, 'got 0'):
            note_burst(burst[:20], 0, 100000000)
        second = [dict(row, cycle=str(int(row['cycle']) + 20000000)) for row in burst]
        with self.assertRaisesRegex(ValueError, 'got 2'):
            note_burst(burst + second, 0, 100000000)

    def test_irq_modulation_and_polarity(self):
        clean = measure(*tone())
        modulated = measure(*tone(10))
        inverted = measure(*tone(10, invert=True))
        self.assertLess(max(clean['bands']), -65)
        self.assertGreater(min(modulated['bands'][1:3]), -40)
        self.assertLess(max(modulated['fixed_bands'][1:3]), -65)
        np.testing.assert_allclose(modulated['bands'], inverted['bands'], atol=1e-8)
        self.assertLess(abs(modulated['high_fraction'] - .5), .001)

    def test_reject_corrupt_codes_and_stale_ack(self):
        burst, events = tone()
        burst[300]['code'] = '2'
        with self.assertRaisesRegex(ValueError, 'DAC codes'):
            measure(burst, events)
        burst, events = tone()
        cycles = list(events)
        events[cycles[300]]['ack_cycle'] = events[cycles[299]]['ack_cycle']
        with self.assertRaisesRegex(ValueError, 'IRQ/ack timestamps'):
            measure(burst, events)

    def test_reject_incomplete_window(self):
        burst, events = tone()
        with self.assertRaisesRegex(ValueError, 'Incomplete sustained note'):
            measure(burst[:400], events)


if __name__ == '__main__':
    unittest.main()
