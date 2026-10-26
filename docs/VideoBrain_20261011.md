# VideoBrain 20261011

## Changes since 20261007

- Support for all eighteen known cartridge layouts, including assembled APL/S and Information Manager images.
- Initial Expander 1 processor and host interface support, with separate firmware loading as `boot1.rom`.
- Pinball background modifier correction and audio output/filtering updates.
- Integer scaling correction and source cleanup following the CPU, bus and video audits.

These changes summarize the source history through the release publication commit. At this release, Expander support was preliminary: tape and serial communication were not yet supported. APL/S startup coverage did not establish full program execution.

## Setup

Install [VideoBrain_20261011.rbf](../releases/VideoBrain_20261011.rbf) in the MiSTer Computers folder. The combined BIOS filename is `boot0.rom`; rename an older `boot.rom` installation. Information Manager also needs Expander 1 firmware as `boot1.rom`.

This release uses the older joystick OSD: Joystick=On and Stick timing=Curve. Current calibration and preset instructions apply to later sources.

## Artifact

- File: `VideoBrain_20261011.rbf`
- Publication commit: `3cbccd75ce847a9f78de3a1ee2d3f8da98bcc54e`
- Size: 2,858,972 bytes
- SHA-256: `f971ea62db09456726b8cfa6ef5959883516a4f7e98873f6fbd5bf15ab5c2f03`

The publication commit identifies the tracked binary; its exact build-source revision was not recorded.
