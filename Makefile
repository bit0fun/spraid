# Tools
VC=iverilog
VSIM=vvp -lxt2

#cocotb setup
COCOTB_MODULES=$$(cocotb-config --prefix)/cocotb/libs 
VSIM_MODULES= -M $(COCOTB_MODULES) -m libcocotbvpi_icarus sim_build/sim.vvp


# FPGA Settings
PROJECT = fpga/spraid
SRC = src/spraid.v src/spi_slave.v src/raid0.v src/raid1.v src/raid5.v src/flash_ctl.v src/sync_fifo.v src/raid0_write.v src/raid0_read.v src/spi.v
ICEBREAKER_DEVICE = up5k
ICEBREAKER_PIN_DEF = fpga/icebreaker.pcf
ICEBREAKER_PACKAGE = sg48
SEED = 1
NEXTPNR_FREQ=20

# Verilog source for testing SPI Flash 
#TEST_SRC = sim_src/W25Q80DL.v
TEST_SRC = sim_src/MX25V1006F.v


export COCOTB_REDUCED_LOG_FMT=1

all: test_spi test_raid0 test_raid1 test_raid5 test_flash_ctl test_spraid

test_fifo: src/sync_fifo.v test/dump_sync_fifo.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s sync_fifo -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_spi: src/spi.v test/dump_spi.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s spi -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_flashtb: sim_src/flashtb.v test/dump_flashtb.v src/spi.v $(TEST_SRC) 
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s flashtb -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_raid: src/raid.v test/dump_raid.v 
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_raid0: src/raid0.v src/raid0_write.v src/raid0_read.v test/dump_raid0.v test/dump_raid0_write.v test/dump_raid0_read.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid0 -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_raid0_write: src/raid0_write.v test/dump_raid0_write.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid0_write -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_raid0_read: src/raid0_read.v test/dump_raid0_read.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid0_read -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_raid1: src/raid1.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid1 -s dump -g2012 $^ test/dump_raid1.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_raid5: src/raid5.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid5 -s dump -g2012 $^ test/dump_raid5.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_flash_ctl: src/spi_slave.v src/flash_ctl.v $(TEST_SRC)
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s flash_ctl -s dump -g2012 $^ test/dump_flash_ctl.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_spraid: $(SRC) $(TEST_SRC)
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s spraid -s dump -g2012 $^ test/dump_spraid.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

formal_all: formal_sync_fifo

formal_%: formal/%.sby src/%.v 
	sby -f $<

show_raid0_write: raid0_write.vcd gtkwave/raid0_write.gtkw
	gtkwave $^

show_%: %.vcd gtkwave/%.gtkw
	gtkwave $^

# FPGA build
show_synth_%: src/%.v
	yosys -p "read_verilog $<; proc; opt; show -colors 2 -width -signed"

%.json: $(SRC)
	yosys -l fpga/yosys.log -p 'synth_ice40 -top spraid -json $(PROJECT).json' $^

%.asc: %.json $(ICEBREAKER_PIN_DEF)
	nextpnr-ice40 -l fpga/nextpnr.log --seed $(SEED) --freq $(NEXTPNR_FREQ) --package $(ICEBREAKER_PACKAGE) --$(ICEBREAKER_DEVICE) --asc --pcf $(ICEBREAKER_PIN_DEF) --json $<

%.bin: %.asc
	icepack $< $@

prog: $(PROJECT).bin
	iceprog $<

lint:
	verible-verilog-lint $(SRC) --rules_config verible.rules

clean:
	rm -rf *vcd sim_build fpga/*log fpga/*bin test/__pycache__

.PHONY: clean lint







