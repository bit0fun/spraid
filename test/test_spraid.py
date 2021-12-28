import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random
from array import *

async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 20)

@cocotb.test()
async def test_spraid(dut):

    # Raid type definitions
    raid0 = 1
    raid1 = 0
    raid5 = 5

    # Test data 
    write_data = 0x1234ABCD
    addr = 0x000001AA
    raid_type = raid0

    # Start clock 
    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    # Initialize input values 
    dut.read.value = 0
    dut.write.value = 0
    dut.addr.value = 0
    dut.din.value = 0
    dut.spi0_miso.value = 0
    dut.spi1_miso.value = 0
    dut.spi2_miso.value = 0
    dut.spi3_miso.value = 0
    dut.raid_type.value = 0

    # Reset device before continuing
    await reset(dut)

    # Need to wait at least 1ms before accessing the FRAM
#    await Timer(1, units='ms')

    # Test RAID0 Write
    dut._log.info("\nRAID0 Write Test\n")

    dut.write.value = 1
    dut.read.value = 0
    dut.addr.value = addr
    dut.din.value = write_data
    dut.raid_type.value = raid0

    # next cycle should be in OP_WRITE
    await ClockCycles(dut.clk, 2)
    assert( dut.raid_module.op.value == 2 )
    await ClockCycles(dut.clk, 1)
    assert( dut.spi_write.value == 1 )
    assert( dut.spi_read.value == 0 )

    # Remove address from input, clear write signal
    dut.addr.value = 0
    dut.write.value = 0
    dut.din.value = 0

    # Stored data in temp value 
    assert( dut.raid_module.tmp_data.value == write_data )

    # Should be in write finish 
    assert( dut.raid_module.op.value == 3 )

    # Check that data is striped
    assert( dut.spi0_din.value == 0x000000CD )
    assert( dut.spi1_din.value == 0x000000AB )
    assert( dut.spi2_din.value == 0x00000034 )
    assert( dut.spi3_din.value == 0x00000012 )
    
    # Clock data into devices 
    await ClockCycles(dut.clk, 2)

    # Make sure devices are now busy 
    assert( dut.spi0_busy.value == 1)
    assert( dut.spi1_busy.value == 1)
    assert( dut.spi2_busy.value == 1)
    assert( dut.spi3_busy.value == 1)


    # Wait for not busy, finish writes 
    while( dut.busy.value == 1 or dut.spi0_busy.value == 1):
        await ClockCycles(dut.clk, 1)

    # Should always be true, but better to check than not
    assert( dut.busy.value == 0 )

    # Should be back at NOP
    assert( dut.raid_module.op.value == 0 )

    await ClockCycles(dut.clk, 1)


    # Test reads 
    dut._log.info("\nRAID0 Read Test\n")

    dut.write.value = 0
    dut.read.value = 1
    dut.addr.value = addr
    dut.din.value = 0
    dut.raid_type.value = raid0
    dut.spi0_miso.value = 1
    dut.spi1_miso.value = 0
    dut.spi2_miso.value = 1
    dut.spi3_miso.value = 0

    # next cycle should be in OP_READ
    await ClockCycles(dut.clk, 1)
    # Remove address from input, clear write signal
    dut.spi_addr.value = 0
    dut.read.value = 0
    await ClockCycles(dut.clk, 1)
    assert( dut.raid_module.op.value == 4 ) # read wait 
    await ClockCycles(dut.clk, 1)
    assert( dut.spi_write.value == 0 )
    assert( dut.spi_read.value == 1 )



    # wait for busy
    while( dut.busy.value == 0 ):
        await ClockCycles(dut.clk, 1)

    # Wait for not busy, finish writes 
    while( dut.busy.value == 1 or dut.spi0_busy.value == 1):
        await ClockCycles(dut.clk, 1)

    # Should always be true, but better to check than not
    assert( dut.busy.value == 0 )

    await ClockCycles(dut.clk, 1)

    dut._log.info("Read back data: %08x" %( dut.dout.value ))
    await ClockCycles(dut.clk, 10)
