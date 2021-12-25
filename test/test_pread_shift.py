import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random

async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 5)


@cocotb.test()
async def test_pread_shift(dut):

    data = 0x1234ABCD

    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    dut.din.value = 0
    dut.enable.value = 0

    # Reset device before continuing
    await reset(dut)
    dut._log.info("Finished reset")
    
    await ClockCycles(dut.clk, 5)
    dut._log.info("data[0]: %02x\tdata[1]: %02x\tdata[2]: %02x\tdata[3]: %02x" % (dut.data[0].value, dut.data[1].value, dut.data[2].value, dut.data[3].value))

    # write data one clock cycle at a time 
    dut.din.value = 0x12
    dut.enable.value = 1
    await ClockCycles(dut.clk, 1)
    dut._log.info("data[0]: %02x\tdata[1]: %02x\tdata[2]: %02x\tdata[3]: %02x" % (dut.data[0].value, dut.data[1].value, dut.data[2].value, dut.data[3].value))

    assert( dut.dcount.value == 3 )

    dut.din.value = 0x34
    dut.enable.value = 0
    await ClockCycles(dut.clk, 1)

    dut._log.info("data[0]: %02x\tdata[1]: %02x\tdata[2]: %02x\tdata[3]: %02x" % (dut.data[0].value, dut.data[1].value, dut.data[2].value, dut.data[3].value))

    assert( dut.busy.value == 1 )
    assert( dut.dcount.value == 3 )

    dut.din.value = 0xAB
    await ClockCycles(dut.clk, 1)

    dut._log.info("data[0]: %02x\tdata[1]: %02x\tdata[2]: %02x\tdata[3]: %02x" % (dut.data[0].value, dut.data[1].value, dut.data[2].value, dut.data[3].value))

    assert( dut.busy.value == 1 )
    assert( dut.dcount.value == 2 )

    dut.din.value = 0xCD
    await ClockCycles(dut.clk, 1)

    assert( dut.busy.value == 1 )
    assert( dut.dcount.value == 1 )

    dut.din.value = 0x00
    await ClockCycles(dut.clk, 1)

    assert( dut.busy.value == 1 )
    assert( dut.dcount.value == 0 )
    

 #       if( dut.dcount != 0 ):

        # ensure enable is put low, to not have it go into an infinite loop
#        dut.enable.value = 0

    dut._log.info("data[0]: %02x\tdata[1]: %02x\tdata[2]: %02x\tdata[3]: %02x" % (dut.data[0].value, dut.data[1].value, dut.data[2].value, dut.data[3].value))
    #    dut._log.info("dout: %02x" % (dut.dout.value))
    await ClockCycles(dut.clk, 1)   

    assert( dut.dcount.value == 0 )

    assert( dut.busy.value == 0 )
    assert( dut.dout.value == data )
