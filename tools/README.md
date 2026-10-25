# Printer image tools

Copy `examples/blank-printer.vbp` to a new name and mount it under Printer in
the OSD, or create one with Python:

```sh
python3 tools/printer_image.py new session.vbp
python3 tools/printer_image.py inspect session.vbp
python3 tools/printer_image.py export session.vbp printer.bin
```

After Stop and Flush, wait for Ready and unmount before exporting. Export
preserves all eight bits and exact payload length. It refuses existing outputs
and incomplete/error sessions unless `--recover` is explicit. Optional
`--session N`, `--text FILE`, `--remove-nul` and `--normalize-crlf` select a
session or create a separate readable copy. See [printer images](../docs/PRINTER.md)
for operation, format, errors and hardware validation limits.

`capture_printer.py` remains the shared-UART diagnostic tool. Select System >
UART Output > Printer for it; simultaneous modem service uses the mounted-image
path instead.

## Tape images

`new_tape.py`, `trim_tape.py` and `tape_convert.py` create blank images, trim
unused capacity and convert VBT/WAV waveforms. See [tape images](../docs/TAPE.md).
