# Licensing

The VideoBrain core sources (`VideoBrain.sv` and `rtl/`, except vendor PLL
files) are licensed under GNU GPL version 2 or, at your option, any later
version (`GPL-2.0-or-later`). See [LICENSE](../LICENSE).

The combined MiSTer build is distributed under GNU GPL version 3 or later
because it includes GPL-3.0-or-later framework modules, including
`sys/hps_io.sv` and `sys/ddr_svc.sv`. See [COPYING.GPL3](COPYING.GPL3).
Individual files retain their own license terms and attribution.

## Channel F sources

These files derive from Grabulosaure's
[ChannelF_MiSTer](https://github.com/MiSTer-devel/ChannelF_MiSTer):

| Local file | Upstream file |
| --- | --- |
| `rtl/f8/f8_cpu.vhd` | `rtl/chf/f8_cpu.vhd` |
| `rtl/f8/f8_pack.vhd` | `rtl/chf/f8_pack.vhd` |
| `rtl/f8/base_pack.vhd` | `rtl/base/base_pack.vhd` |

Upstream includes the GPL v2 text in `LICENSE` and explicitly permits GPL
v2 or later in `channel_f.sv`. This program-wide notice is the basis for
applying GPL-2.0-or-later to the F8 files, which have no separate license
notice. Their original DO and MAME acknowledgments are preserved.

Compared with upstream commit `34da8117b891f9aa38cc001875c60e18c8867559`,
the CPU contains VideoBrain changes; both packages match apart from the
licensing notices added here.

## Other bundled material

- `sys/` retains upstream MiSTer notices without project-specific edits.
  `sys/sd_card.sv` uses LGPL v3 or later; see
  [COPYING.LGPL3](COPYING.LGPL3) and [COPYING.GPL3](COPYING.GPL3).
- Altera/Intel PLL and reconfiguration files retain their vendor terms.
- `verilator/sim/imgui/` retains its bundled license texts and file notices.
- The core license does not grant rights to third-party ROMs, software,
  manuals, or other reference material.

Distribute RBF releases with their corresponding source and build files,
license texts, and notices. Keep an identifiable source revision for each
release.
