
V     = verilator
GHDL  = ghdl
RTL   = ../rtl
GEN   = gen
WORK  = ghdl_work
TEST_INCLUDE = out/include
TEST_BUILD_ID = $(TEST_INCLUDE)/build_id.v

TOP      = --top-module top
GEN_V    = $(GEN)/videobrain.v
VHD_TOP  = videobrain_core

VHD_SRC = \
	$(RTL)/f8/base_pack.vhd \
	$(RTL)/f8/f8_pack.vhd \
	$(RTL)/uv201/uv201_pack.vhd \
	$(RTL)/uv202/uv202_pack.vhd \
	$(RTL)/f8/f8_cpu.vhd \
	$(RTL)/uv202/f8_busif.vhd \
	$(RTL)/uv202/uv202_clkgen.vhd \
	$(RTL)/uv202/uv202_cpu_gate.vhd \
	$(RTL)/uv202/uv202_timing.vhd \
	$(RTL)/uv202/uv202_arbiter.vhd \
	$(RTL)/uv202/uv202_top.vhd \
	$(RTL)/uv201/uv201_regs.vhd \
	$(RTL)/uv201/uv201_fetcher.vhd \
	$(RTL)/uv201/uv201_fifo.vhd \
	$(RTL)/uv201/uv201_yint.vhd \
	$(RTL)/uv201/uv201_render.vhd \
	$(RTL)/f3853.vhd \
	$(RTL)/buffered_bus.vhd \
	$(RTL)/sys_bus.vhd \
	$(RTL)/videobrain_io.vhd \
	$(RTL)/f3870_timer.vhd \
	$(RTL)/expander1.vhd \
	$(RTL)/videobrain_core.vhd

# Modules converted from VHDL to Verilog by hand. Each name listed here is
# deleted from the synthesised netlist and must exist as rtl_v/<name>.v.
CONVERTED =

CONVERTED_V = $(patsubst %,rtl_v/%.v,$(CONVERTED))
V_SRC = sim.v $(GEN_V) $(RTL)/videobrain_audio.sv $(RTL)/apl_source_loader.sv $(CONVERTED_V)

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S), Darwin)
	LIBS += -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo `sdl2-config --libs`
	LIBS += -L/usr/local/lib -L/opt/local/lib
	CXXFLAGS += `sdl2-config --cflags` -Iimgui
	# imgui_impl_sdl.cpp includes <SDL.h>, sim_video.cpp includes <SDL2/SDL.h>;
	# add the parent of SDL2/ so both spellings resolve.
	CXXFLAGS += `sdl2-config --cflags | sed 's|include/SDL2|include/|'`
	CXXFLAGS += -I/usr/local/include -I/opt/local/include
endif

ifeq ($(UNAME_S), Linux)
	LIBS += -lGL -ldl `sdl2-config --libs`
	CXXFLAGS += `sdl2-config --cflags` -Iimgui
endif

CXXFLAGS += -I../sim/imgui -I../sim/ -O3 -std=c++17
LDFLAGS   = $(LIBS)

V_OPT = -O3 --x-assign fast --x-initial fast --noassert --public-flat-rw \
	-Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
	-Wno-UNSIGNED -Wno-CMPCONST -Wno-DECLFILENAME

EXE = ./obj_dir/Vtop
C_SRC = \
	sim_main.cpp \
	sim/sim_bus.cpp sim/sim_clock.cpp sim/sim_console.cpp sim/sim_video.cpp sim/sim_input.cpp \
	sim/imgui/imgui_impl_sdl.cpp sim/imgui/imgui_impl_opengl2.cpp sim/imgui/imgui_draw.cpp \
	sim/imgui/imgui_widgets.cpp sim/imgui/imgui_tables.cpp sim/imgui/imgui.cpp \
	sim/imgui/ImGuiFileDialog.cpp

HL_DIR = obj_dir_headless
HL_EXE = ./$(HL_DIR)/Vtop
HL_SRC = sim_headless.cpp

all: $(EXE)

headless: $(HL_EXE)

$(GEN_V): $(VHD_SRC) $(CONVERTED_V) Makefile
	@mkdir -p $(GEN) $(WORK)
	$(GHDL) -a --std=08 --workdir=$(WORK) -Wno-hide $(VHD_SRC)
	$(GHDL) synth --std=08 --workdir=$(WORK) --out=verilog $(VHD_TOP) > $@.tmp
	@if [ -n "$(CONVERTED)" ]; then python3 strip_modules.py $@.tmp $(CONVERTED); fi
	@mv $@.tmp $@

netlist: $(GEN_V)

