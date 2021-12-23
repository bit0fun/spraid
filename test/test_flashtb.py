import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random
from array import *


# Writing data 
async def spi_write( dut, data, dlen ):
    # Setup signals 
    dut.write.value = 1
    dut.read.value = 0
    for i in range(dlen):
        dut._log.info("Current write cycle: %d\t%02x" % (i, data[i]))
        dut.din.value = data[i]
        if( i == 0 ):
            # CS should not go low until next clock cycle 
            assert(dut.spi_cs.value == 1)
        else:
            # CS should still be low
            assert(dut.spi_cs.value == 0)

        # OP should still be NOP
        assert(dut.spi0.op.value == 0)

        # Wait for busy to start 
        while( dut.busy.value == 0 ):
            await ClockCycles(dut.clk, 1)

#        dut.write.value = 0
#        dut.din.value = 0

        # wait until not busy 
        while( (dut.busy.value == 1) and (dut.spi0.op.value == 2) ):
            # should be in OP_WRITE mode 
            assert( dut.spi0.op.value == 2 )
            # CS should be selected 
            assert(dut.spi_cs.value == 0)
            dut._log.info("Current data: %01x\t current bit: %01x" % (data[i], dut.spi_mosi.value))
            await ClockCycles(dut.clk, 1)
            # check if done writing
            if( i == (dlen - 1) ):
                dut.write.value = 0;

        # No longer busy 

        # Should mean that we are in OP_WAIT_CS
        assert( dut.spi0.op.value == 4 )

        # CS should still be selected 
        assert( dut.spi_cs.value == 0 )

        # Wait a cycle 
        await ClockCycles(dut.clk, 2)

    # CS should no longer be selected 
    assert( dut.spi_cs.value == 1 )


# Writing for read command
async def spi_write4read(dut, data, dlen):
    # Setup signals 
    dut.write.value = 1
    dut.read.value = 1
    for i in range(dlen):
        dut._log.info("Current write cycle: %d" % (i))
        dut.din.value = data[i]

        if( i == 0 ):
            # CS should not go low until next clock cycle 
            assert(dut.spi_cs.value == 1)
        else:
            # CS should still be low
            assert(dut.spi_cs.value == 0)

        # OP should still be NOP
        assert(dut.spi0.op.value == 0)

        # Wait for busy to start 
        while( dut.busy.value == 0 ):
            await ClockCycles(dut.clk, 1)

        #dut.write.value = 0
#        dut.din.value = 0

        # wait until not busy 
        while( (dut.busy.value == 1) and (dut.spi0.op.value == 2) ):
            # should be in OP_WRITE mode 
            assert( dut.spi0.op.value == 2 )
            # CS should be selected 
            assert(dut.spi_cs.value == 0)
            dut._log.info("Current data: %01x\t current bit: %01x" % (data[i], dut.spi_mosi.value))
            await ClockCycles(dut.clk, 1)

        # No longer busy 

        # Should mean that we are in OP_WAIT_CS
        assert( dut.spi0.op.value == 4 )

        # CS should still be selected 
        assert( dut.spi_cs.value == 0 )

        # Wait a cycle 
        await ClockCycles(dut.clk, 1)


