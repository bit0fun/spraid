import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random
from array import *

async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_spi32(dut):

    data = 0x1234ABCD
    # Command = 0x03, address is 0x01AA, last byte is used for reading 
    read_cmd_test = 0x0301AA00

    # Start clock 
    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    # Initialize input values 
    dut.din.value = 0
    dut.sdi.value = 0
    dut.read.value = 0
    dut.write.value = 0

    # Reset device before continuing
    await reset(dut)

    # Write test
    dut._log.info("SPI32 Write test")

    # Check initial values are proper 
    assert( dut.cs.value == 1 )
    assert( dut.sdo.value == 0 )
    assert( dut.busy.value == 0 )
#    assert( dut.dout.value == 0 )
    assert( dut.spi_state.value == 0 ) 

    # Write data to write shift register 
    dut.din.value = data
    dut.write.value = 1
    dut.read.value = 0

    await ClockCycles(dut.clk, 2)

    dut.din.value = 0
    dut.write.value = 0
    dut.read.value = 0

    # Should now be in SPI_WRITE_FIFO state 
    assert(dut.spi_state.value == 1)
    assert(dut.busy.value == 1)
    
    # Wait until fifo is no longer empty, data should be shifted in
    dut._log.info("Waiting for fifo to be empty")
    while( dut.write_fifo_empty.value ):
        await ClockCycles(dut.clk, 1)

    # Wait for all data to be shifted in to the fifo
    dut._log.info("Waiting for fifo to be full")
    while( dut.write_fifo_full.value == 0 ):
        assert( dut.spi_state.value == 1 )
        await ClockCycles(dut.clk, 1)

    # Write fifo is full, should transition to writing out data next
    assert( dut.spi_state.value == 1)
    await ClockCycles(dut.clk, 1)

    assert( dut.spi_state.value == 2 )

    assert( dut.write_fifo_spi_en.value == 1 )


    # Wait until byte is written on spi 
    for i in range(5):
        dut._log.info("Waiting for tx ready cycle %d" % (i))
        while( dut.spi_tx_ready.value == 0 ):
            await ClockCycles(dut.clk, 1)
        if( i < 4 ):
            dut._log.info("Waiting for tx not ready cycle %d" % (i))
            while( dut.spi_tx_ready.value == 1 ):
                await ClockCycles(dut.clk, 1)

    # need a couple more clock cycles to get to cs high again 
    while( dut.busy.value == 1):
        await ClockCycles( dut.clk, 1 )

    assert( dut.spi_state.value == 0)
    assert( dut.cs.value == 1 )


    assert( dut.write_fifo_spi_en.value == 0 )

    await ClockCycles( dut.clk, 10 )

    # Read test
    dut._log.info("SPI32 Read test")

    # Check initial values are proper 
    assert( dut.cs.value == 1 )
    #assert( dut.sdo.value == 0 )
    assert( dut.busy.value == 0 )
#    assert( dut.dout.value == 0 )
    assert( dut.spi_state.value == 0 ) 

    # Write data to write shift register 
    dut.din.value = read_cmd_test
    dut.write.value = 0
    dut.read.value = 1

    await ClockCycles(dut.clk, 2)

    dut.din.value = 0
    dut.write.value = 0
    dut.read.value = 0

    # set din value just to make it easier for later 
    dut.sdi.value = 1

    # Should now be in SPI_WRITE_FIFO state 
    assert(dut.spi_state.value == 1)
    assert(dut.busy.value == 1)
    
    # Wait until fifo is no longer empty, data should be shifted in
    dut._log.info("Waiting for fifo to be empty")
    while( dut.write_fifo_empty.value ):
        await ClockCycles(dut.clk, 1)

    # Wait for all data to be shifted in to the fifo
    dut._log.info("Waiting for fifo to be full")
    while( dut.write_fifo_full.value == 0 ):
        assert( dut.spi_state.value == 1 )
        await ClockCycles(dut.clk, 1)

    # Write fifo is full, should transition to writing out data next
    assert( dut.spi_state.value == 1)
    await ClockCycles(dut.clk, 1)

    assert( dut.spi_state.value == 2 )

    assert( dut.write_fifo_spi_en.value == 1 )


    # Wait until byte is written on spi 
    for i in range(5):
        dut._log.info("Waiting for tx ready cycle %d" % (i))
        while( dut.spi_tx_ready.value == 0 ):
            await ClockCycles(dut.clk, 1)
        if( i < 4 ):
            dut._log.info("Waiting for tx not ready cycle %d" % (i))
            while( dut.spi_tx_ready.value == 1 ):
                await ClockCycles(dut.clk, 1)

    # need a couple more clock cycles to get to cs high again 
    while( dut.busy.value == 1):
        await ClockCycles( dut.clk, 1 )

    assert( dut.spi_state.value == 0)
    assert( dut.cs.value == 1 )


    assert( dut.write_fifo_spi_en.value == 0 )