$(HL_EXE): $(V_SRC) $(HL_SRC) Makefile
	$V -cc $(V_OPT) -exe --Mdir ./$(HL_DIR) $(TOP) \
		-CFLAGS "-O2 -std=c++17" -LDFLAGS "-lz" $(V_SRC) $(HL_SRC)
	$(MAKE) -C $(HL_DIR) -f Vtop.mk

$(EXE): $(V_SRC) $(C_SRC) Makefile
	$V -cc $(V_OPT) -LDFLAGS "$(LDFLAGS)" -exe --trace --Mdir ./obj_dir \
		$(TOP) -CFLAGS "$(CXXFLAGS)" $(V_SRC) $(C_SRC)
	$(MAKE) -C obj_dir -f Vtop.mk

lint: $(GEN_V)
	$V --lint-only -Wall -Wno-DECLFILENAME -Wno-fatal $(TOP) $(V_SRC)

test-cpu-clock: $(GEN_V)
	$(GHDL) -a --std=08 --workdir=$(WORK) tests/tb_cpu_clock.vhd
	$(GHDL) -r --std=08 --workdir=$(WORK) tb_cpu_clock --assert-level=error

.PHONY: test-cpu-ports
test-cpu-ports:
	mkdir -p out/cpu_ports
	$(GHDL) -a --std=08 --workdir=out/cpu_ports -Wno-hide $(VHD_SRC) tests/tb_cpu_ports.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_ports tb_cpu_ports --assert-level=error --ieee-asserts=disable

.PHONY: test-cpu-opcode-timing
test-cpu-opcode-timing:
	mkdir -p out/cpu_opcode_timing
	$(GHDL) -a --std=08 --workdir=out/cpu_opcode_timing $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_cpu_opcode_timing.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_opcode_timing tb_cpu_opcode_timing --assert-level=error --ieee-asserts=disable

.PHONY: test-cpu-branches
test-cpu-branches:
	mkdir -p out/cpu_branches
	$(GHDL) -a --std=08 --workdir=out/cpu_branches $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_cpu_branches.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_branches tb_cpu_branches --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/cpu_branches tb_cpu_branches -gcheck_br7=false --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/cpu_branches tb_cpu_branches -gcheck_br7=false -gcheck_bt=true --assert-level=error

.PHONY: test-cpu-reset
test-cpu-reset:
	mkdir -p out/cpu_reset
	$(GHDL) -a --std=08 --workdir=out/cpu_reset $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/uv202/uv202_clkgen.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_cpu_reset.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_reset tb_cpu_reset --assert-level=error --ieee-asserts=disable

.PHONY: test-cpu-interrupt
test-cpu-interrupt:
	mkdir -p out/ghdl_cpu_interrupt
	$(GHDL) -a --std=08 --workdir=out/ghdl_cpu_interrupt $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_cpu_interrupt.vhd
	$(GHDL) -r --std=08 --workdir=out/ghdl_cpu_interrupt tb_cpu_interrupt --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/ghdl_cpu_interrupt tb_cpu_interrupt -glate_request=true --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/ghdl_cpu_interrupt tb_cpu_interrupt -glong_cycle=true --assert-level=error

test-cpu-irq-chain:
	mkdir -p out/cpu_irq_chain
	$(GHDL) -a --std=08 --workdir=out/cpu_irq_chain $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_cpu_irq_chain.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_irq_chain tb_cpu_irq_chain --assert-level=error

.PHONY: test-cpu-irq-chain

test-cpu-bus-wait:
	mkdir -p out/cpu_bus_wait
	$(GHDL) -a --std=08 --workdir=out/cpu_bus_wait $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/uv202/uv202_clkgen.vhd $(RTL)/uv202/uv202_cpu_gate.vhd $(RTL)/uv202/uv202_timing.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd $(RTL)/uv202/uv202_arbiter.vhd $(RTL)/uv202/uv202_top.vhd tests/tb_cpu_bus_wait.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_bus_wait tb_cpu_bus_wait --assert-level=error --ieee-asserts=disable $(BUS_WAIT_ARGS)

.PHONY: test-cpu-bus-wait

test-cpu-gate:
	mkdir -p out/cpu_gate
	$(GHDL) -a --std=08 --workdir=out/cpu_gate $(RTL)/f8/base_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/uv202/uv202_clkgen.vhd $(RTL)/uv202/uv202_cpu_gate.vhd $(RTL)/uv202/uv202_timing.vhd $(RTL)/uv202/uv202_arbiter.vhd $(RTL)/uv202/uv202_top.vhd tests/tb_cpu_gate.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_gate tb_cpu_gate --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/cpu_gate tb_cpu_gate -glegacy_gate=true --assert-level=error

