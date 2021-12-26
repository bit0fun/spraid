import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random
from array import *

async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_flash_ctl(dut):

    # State definitions 
    state_idle = 0
    state_write_enable = 1
    state_write_bubble = 2
    state_write = 3
    state_read = 4

    addr = 0x01AA
    write_data = 0x55 

    # Start clock 
    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    # Initialize input values 
    dut.read.value = 0
    dut.write.value = 0
    dut.addr.value = 0
    dut.din.value = 0
    dut.spi_miso.value = 0

    # Reset device before continuing
    await reset(dut)

    # Need to wait at least 1ms before accessing the FRAM
#    await Timer(1, units='ms')

    # Test write 
    dut._log.info("\nWrite Test\n")

    # Setup data to write 
    dut.write.value = 1
    dut.read.value = 0
    dut.addr.value = addr
    dut.din.value = write_data

    # Clock in data 
    await ClockCycles(dut.clk, 1)

    # Clear data
    dut.read.value = 0
    dut.write.value = 0
    dut.addr.value = 0
    dut.din.value = 0
    dut.spi_miso.value = 0

    await ClockCycles(dut.clk, 1)

    # Should go into write enable command
    assert( dut.flash_state.value == state_write_enable )
    assert( dut.spi_write.value == 1 )
    assert( dut.spi_read.value == 0 )
    assert( dut.cmd.value == 0x06000000 ) # need big endian for single byte 
  #  assert( dut.cmd_sz.value == 1 )
    assert( dut.busy.value == 1 )

    await ClockCycles(dut.clk, 1)
    dut._log.info("Command being sent: %08x" %  ( dut.cmd.value ))

    assert( dut.spi_busy.value == 1)

    # Wait for SPI to finish 
    while( dut.spi_busy.value == 1 ):
#        assert( dut.spi_write.value == 0 )
        await ClockCycles(dut.clk, 1)

    assert( dut.spi_busy.value == 0 )

    await ClockCycles(dut.clk, 1)

    # Now to actually write data out 
    assert( dut.flash_state.value == state_write )
    assert( dut.spi_write.value == 1 )
    assert( dut.spi_read.value == 0 )
    assert( dut.cmd.value == 0x0201AA55 )
    assert( dut.cmd_sz.value == 3 )
    assert( dut.busy.value == 1 )
    
    dut._log.info("Command being sent: %08x" %  ( dut.cmd.value ))

    await ClockCycles(dut.clk, 1)
    assert( dut.spi_busy.value == 1)


    # Wait for SPI to finish 
    while( dut.spi_busy.value == 1 ):
#        assert( dut.spi_write.value == 0 )
        await ClockCycles(dut.clk, 1)

    assert( dut.spi_busy.value == 0 )

    # Make sure back at idle 
    assert( dut.flash_state.value == state_idle )
    assert( dut.cmd.value == 0 )

    await ClockCycles(dut.clk, 10) 


    # Test read 
    dut._log.info("\nRead Test\n")
    # Setup for reading
    dut.write.value = 0
    dut.read.value = 1
    dut.addr.value = addr
    dut.din.value = 0

    # Clock in data 
    await ClockCycles(dut.clk, 1)

    # Clear data
    dut.read.value = 0
    dut.write.value = 0
    dut.addr.value = 0
    dut.din.value = 0
    dut.spi_miso.value = 1

    await ClockCycles(dut.clk, 1)

    # Should go into write enable command
    assert( dut.flash_state.value == state_read )
    assert( dut.spi_write.value == 0 )
    assert( dut.spi_read.value == 1 )
    assert( dut.cmd.value == 0x0301AA00 )  
  #  assert( dut.cmd_sz.value == 1 )
    assert( dut.busy.value == 1 )

    await ClockCycles(dut.clk, 1)
    dut._log.info("Command being sent: %08x" %  ( dut.cmd.value ))

    assert( dut.spi_busy.value == 1)

    # Wait for SPI to finish 
    while( dut.spi_busy.value == 1 ):
#        assert( dut.spi_write.value == 0 )
        await ClockCycles(dut.clk, 1)

    assert( dut.spi_busy.value == 0 )

    await ClockCycles(dut.clk, 1)


    dut._log.info("Command being sent: %08x" %  ( dut.dout.value ))
    assert( dut.dout.value == 0xff)



