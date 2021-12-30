# Tools
VC=iverilog
VSIM=vvp -lxt2

#cocotb setup
COCOTB_MODULES=$$(cocotb-config --prefix)/cocotb/libs 
VSIM_MODULES= -M $(COCOTB_MODULES) -m libcocotbvpi_icarus sim_build/sim.vvp

# Source files 
SRC_SYNCFIFO= src/sync_fifo.v
SRC_PLOADSHIFT= src/pload_shift.v
SRC_PREADSHIFT= src/pread_shift.v
SRC_RAID= src/raid.v
SRC_SPI32= src/spi32.v src/spi_master.v $(SRC_SYNCFIFO) $(SRC_PLOADSHIFT)
SRC_FLASHCTL = src/flash_ctl.v $(SRC_SPI32)
SRC_SPRAID= src/spraid.v $(SRC_RAID) $(SRC_FLASHCTL)
SRC_WBSPRAID= src/wb_spraid.v $(SRC_SPRAID)
SRC= $(SRC_SPRAID)

# Simulation Sources 
#SRC_NOR_IC = sim_src/W25Q80DL.v
SRC_NOR_IC = sim_src/MX25V1006F.v
SRC_FRAM_IC = sim_src/FRAM_SPI.v sim_src/config.v
SRC_FLASHTBNOR= sim_src/flashtb_nor.v $(SRC_SPI32) $(SRC_NOR_IC)

# FPGA Settings
PROJECT = fpga/spraid

SRC_FPGA_FLASH_TEST	= fpga/flash_test.v $(SRC_FLASHCTL)

SRC_FPGA = fpga/top.v  $(SRC)
ICEBREAKER_DEVICE = up5k
ICEBREAKER_PIN_DEF = fpga/icebreaker.pcf
ICEBREAKER_PACKAGE = sg48
SEED = 1
NEXTPNR_FREQ=20




export COCOTB_REDUCED_LOG_FMT=1

all: test_fifo test_spi32 test_pload_shift test_pread_shift test_raid test_flash_ctl test_spraid


test_fifo: $(SRC_SYNCFIFO) test/dump_sync_fifo.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s sync_fifo -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_spi32: $(SRC_SPI32) test/dump_spi32.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s spi32 -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_pload_shift: $(SRC_PLOADSHIFT) test/dump_pload_shift.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s pload_shift -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_pread_shift: $(SRC_PREADSHIFT) test/dump_pread_shift.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s pread_shift -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_flashtb_nor: $(SRC_FLASHTBNOR) $(SRC_NOR_IC) test/dump_flashtb_nor.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s flashtb_nor -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_flashtb_fram: $(SRC_FLASHTBFRAM) $(SRC_FRAM_IC) test/dump_flashtb_fram.v 
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s flashtb_fram -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_raid: $(SRC_RAID) test/dump_raid.v 
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s raid -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_flash_ctl: $(SRC_FLASHCTL) test/dump_flash_ctl.v 
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s flash_ctl -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_spraid: $(SRC) test/dump_spraid.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s spraid -s dump -g2012 $^ test/dump_spraid.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)

test_wb_spraid: $(SRC_WBSPRAID)  test/dump_wb_spraid.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s wb_spraid -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)


test_flash_model: $(SRC_WBSPRAID)  test/dump_wb_spraid.v
	rm -rf sim_build
	mkdir -p sim_build
	$(VC) -o sim_build/sim.vvp -s wb_spraid -s dump -g2012 $^
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.$@ $(VSIM) $(VSIM_MODULES)





formal_all: formal_sync_fifo

formal_%: formal/%.sby src/%.v 
	sby -f $<

show_%: %.vcd gtkwave/%.gtkw
	gtkwave $^

# FPGA build
show_synth_%: src/%.v
	yosys -p "read_verilog $<; check; proc; opt; show -colors 2 -width -signed"

flash_test: flash_test.bin

fpga/flash_test.json: $(SRC_FPGA_FLASH_TEST)
	yosys -l fpga/yosys.log -p 'check; proc; opt; synth_ice40 -top flash_test -json fpga/flash_test.json' $^

#fpga/%.json: $(SRC)
#	yosys -l fpga/yosys.log -p 'synth_ice40 -top $(basename $(notdir $@)) -json $@' $^

fpga/%.asc: fpga/%.json $(ICEBREAKER_PIN_DEF)
	nextpnr-ice40 -l fpga/nextpnr.log --seed $(SEED) --freq $(NEXTPNR_FREQ) --package $(ICEBREAKER_PACKAGE) --$(ICEBREAKER_DEVICE) --asc $@ --pcf $(ICEBREAKER_PIN_DEF) --json $<

fpga/%_timing.log: fpga/%.asc fpga/icebreaker_timing.pcf
	icetime -t -d up5k -p fpga/icebreaker_timing.pcf -c $(NEXTPNR_FREQ) -r $@  $<

%.bin: fpga/%.asc
	icepack $< $@

prog: $(PROJECT).bin fpga/%_timing.log
	iceprog $<

lint:
	verible-verilog-lint $(SRC) --rules_config verible.rules

clean:
	rm -rf *vcd sim_build fpga/*log fpga/*bin test/__pycache__ fpga/*.json results.xml xt2 *.bin

.PHONY: clean lint