.PHONY: test-cpu-gate

.PHONY: test-smi-clock
test-smi-clock:
	mkdir -p out/smi_clock
	$(GHDL) -a --std=08 --workdir=out/smi_clock -Wno-hide $(VHD_SRC) tests/tb_smi_clock.vhd
	$(GHDL) -r --std=08 --workdir=out/smi_clock tb_smi_clock --assert-level=error --ieee-asserts=disable

.PHONY: test-smi
test-smi:
	mkdir -p out/ghdl_smi
	$(GHDL) -a --std=08 --workdir=out/ghdl_smi $(RTL)/f8/base_pack.vhd $(RTL)/f3853.vhd $(RTL)/uv201/uv201_yint.vhd tests/tb_f3853.vhd tests/tb_f3853_timer.vhd
	$(GHDL) -r --std=08 --workdir=out/ghdl_smi tb_f3853 --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/ghdl_smi tb_f3853_timer --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/ghdl_smi tb_f3853_timer -gdivider=1 --assert-level=error
	$(GHDL) -a --std=08 --workdir=out/ghdl_smi $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_smi_vector.vhd
	$(GHDL) -r --std=08 --workdir=out/ghdl_smi tb_smi_vector --assert-level=error

test-yint: $(GEN_V)
	$(GHDL) -a --std=08 --workdir=$(WORK) tests/tb_yint.vhd
	$(GHDL) -r --std=08 --workdir=$(WORK) tb_yint --assert-level=error

test-render: $(GEN_V)
	$(GHDL) -a --std=08 --workdir=$(WORK) tests/tb_render.vhd
	$(GHDL) -r --std=08 --workdir=$(WORK) tb_render --assert-level=error

.PHONY: test-audio-io
test-audio-io:
	mkdir -p out/ghdl_audio_io
	$(GHDL) -a --std=08 --workdir=out/ghdl_audio_io $(RTL)/f8/base_pack.vhd $(RTL)/videobrain_io.vhd tests/tb_audio_io.vhd
	$(GHDL) -r --std=08 --workdir=out/ghdl_audio_io tb_audio_io --assert-level=error

test-audio: test-audio-io
	PYTHONDONTWRITEBYTECODE=1 python3 tests/audio_filter_design.py
	$V -cc --exe --build --top-module videobrain_audio --Mdir out/obj_audio \
		$(RTL)/videobrain_audio.sv $(abspath tests/tb_audio.cpp)
	./out/obj_audio/Vvideobrain_audio --sweep out/audio_sweep.bin
	PYTHONDONTWRITEBYTECODE=1 python3 tests/test_audio_alias.py out/audio_sweep.bin
	$V -cc --exe --build --top-module videobrain_audio_fir --Mdir out/obj_audio_fir \
		$(RTL)/videobrain_audio.sv $(abspath tests/tb_audio_fir.cpp)
	./out/obj_audio_fir/Vvideobrain_audio_fir $(RTL)/videobrain_audio.sv

.PHONY: test-audio-path
test-audio-path:
	python3 -B tests/check_audio_path.py --run

