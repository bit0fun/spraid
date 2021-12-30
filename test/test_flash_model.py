import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotbext.spi import SpiMaster, SpiSignals, SpiConfig
from .FM25C160B import FM25C160B
from cocotbext.wishbone.driver import WishboneMaster, WBOp
import random
from array import *

# Read and write operations for wishbone 
async def wb_write(dut, wbs, addr, data ):
    dut.wb_we_i.value = 1
    await wbs.send_cycle([WBOp(addr, data)])
    dut.wb_we_i.value = 0


async def wb_read( wbs, addr ):
    results = await wbs.send_cycle([WBOp(addr)])
    data = [entry.datrd for entry in results]
    return data[0]

async def reset(dut):
    dut.spi0_miso.value = 0
    dut.spi1_miso.value = 0
    dut.spi2_miso.value = 0
    dut.spi3_miso.value = 0
    dut.wb_rst_i.value = 1
#    dut.wb_lock_i.value = 0
#    dut.wb_rty_o.value = 0
    await ClockCycles(dut.wb_clk_i, 5)
    dut.wb_rst_i.value = 0
    await ClockCycles(dut.wb_clk_i, 10)

@cocotb.test()
async def test_flash_model(dut):

    data = 0x1234ABCD
    # Command = 0x03, address is 0x01AA, last byte is used for reading 
    read_cmd_test = 0x0301AA00

    # Setup FRAM models
    flash0_spi = SpiSignals(
        sclk = dut.spi0_clk,
        mosi = dut.spi0_mosi,
        miso = dut.spi0_miso,
        cs   = dut.spi0_cs
    )
    flash1_spi = SpiSignals(
        sclk = dut.spi1_clk,
        mosi = dut.spi1_mosi,
        miso = dut.spi1_miso,
        cs   = dut.spi1_cs
    )
    flash2_spi = SpiSignals(
        sclk = dut.spi2_clk,
        mosi = dut.spi2_mosi,
        miso = dut.spi2_miso,
        cs   = dut.spi2_cs
    )
    flash3_spi = SpiSignals(
        sclk = dut.spi3_clk,
        mosi = dut.spi3_mosi,
        miso = dut.spi3_miso,
        cs   = dut.spi3_cs
    )

    # Use SPI mode 0
    flash0 = FM25C160B( flash0_spi, 0, dut )
    flash1 = FM25C160B( flash1_spi, 0, dut )
    flash2 = FM25C160B( flash2_spi, 0, dut )
    flash3 = FM25C160B( flash3_spi, 0, dut )

    # raid type definitions
    raid0 = 0x00000001
    raid1 = 0x00000000
    raid5 = 0x00000005

    # Test data 
    write_data = 0x1234ABCD
    base_addr = 0x30000000
    raid_type_addr = 0x30000800
    stat_addr = 0x30000801

    # Start clock
    clock = Clock(dut.wb_clk_i, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    signals_dict = {
        "cyc": "wb_cyc_i",
        "stb": "wb_stb_i",
        "we": "wb_we_i",
        "adr": "wb_adr_i",
        "datwr" : "wb_dat_i",
        "datrd" : "wb_dat_o",
        "ack" : "wb_ack_o"
    }

    dut._log.info("Initializing wishbone master")
    # Initialize wishbone master 
    wbs = WishboneMaster( dut, "", dut.wb_clk_i, width=32, timeout=100, signals_dict=signals_dict)

    # Reset 
    dut._log.info("Resetting device")
    await reset(dut)

    # Write to raid_type register, then read back the data and make sure it is
    # correct 

    dut._log.info("Writing to raid_type register ")
    await wb_write(dut, wbs, raid_type_addr, raid5 )

    dut._log.info("Reading from raid_type register ")
    raid_type_reg = await wb_read( wbs, raid_type_addr )
    dut._log.info("Read back %02x from raid_type register" % (raid_type_reg) ) 

    assert( raid_type_reg == raid5 )
    await ClockCycles(dut.wb_clk_i, 5)

    # Actually set to RAID0 for the rest of the test 
    await wb_write(dut, wbs, raid_type_addr, raid0 )

    await ClockCycles(dut.wb_clk_i, 5)

    # Try reading status register 
    dut._log.info("Reading from status register ")   
    status_reg = await wb_read( wbs, stat_addr )
    dut._log.info("Read back %02x from status register" % (status_reg) ) 
    # Status should be zero 
    assert( status_reg == 0 )

    await ClockCycles(dut.wb_clk_i, 5)


    # Actually perform read and write to SPI part to test 
    
    # Do a couple writes in a row 

    for i in range (4):
        dut._log.info("Write cycle %d" % (i) )
        await wb_write(dut, wbs, (base_addr + (i*4)), ( 0x0A0B0C0D << i ) )


    await ClockCycles(dut.wb_clk_i, 5)


    for i in range (4):
        dut._log.info("Read cycle %d" % (i) )
        result = await wb_read( wbs, (base_addr + (i*4)) )
        dut._log.info("Read cycle %d returned: %08x" % ( i, result))
        assert( result == (0x0A0B0C0D << i) )
        await ClockCycles(dut.wb_clk_i, 1)

    await ClockCycles(dut.wb_clk_i, 5)

