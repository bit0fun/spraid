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
async def test_raid0_write(dut):
    addr = 0x80001000
    data = 0x1234ABCD


    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())
    
    # Reset device before continuing
    await reset(dut)
    
    dut._log.info("Finished reset")

    # Write data over
    dut.enable.value = 1 #set enable high 
    dut.host_data.value = data
    dut.host_addr.value = addr

    dut._log.info("Finished reset")

    # Wait until data is present, then set busy 
    while( dut.busy.value == 0):
        await ClockCycles(dut.clk, 1)
    
    # Can release forced values 
    dut.enable.value = 0
    dut.host_data.value = 0
    dut.host_addr.value = 0

    # Devices are busy for a couple clock cycles
    dut.device_busy.value = 0x0f
    await ClockCycles(dut.clk, 5)
    assert dut.busy.value == 1
    assert dut.state.value == 3

    dut._log.info("Data for each device")
    for i in range(4):
        dut._log.info( "Device[ %d ]: addr = %08x \tdata = %02x" % (i, dut.device_addr.value, (dut.device_data.value & (0xff << i*8))>>(i*8)) )
    assert dut.device_addr == addr

    # Set device busy to low
    dut.device_busy.value = 0
    await ClockCycles(dut.clk, 2)

    # Check that outputs are back to zero 
    dut._log.info("After completing")
    for i in range(4):
        dut._log.info( "Device[ %d ]: addr = %08x \tdata = %02x" % (i, dut.device_addr.value, (dut.device_data.value & (0xff << i*8))>>(i*8)) )

    assert dut.device_data.value == 0

    clk_thread.kill()