test-expander1:
	@mkdir -p out/expander1
	$(GHDL) -a --std=08 --workdir=out/expander1 $(RTL)/f8/base_pack.vhd \
		$(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd \
		$(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd \
		$(RTL)/f3870_timer.vhd $(RTL)/expander1.vhd \
		tests/tb_f3870_timer.vhd tests/tb_expander1.vhd
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_f3870_timer --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1 --assert-level=error

test-cartridges:
	@mkdir -p out/cartridges
	$(GHDL) -a --std=08 --workdir=out/cartridges $(RTL)/f8/base_pack.vhd \
		$(RTL)/uv201/uv201_pack.vhd $(RTL)/uv202/uv202_pack.vhd \
		$(RTL)/uv201/uv201_regs.vhd $(RTL)/buffered_bus.vhd \
		$(RTL)/sys_bus.vhd tests/tb_cartridges.vhd
	$(GHDL) -r --std=08 --workdir=out/cartridges tb_cartridges --assert-level=error

EXPANDER1_ROM ?= ../software/0 BIOS/VideoBrain Expander I (197x)(VideoBrain Computer Company)(VideoBrain)(ROM)[F3870].bin

test-expander1-serial: test-expander1
	$(GHDL) -a --std=08 --workdir=out/expander1 tests/tb_expander1_serial.vhd
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1_serial \
		"-gfirmware=$(EXPANDER1_ROM)" --assert-level=error --ieee-asserts=disable
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1_serial \
		"-gfirmware=$(EXPANDER1_ROM)" -gbaud_rate=110 --assert-level=error --ieee-asserts=disable

.PHONY: test-expander1-serial

test-printer: test-expander1-serial $(TEST_BUILD_ID) test-printer-image test-printer-hps test-printer-rom
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1_serial \
		"-gfirmware=$(EXPANDER1_ROM)" -gprinter_only=true --assert-level=error --ieee-asserts=disable
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1_serial \
		"-gfirmware=$(EXPANDER1_ROM)" -gprinter_only=true -gbaud_rate=110 --assert-level=error --ieee-asserts=disable
	iverilog -g2012 -i -I$(TEST_INCLUDE) -I.. -s tb_printer_uart -o out/expander1/printer_uart \
		tests/tb_printer_uart.sv ../VideoBrain.sv $(RTL)/videobrain_printer_rx.sv $(RTL)/videobrain_printer_capture.sv
	vvp out/expander1/printer_uart
	PYTHONDONTWRITEBYTECODE=1 python3 tests/test_capture_printer.py
	PYTHONDONTWRITEBYTECODE=1 python3 tests/test_printer_image.py

.PHONY: test-printer

test-expander1-record: test-expander1
	$(GHDL) -a --std=08 --workdir=out/expander1 tests/tb_expander1_record.vhd
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1_record \
		"-gfirmware=$(EXPANDER1_ROM)" --assert-level=error --ieee-asserts=disable
	PYTHONDONTWRITEBYTECODE=1 python3 tests/check_expander1_record.py out/expander1/record.csv
	$(GHDL) -r --std=08 --workdir=out/expander1 tb_expander1_record \
		"-gfirmware=$(EXPANDER1_ROM)" -gbad_crc=true \
		-gcapture_file=out/expander1/record-bad.csv --assert-level=error --ieee-asserts=disable

.PHONY: test-expander1-record

test-tape:
	@mkdir -p out/expander1
	$(V) --binary --timing -Wno-fatal --top-module tb_tape \
		--Mdir out/expander1/obj_tape $(RTL)/videobrain_tape.sv \
		tests/tape_sd_model.sv tests/tb_tape.sv
	./out/expander1/obj_tape/Vtb_tape

test-dual-tape:
	@mkdir -p out/expander1
	$(V) --binary --timing -Wno-fatal --top-module tb_dual_tape \
		--Mdir out/expander1/obj_dual_tape $(RTL)/videobrain_tape.sv \
		$(RTL)/videobrain_tapes.sv tests/tape_dual_sd_model.sv tests/tb_dual_tape.sv
	./out/expander1/obj_dual_tape/Vtb_dual_tape

.PHONY: test-dual-tape

test-expander1-edit: test-expander1 test-dual-tape
	$(GHDL) synth --std=08 --workdir=out/expander1 --out=verilog expander1 > out/expander1/expander1.v
	$(V) --binary --timing -Wno-fatal --top-module tb_expander1_edit \
		--Mdir out/expander1/obj_edit out/expander1/expander1.v \
		$(RTL)/videobrain_tape.sv $(RTL)/videobrain_tapes.sv \
		tests/tape_dual_sd_model.sv tests/tb_expander1_edit.sv
	./out/expander1/obj_edit/Vtb_expander1_edit "+firmware=$(EXPANDER1_ROM)"

.PHONY: test-expander1-edit

test-expander1-playback: test-expander1 test-tape
	$(GHDL) synth --std=08 --workdir=out/expander1 --out=verilog expander1 > out/expander1/expander1.v
	$(V) --binary --timing -Wno-fatal --top-module tb_expander1_playback \
		--Mdir out/expander1/obj_playback out/expander1/expander1.v \
		$(RTL)/videobrain_tape.sv tests/tape_sd_model.sv tests/tb_expander1_playback.sv
	./out/expander1/obj_playback/Vtb_expander1_playback "+firmware=$(EXPANDER1_ROM)"

.PHONY: test-tape test-expander1-playback

capture-apl-save: headless
	@mkdir -p out/expander1/apl-save
	PYTHONDONTWRITEBYTECODE=1 python3 ../tools/apl_source.py tests/apl_save.txt out/expander1/apl-save/save.vbk
	$(HL_EXE) \
		--cart "../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" \
		--expander1 "$(EXPANDER1_ROM)" \
		--source out/expander1/apl-save/save.vbk@210 --frames 7000 \
		--record out/expander1/apl-save/record.csv \
		--shot-last --prefix save --outdir out/expander1/apl-save
	PYTHONDONTWRITEBYTECODE=1 python3 tests/check_expander1_record.py out/expander1/apl-save/record.csv --workspace

.PHONY: capture-apl-save

APL_TAPE ?= ../refs/tape-observations/apls-test.vbt

replay-apl-tape: headless
	@mkdir -p out/expander1/apl-load
	PYTHONDONTWRITEBYTECODE=1 python3 ../tools/apl_source.py tests/apl_load.txt out/expander1/apl-load/load.vbk
	$(HL_EXE) \
		--cart "../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" \
		--expander1 "$(EXPANDER1_ROM)" --playback "$(APL_TAPE)" \
		--expander-trace out/expander1/apl-load/host.csv \
		--source out/expander1/apl-load/load.vbk@210 --frames 1600 \
		--shot-last --prefix load --outdir out/expander1/apl-load

.PHONY: replay-apl-tape

test-joystick:
	@mkdir -p out/joystick_test
	$(V) --binary --timing --assert --top-module tb_joystick \
		--Mdir out/joystick_test $(RTL)/videobrain_joystick.sv tests/tb_joystick.sv
	./out/joystick_test/Vtb_joystick

.PHONY: test-joystick

# Wrapper tests use a fixed build date without generating Quartus files.
$(TEST_BUILD_ID):
	@mkdir -p $(@D)
	@printf '%s\n' '`define BUILD_DATE "simulation"' > $@

test-video: $(TEST_BUILD_ID)
	@mkdir -p out/video
	$(GHDL) -a --std=08 --workdir=out/video $(RTL)/f8/base_pack.vhd \
		$(RTL)/uv201/uv201_pack.vhd $(RTL)/uv202/uv202_pack.vhd \
		$(RTL)/uv202/uv202_clkgen.vhd $(RTL)/uv202/uv202_timing.vhd \
		$(RTL)/uv201/uv201_render.vhd tests/video_test_source.vhd
	$(GHDL) synth --std=08 --workdir=out/video --out=verilog video_test_source > out/video/source.v
	iverilog -g2012 -i -I$(TEST_INCLUDE) -I.. -s tb_video -o out/video/test \
		tests/tb_video.sv out/video/source.v ../VideoBrain.sv \
		../sys/video_freak.sv
	vvp out/video/test

.PHONY: test-video

out/joystick_timing/core.v: $(VHD_SRC)
	@mkdir -p out/joystick_timing
	$(GHDL) -a --std=08 --workdir=out/joystick_timing -Wno-hide $(VHD_SRC)
	$(GHDL) synth --std=08 --workdir=out/joystick_timing --out=verilog $(VHD_TOP) > $@.tmp
	@mv $@.tmp $@

test-joystick-timing: out/joystick_timing/core.v
	iverilog -g2012 -s tb_joystick_timing -o out/joystick_timing/test \
		tests/tb_joystick_timing.sv out/joystick_timing/core.v
	vvp out/joystick_timing/test

.PHONY: test-joystick-timing

clean:
	rm -rf obj_dir $(HL_DIR) $(GEN) $(WORK)

.PHONY: all headless netlist lint test-cpu-clock test-yint test-render test-audio test-expander1 test-cartridges clean

test-apl-input: test-cartridges
	$(GHDL) -r --std=08 --workdir=out/cartridges tb_cartridges --assert-level=error \
		"-gapl_image=../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin"

MT1_ROM ?= ../software/1 Cartridges/Music Teacher 1 (1978.03.28)(VideoBrain Computer Company)(VideoBrain)(Cart)[ED01].bin
MT1_PATCHED_ROM ?=

test-music-input: test-cartridges
	$(GHDL) -r --std=08 --workdir=out/cartridges tb_cartridges --assert-level=error "-gmusic_image=$(MT1_ROM)"
	@if [ -n "$(MT1_PATCHED_ROM)" ]; then \
		$(GHDL) -r --std=08 --workdir=out/cartridges tb_cartridges --assert-level=error "-gmusic_image=$(MT1_PATCHED_ROM)"; \
	fi

.PHONY: test-tools
test-tools:
	python3 -B tests/run_tools.py

out/logic_captures/analyze_logic_csv: tests/analyze_logic_csv.cpp
	mkdir -p out/logic_captures
	$(CXX) -std=c++17 -O3 -Wall -Wextra $< -o $@

.PHONY: test-logic-csv
test-logic-csv: out/logic_captures/analyze_logic_csv
	python3 -B tests/check_logic_csv.py $<

.PHONY: test-sean-diag
test-sean-diag:
	mkdir -p out/sean_diag
	$(GHDL) -a --std=08 --workdir=out/sean_diag $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd tests/tb_sean_diag.vhd
	$(GHDL) -r --std=08 --workdir=out/sean_diag tb_sean_diag --assert-level=error --ieee-asserts=disable

.PHONY: test-uv201-wait
test-uv201-wait:
	mkdir -p out/uv201_wait
	$(GHDL) -a --std=08 --workdir=out/uv201_wait $(RTL)/f8/base_pack.vhd $(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd $(RTL)/uv202/uv202_clkgen.vhd $(RTL)/uv202/uv202_cpu_gate.vhd $(RTL)/uv202/uv202_timing.vhd $(RTL)/f8/f8_cpu.vhd $(RTL)/uv202/f8_busif.vhd $(RTL)/uv202/uv202_arbiter.vhd $(RTL)/uv202/uv202_top.vhd tests/tb_uv201_wait.vhd
	$(GHDL) -r --std=08 --workdir=out/uv201_wait tb_uv201_wait --assert-level=error --ieee-asserts=disable -ggap_csv=out/uv201_wait/read.csv
	$(GHDL) -r --std=08 --workdir=out/uv201_wait tb_uv201_wait --assert-level=error --ieee-asserts=disable -gwrite_test=true -ggap_csv=out/uv201_wait/write.csv
	$(GHDL) -r --std=08 --workdir=out/uv201_wait tb_uv201_wait --assert-level=error --ieee-asserts=disable -gdma_mode=true -ggap_csv=out/uv201_wait/read-dma.csv
	$(GHDL) -r --std=08 --workdir=out/uv201_wait tb_uv201_wait --assert-level=error --ieee-asserts=disable -gwrite_test=true -gdma_mode=true -ggap_csv=out/uv201_wait/write-dma.csv

test-apl-source: test-apl-input test-cpu-interrupt test-tools
	@mkdir -p out/source_test
	$(V) --binary --timing -Wno-fatal --top-module tb_apl_source_loader \
		--Mdir out/source_test $(RTL)/apl_source_loader.sv tests/tb_apl_source_loader.sv
	./out/source_test/Vtb_apl_source_loader

.PHONY: test-apl-input test-apl-source test-music-input

replay-clock-source: headless
	@mkdir -p out/clock-source
	$(HL_EXE) \
		--cart "../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" \
		--source "../examples/21-apl_s-games-james-price/21-clock.vbk@210" \
		--source-trace --frames 14000 --max-cycles 6000000000 \
		--shot-every 500 --shot-last --prefix clock --outdir out/clock-source \
		> out/clock-source/run.log 2>&1

.PHONY: replay-clock-source

test-arbiter:
	@mkdir -p out/arbiter
	$(GHDL) -a --std=08 --workdir=out/arbiter $(RTL)/f8/base_pack.vhd \
		$(RTL)/uv202/uv202_pack.vhd $(RTL)/uv202/uv202_arbiter.vhd tests/tb_arbiter.vhd
	$(GHDL) -r --std=08 --workdir=out/arbiter tb_arbiter --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/arbiter tb_arbiter --assert-level=error -gdma_test=true

.PHONY: test-arbiter

test-fetcher-bus:
	@mkdir -p out/fetcher_bus
	$(GHDL) -a --std=08 --workdir=out/fetcher_bus $(RTL)/f8/base_pack.vhd \
		$(RTL)/uv201/uv201_pack.vhd $(RTL)/uv202/uv202_pack.vhd \
		$(RTL)/uv202/uv202_clkgen.vhd $(RTL)/uv202/uv202_arbiter.vhd \
		$(RTL)/uv201/uv201_fetcher.vhd tests/tb_fetcher_bus.vhd
	$(GHDL) -r --std=08 --workdir=out/fetcher_bus tb_fetcher_bus --assert-level=error
	$(GHDL) -r --std=08 --workdir=out/fetcher_bus tb_fetcher_bus --assert-level=error -gcopy_mode=true
	$(GHDL) -r --std=08 --workdir=out/fetcher_bus tb_fetcher_bus --assert-level=error -gbackpressure=true
	$(GHDL) -r --std=08 --workdir=out/fetcher_bus tb_fetcher_bus --assert-level=error -gcopy_mode=true -gbackpressure=true

.PHONY: test-fetcher-bus

test-cpu-audio:
	@mkdir -p out/cpu_audio
	$(GHDL) -a --std=08 --workdir=out/cpu_audio $(RTL)/f8/base_pack.vhd \
		$(RTL)/f8/f8_pack.vhd $(RTL)/uv202/uv202_pack.vhd \
		$(RTL)/uv202/uv202_clkgen.vhd $(RTL)/f8/f8_cpu.vhd \
		$(RTL)/uv202/f8_busif.vhd $(RTL)/videobrain_io.vhd tests/tb_cpu_audio.vhd
	$(GHDL) -r --std=08 --workdir=out/cpu_audio tb_cpu_audio --assert-level=error -gdelay_count=96
	$(GHDL) -r --std=08 --workdir=out/cpu_audio tb_cpu_audio --assert-level=error -gdelay_count=46
	$(GHDL) -r --std=08 --workdir=out/cpu_audio tb_cpu_audio --assert-level=error -gdelay_count=21
	$(GHDL) -r --std=08 --workdir=out/cpu_audio tb_cpu_audio --assert-level=error -gdelay_count=8

.PHONY: test-cpu-audio

test-download-reset: $(TEST_BUILD_ID)
	@mkdir -p out/download_reset
	iverilog -g2012 -i -I$(TEST_INCLUDE) -I.. -s tb_download_reset -o out/download_reset/test \
		tests/tb_download_reset.sv ../VideoBrain.sv
	vvp out/download_reset/test

.PHONY: test-download-reset

# Real BIOS, cartridge, Expander firmware and unmounted tape decks.
test-apl-reload: $(GEN_V)
	$(V) --binary --timing -Wno-fatal -Wno-PINMISSING --top-module tb_apl_reload \
		--Mdir out/apl_reload $(GEN_V) $(RTL)/videobrain_tape.sv $(RTL)/videobrain_tapes.sv tests/tb_apl_reload.sv
	./out/apl_reload/Vtb_apl_reload \
		"+bios1=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[uvres-1n-2129-7802].bin" \
		"+bios2=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[7802G0-RESN2-KOREA].bin" \
		"+expander=$(EXPANDER1_ROM)" \
		"+cart=../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" $(APL_RELOAD_ARGS)

.PHONY: test-apl-reload

test-status-messages: $(TEST_BUILD_ID)
	@mkdir -p out/status_messages
	iverilog -g2012 -i -I$(TEST_INCLUDE) -I.. -s tb_status_messages -o out/status_messages/test \
		tests/tb_status_messages.sv ../VideoBrain.sv $(RTL)/videobrain_printer_rx.sv $(RTL)/videobrain_printer_capture.sv
	vvp out/status_messages/test

.PHONY: test-status-messages


test-printer-image:
	@mkdir -p out/expander1
	$(V) --binary --timing -Wno-fatal --top-module tb_printer_capture \
		--Mdir out/expander1/obj_printer $(RTL)/videobrain_printer_rx.sv \
		$(RTL)/videobrain_printer_capture.sv tests/tb_printer_capture.sv
	./out/expander1/obj_printer/Vtb_printer_capture
	PYTHONDONTWRITEBYTECODE=1 python3 tests/test_printer_image.py

.PHONY: test-printer-image


test-printer-hps:
	@mkdir -p out/expander1
	$(V) --binary --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-BLKANDNBLK -Wno-PINMISSING --top-module tb_printer_hps \
		--Mdir out/expander1/obj_printer_hps ../sys/hps_io.sv \
		$(RTL)/videobrain_printer_rx.sv $(RTL)/videobrain_printer_capture.sv \
		tests/printer_hps_model.sv tests/tb_printer_hps.sv
	./out/expander1/obj_printer_hps/Vtb_printer_hps

.PHONY: test-printer-hps




test-printer-rom: test-expander1
	$(GHDL) synth --std=08 --workdir=out/expander1 --out=verilog expander1 > out/expander1/expander1.v
	$(V) --binary --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-BLKANDNBLK -Wno-PINMISSING \
		--top-module tb_printer_rom --Mdir out/expander1/obj_printer_rom \
		../sys/hps_io.sv out/expander1/expander1.v $(RTL)/videobrain_printer_rx.sv \
		$(RTL)/videobrain_printer_capture.sv tests/printer_hps_model.sv tests/tb_printer_rom.sv
	./out/expander1/obj_printer_rom/Vtb_printer_rom "+firmware=$(EXPANDER1_ROM)"

.PHONY: test-printer-rom


test-printer-cartridge: $(GEN_V)
	@mkdir -p out/expander1
	$(V) --binary --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-BLKANDNBLK -Wno-PINMISSING \
		--top-module tb_printer_cartridge --Mdir out/expander1/obj_printer_cartridge \
		../sys/hps_io.sv $(GEN_V) $(RTL)/videobrain_printer_rx.sv \
		$(RTL)/videobrain_printer_capture.sv tests/printer_hps_model.sv tests/tb_printer_cartridge.sv
	./out/expander1/obj_printer_cartridge/Vtb_printer_cartridge \
		"+bios1=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[uvres-1n-2129-7802].bin" \
		"+bios2=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[7802G0-RESN2-KOREA].bin" \
		"+firmware=$(EXPANDER1_ROM)" \
		"+cart=../software/1 Cartridges/Timeshare (1978.09.01)(VideoBrain Computer Company)(VideoBrain)(Cart)[CM01].bin"
	python3 tests/test_printer_image.py PrinterImageTests.test_timeshare

.PHONY: test-printer-cartridge


test-printer-infoman: $(GEN_V)
	@mkdir -p out/expander1
	python3 tests/make_printer_fixture.py out/expander1/infoman-printer.vbt
	$(V) --binary --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-BLKANDNBLK -Wno-PINMISSING \
		--top-module tb_printer_infoman --Mdir out/expander1/obj_printer_infoman \
		../sys/hps_io.sv $(GEN_V) $(RTL)/videobrain_printer_rx.sv \
		$(RTL)/videobrain_printer_capture.sv $(RTL)/videobrain_tape.sv $(RTL)/videobrain_tapes.sv \
		tests/printer_hps_model.sv tests/tb_printer_infoman.sv
	./out/expander1/obj_printer_infoman/Vtb_printer_infoman \
		"+bios1=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[uvres-1n-2129-7802].bin" \
		"+bios2=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[7802G0-RESN2-KOREA].bin" \
		"+firmware=$(EXPANDER1_ROM)" \
		"+cart=../software/1 Cartridges/Information Manager (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)(prototype)[VB-1200].bin" \
		"+fixture=out/expander1/infoman-printer.vbt"
	python3 tests/test_printer_image.py PrinterImageTests.test_infoman

test-printer-infoman-apple: $(GEN_V)
	@mkdir -p out/expander1
	$(V) --binary --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-BLKANDNBLK -Wno-PINMISSING \
		--top-module tb_printer_infoman --Mdir out/expander1/obj_printer_infoman_apple \
		../sys/hps_io.sv $(GEN_V) $(RTL)/videobrain_printer_rx.sv \
		$(RTL)/videobrain_printer_capture.sv $(RTL)/videobrain_tape.sv $(RTL)/videobrain_tapes.sv \
		tests/printer_hps_model.sv tests/tb_printer_infoman.sv
	./out/expander1/obj_printer_infoman_apple/Vtb_printer_infoman \
		"+bios1=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[uvres-1n-2129-7802].bin" \
		"+bios2=../software/0 BIOS/VideoBrain BIOS (1977)(VideoBrain Computer Company)(VideoBrain)(ROM)[7802G0-RESN2-KOREA].bin" \
		"+firmware=$(EXPANDER1_ROM)" \
		"+cart=../software/1 Cartridges/Information Manager (1978)(VideoBrain Computer Company)(VideoBrain)(Cart)(prototype)[VB-1200].bin" \
		"+fixture=../examples/saves/Information Manager - APPLE.vbt" +apple +trace_serial

.PHONY: test-printer-infoman test-printer-infoman-apple


test-printer-tapes: test-expander1
	test -f out/expander1/printer-tape-blank.vbp || python3 ../tools/printer_image.py new out/expander1/printer-tape-blank.vbp --size 32768
	$(GHDL) synth --std=08 --workdir=out/expander1 --out=verilog expander1 > out/expander1/expander1.v
	$(V) --binary --timing -Wno-fatal -Wno-PROCASSWIRE -Wno-BLKANDNBLK -Wno-PINMISSING \
		--top-module tb_printer_tapes --Mdir out/expander1/obj_printer_tapes \
		../sys/hps_io.sv out/expander1/expander1.v $(RTL)/videobrain_printer_rx.sv \
		$(RTL)/videobrain_printer_capture.sv $(RTL)/videobrain_tape.sv $(RTL)/videobrain_tapes.sv \
		tests/printer_hps_model.sv tests/tb_printer_tapes.sv
	./out/expander1/obj_printer_tapes/Vtb_printer_tapes "+firmware=$(EXPANDER1_ROM)" +capture=0
	./out/expander1/obj_printer_tapes/Vtb_printer_tapes "+firmware=$(EXPANDER1_ROM)" +capture=1
	python3 tests/test_printer_image.py PrinterImageTests.test_tape_contention

.PHONY: test-printer-tapes
