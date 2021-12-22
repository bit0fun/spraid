import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random
from array import *

async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk_in, 5)
    dut.reset.value = 0
    await ClockCycles(dut.clk_in, 5)

@cocotb.test()
async def test_spi(dut):

    # 8 elements to transmit 
    example_data = [ 0xAA, 0x55, 0x00, 0xFF, 0x10, 0x0F, 0xF0, 0x81 ]

    # Serialized bits to read back, with buffer 
    bit_data = [
        #0xAA
       [ 1, 0, 1, 0,      1, 0, 1, 0 ],
        #0x55
       [ 0, 1, 0, 1,      0, 1, 0, 1 ],
        #0x00
       [ 0, 0, 0, 0,      0, 0, 0, 0 ],
        #0xFF
       [ 1, 1, 1, 1,      1, 1, 1, 1 ],
        #0x10
       [ 1, 0, 0, 0,      0, 0, 0, 0 ],
        #0x0F
       [ 0, 0, 0, 0,      1, 1, 1, 1 ],
        #0xF0
       [ 1, 1, 1, 1,      0, 0, 0, 0 ],
        #0x00 needed for getting all data
       [ 0, 0, 0, 0,      0, 0, 0, 0 ],
        # 0x08
       [ 1, 0, 0, 0,      0, 0, 0, 1 ]

    ]

    read_data = [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ]

    clock = Clock(dut.clk_in, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    # Set default signal state 
    dut.sdi.value = 0
    dut.write.value = 0;
    dut.read.value = 0;
    dut.din.value = 0;

    # Reset device before continuing
    await reset(dut)

    # Write test
    dut._log.info("Write test start") 
    # setup signals 
    for byte in example_data:
        # Setup signals 
        dut.write.value = 1
        dut.read.value = 0
        dut.din.value = byte
        
        # CS should not go low until next clock cycle 
        assert(dut.cs.value == 1)

        # OP should still be NOP
        assert(dut.op.value == 0)

        # Wait for busy to start 
        while( dut.busy.value == 0 ):
            await ClockCycles(dut.clk_in, 1)

        dut.write.value = 0
        dut.din.value = 0

        # wait until not busy 
        while( (dut.busy.value == 1) and (dut.op.value == 2) ):
            # should be in OP_WRITE mode 
            assert( dut.op.value == 2 )
            # CS should be selected 
            assert(dut.cs.value == 0)
            dut._log.info("Current data: %01x\t current bit: %01x" % (byte, dut.sdo.value))
            await ClockCycles(dut.clk_in, 1)

        # No longer busy 

        # Should mean that we are in OP_WAIT_CS
        assert( dut.op.value == 4 )

        # CS should still be selected 
        assert( dut.cs.value == 0 )

        # Wait a cycle 
        await ClockCycles(dut.clk_in, 1)

        # CS should no longer be selected 
        assert( dut.cs.value == 1 )

    dut._log.info("Write test end\n\n") 
    # Read test
    # setup signals 
    dut._log.info("Read test start") 
    await ClockCycles(dut.clk_in, 5)
    for i in range(len(read_data)):
        # Setup signals 
        dut.write.value = 0
        dut.read.value = 1
#        dut.din.value = byte
        
        # CS should not go low until next clock cycle 
        assert(dut.cs.value == 1)

        # OP should still be NOP
        assert(dut.op.value == 0)

        # Wait for busy to start 
        while( dut.busy.value == 0 ):
#            await FallingEdge(dut.clk_in)
            await ClockCycles(dut.clk_in, 1)

        dut.read.value = 0
        for j in bit_data[i]:
            dut.sdi.value = j
            assert( dut.busy.value == 1 )
            assert( dut.op.value == 1 )
            assert( dut.cs.value == 0 )
#            await ClockCycles(dut.clk_in, 1)
            await RisingEdge(dut.clk_in)



        # No longer busy 
        while( dut.busy.value == 1 ):
            await FallingEdge(dut.clk_in)

        # Should mean that we are in OP_WAIT_CS
#        assert( dut.op.value == 5 )

        # CS should still be selected 
#        assert( dut.cs.value == 0 )

        while( dut.busy.value == 1):
            await ClockCycles(dut.clk_in, 1)



        # Wait a cycle 
        await ClockCycles(dut.clk_in, 1)

        read_data[i] = dut.dout.value;

        # CS should no longer be selected 
        assert( dut.cs.value == 1 )

        dut._log.info("read_data[%d]: %02x" % (i, read_data[i] ))

    # Check the data that was read back 
    for index in range(len(read_data)):
        assert( read_data[index + 1] == example_data[index] )
    
    dut._log.info("Read test end\n\n") 


    # Read write test 
