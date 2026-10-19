
V     = verilator
GHDL  = ghdl
RTL   = ../rtl
GEN   = gen
WORK  = ghdl_work

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

.PHONY: test-smi
test-smi:
	mkdir -p out/ghdl_smi
	$(GHDL) -a --std=08 --workdir=out/ghdl_smi $(RTL)/f8/base_pack.vhd $(RTL)/f3853.vhd $(RTL)/uv201/uv201_yint.vhd tests/tb_f3853.vhd
	$(GHDL) -r --std=08 --workdir=out/ghdl_smi tb_f3853 --assert-level=error

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

test-expander1-playback: test-expander1 test-tape
	$(GHDL) synth --std=08 --workdir=out/expander1 --out=verilog expander1 > out/expander1/expander1.v
	$(V) --binary --timing -Wno-fatal --top-module tb_expander1_playback \
		--Mdir out/expander1/obj_playback out/expander1/expander1.v \
		$(RTL)/videobrain_tape.sv tests/tape_sd_model.sv tests/tb_expander1_playback.sv
	./out/expander1/obj_playback/Vtb_expander1_playback "+firmware=$(EXPANDER1_ROM)"

.PHONY: test-tape test-expander1-playback

capture-apl-save: headless
	@mkdir -p out/expander1/apl-save
	PYTHONDONTWRITEBYTECODE=1 python3 apl_source.py tests/apl_save.txt out/expander1/apl-save/save.vbk
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
	PYTHONDONTWRITEBYTECODE=1 python3 apl_source.py tests/apl_load.txt out/expander1/apl-load/load.vbk
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

test-video:
	@mkdir -p out/video
	$(GHDL) -a --std=08 --workdir=out/video $(RTL)/f8/base_pack.vhd \
		$(RTL)/uv201/uv201_pack.vhd $(RTL)/uv202/uv202_pack.vhd \
		$(RTL)/uv202/uv202_clkgen.vhd $(RTL)/uv202/uv202_timing.vhd \
		$(RTL)/uv201/uv201_render.vhd tests/video_test_source.vhd
	$(GHDL) synth --std=08 --workdir=out/video --out=verilog video_test_source > out/video/source.v
	iverilog -g2012 -i -I.. -s tb_video -o out/video/test \
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

# test-apl-ram: test-cartridges
# 	$(GHDL) -r --std=08 --workdir=out/cartridges tb_cartridges --assert-level=error \
# 		"-gapl_image=../software/converted/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" \
# 		"-gapl_dump=../software/21 games for apl_s/guess.bin"
# 	@mkdir -p $(WORK)
# 	$(GHDL) -a --std=08 --workdir=$(WORK) -Wno-hide $(VHD_SRC) tests/tb_apl_loader.vhd
# 	$(GHDL) -r --std=08 --workdir=$(WORK) tb_apl_loader --assert-level=error

# .PHONY: test-apl-ram

test-apl-input: test-cartridges
	$(GHDL) -r --std=08 --workdir=out/cartridges tb_cartridges --assert-level=error \
		"-gapl_image=../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin"

test-apl-source: test-apl-input test-cpu-interrupt
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_apl_source.py
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_apl_next_sweep.py
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_keyboard_input.py
	@mkdir -p out/source_test
	$(V) --binary --timing -Wno-fatal --top-module tb_apl_source_loader \
		--Mdir out/source_test $(RTL)/apl_source_loader.sv tests/tb_apl_source_loader.sv
	./out/source_test/Vtb_apl_source_loader

.PHONY: test-apl-input test-apl-source

replay-clock-source: headless
	@mkdir -p out/clock-source
	$(HL_EXE) \
		--cart "../software/1 Cartridges/APL-S - The Computational Language (1979.01.24)(VideoBrain Computer Company)(VideoBrain)(Cart)[APL-S].bin" \
		--source "../software/2 VideoBrain Keyboard Input Files (vbk)/21-apl_s-games-james-price/21-clock.vbk@210" \
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

test-download-reset:
	@mkdir -p out/download_reset
	iverilog -g2012 -i -I.. -s tb_download_reset -o out/download_reset/test \
		tests/tb_download_reset.sv ../VideoBrain.sv
	vvp out/download_reset/test

.PHONY: test-download-reset