# Write then read operation; more generic than just read
async def spi_read(dut, data, wlen, rlen):
    read_data = [];
    # First write data to the flash
    await spi_write4read( dut, data, wlen )

    # Setup signals
    dut.write.value = 0
    dut.read.value = 1
    dut.din.value = 0;

    for i in range(rlen):
        # CS should still be low
        assert(dut.spi_cs.value == 0)

        # OP should still be NOP
        assert(dut.spi0.op.value == 0)

        # Wait for busy to start 
        while( dut.busy.value == 0 ):
            await ClockCycles(dut.clk, 1)

        dut.write.value = 0

        # wait until not busy 
        while( (dut.busy.value == 1) and (dut.spi0.op.value == 1) ):
            # should be in OP_READ mode 
            assert( dut.spi0.op.value == 1 )
            # CS should be selected 
            assert(dut.spi_cs.value == 0)
            await ClockCycles(dut.clk, 1)
            # check if done writing
            if( i == (rlen - 1) ):
                dut.read.value = 0;

        # No longer busy 

        # Should mean that we are in OP_WAIT_CS
        assert( dut.spi0.op.value == 4 )

        # Store data that was read read
        read_data[i] = dut.dout.value


        # CS should still be selected 
        assert( dut.spi_cs.value == 0 )

        # Wait a cycle 
        await ClockCycles(dut.clk, 1)
        dut._log.info("read_data[%d]: %02x" % (i, read_data[i] ))

    # CS should no longer be selected 
    assert( dut.spi_cs.value == 1 )
    return read_data



# Flash command send
async def flash_chip_erase(dut):
    erase_cmd = [0x60]
    await spi_write(dut, erase_cmd, 1)


# Flash write enable
async def flash_write_enable(dut):
    wen_cmd = [0x06]
    await spi_write(dut, wen_cmd, 1)

# Flash write disable
async def flash_write_disable(dut):
    wdis_cmd = [0x04]
    await spi_write(dut, wdis_cmd, 1)
    

# Read status register
async def flash_read_stat1_reg(dut):
    stat1_cmd = [0x05]
    return await spi_read(dut, stat1_cmd, 1, 2)


# Read status 2 register
async def flash_read_stat2_reg(dut):
    stat2_cmd = [0x35]
    return await spi_read(dut, stat2_cmd, 1, 2)


# Read data
async def flash_read_data(dut, addr, nbytes):
    read_cmd = [0x03] + addr
    return await spi_read(dut, read_cmd, 4, nbytes)


# (Write) page program
async def flash_page_program(dut, addr, data, nbytes):
    write_cmd = [0x02] + addr + data
    await spi_write( dut, write_cmd, (4 + nbytes) )


# Sector erase
async def flash_sector_erase(dut, addr):
    sec_erase_cmd = [0x20] + addr
    await spi_write( dut, sec_erase_cmd, 4)


async def reset(dut):
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_flashtb(dut):

    # Address to read and write to
    test_addr = [ 0x03, 0xAA, 0x10 ]

    # 8 elements to transmit 
    example_data = [ 0xAA, 0x55, 0x00, 0xFF, 0x10, 0x0F, 0xF0, 0x81 ]

#    read_data = [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ]

    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())

    # Set default signal state 
    dut.write.value = 0;
    dut.read.value = 0;
    dut.din.value = 0;

    # Reset device before continuing
    await reset(dut)

    # Wait for power on 800us
    await Timer(800, units='us')

    # Perform chiperase
    dut._log.info("Write enable")
    await flash_write_enable(dut)
    await ClockCycles(dut.clk, 4)

    dut._log.info("Erasing flash") 
    await flash_chip_erase(dut)
    # Wait till complete... should use busy signal from flash but whatever
#    await ClockCycles(dut.clk, 10000)
    dut._log.info("Finished erase cmd send")    
    while( (dut.flash.Status_Reg.value & 0x0001) == 0x0001 ):
        await ClockCycles(dut.clk, 1)

    dut._log.info("Write enable")
    await flash_write_enable(dut)
    await ClockCycles(dut.clk, 4)
    dut._log.info("Starting write") 
    # Write to device
    await flash_page_program(dut, test_addr, example_data, 8)
    # Wait till complete... should use busy signal from flash but whatever
#    await ClockCycles(dut.clk, 1000)
    dut._log.info("Finished write cmd send")    
    while( (dut.flash.Status_Reg.value & 0x0001) == 0x0001 ):
        await ClockCycles(dut.clk, 1)

    # Read from device
#    dut._log.info("Starting read") 
#    read_data = await flash_read_data( dut, test_addr, 8)
    
    dut._log.info("Finish!") 

