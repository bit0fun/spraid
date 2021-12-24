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
async def test_raid(dut):

    addr = 0x08001200
    data = 0x1234ABCD
    raid5_data = 0x89EFCDAB
    # Include parity, makes it easier to check 


    clock = Clock(dut.clk, 10, units="us")
    clk_thread = cocotb.start_soon(clock.start())
    
    # Setup signals 
    # Turn off busy signals
    dut.busy_drive0.value = 0
    dut.busy_drive1.value = 0
    dut.busy_drive2.value = 0
    dut.busy_drive3.value = 0
    dut.din.value = 0;

    dut.r_drive_data0.value = 0
    dut.r_drive_data1.value = 0
    dut.r_drive_data2.value = 0
    dut.r_drive_data3.value = 0

    # Reset device before continuing
    await reset(dut)
    dut._log.info("Finished reset")
    
    await ClockCycles(dut.clk, 5)

    assert( dut.op.value == 0 )



    # RAID1    

    # Write test 
    dut._log.info("RAID1 test")
    dut._log.info("RAID1 write")
    dut.raid_type.value = 0 # 0 is RAID1
    dut.write_en.value = 1
    dut.read_en.value = 0
    dut.addr.value = addr
    dut.din.value = data

    # next cycle should be in OP_WRITE
    await ClockCycles(dut.clk, 2)
    assert( dut.op.value == 2 )
    assert( dut.w_drives.value == 1 )
    assert( dut.r_drives.value == 0 )

    # Remove address from input, clear write signal
    dut.addr.value = 0
    dut.write_en.value = 0

    # Stored data in temp value 
    assert( dut.tmp_data.value == data )

    # Make devices busy
    dut.busy_drive0.value = 1
    dut.busy_drive1.value = 1
    dut.busy_drive2.value = 1
    dut.busy_drive3.value = 1

    # Clock data into devices 
    await ClockCycles(dut.clk, 1)

    # Should be in write finish 
    assert( dut.op.value == 3 )

    # Busy signal should be high 
    assert( dut.drive_busy.value == 1 )

    # Turn off busy signals
    dut.busy_drive0.value = 0
    dut.busy_drive1.value = 0
    dut.busy_drive2.value = 0
    dut.busy_drive3.value = 0
    
    # Check that data is all the same 
    assert( dut.w_drive_data0.value == data )
    assert( dut.w_drive_data1.value == data )
    assert( dut.w_drive_data2.value == data )
    assert( dut.w_drive_data3.value == data )

    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.w_drive_data0.value, dut.w_drive_data1.value, dut.w_drive_data2.value, dut.w_drive_data3.value))

    # Write should still be enabled 
    assert( dut.w_drives.value == 1 )
    assert( dut.r_drives.value == 0 )
    
    # Finish up part of test; will require 2 cycles to get back to normal 
    await ClockCycles(dut.clk, 2)

    # Should be back at NOP
    assert( dut.op.value == 0 )

    # make sure all things were cleaned up 
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 0 )
    assert( dut.w_drive_data0.value == 0 )
    assert( dut.w_drive_data1.value == 0 )
    assert( dut.w_drive_data2.value == 0 )
    assert( dut.w_drive_data3.value == 0 )
    assert( dut.tmp_data.value == 0 )
    assert( dut.busy == 0 )

    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.w_drive_data0.value, dut.w_drive_data1.value, dut.w_drive_data2.value, dut.w_drive_data3.value))
    dut._log.info("Finish RAID1 Write Test\n\n")

    await ClockCycles(dut.clk, 5)

    dut.r_drive_data0.value = 0
    dut.r_drive_data1.value = 0
    dut.r_drive_data2.value = 0
    dut.r_drive_data3.value = 0

    # Read test 
    dut._log.info("RAID1 read")
    dut.raid_type.value = 0 # 0 is RAID1
    dut.write_en.value = 0
    dut.read_en.value = 1
    dut.addr.value = addr
    dut.din.value = 0

    # Set busy signal, reads should start on next cycle and this is the only
    # way this testbench could achieve this 
    dut.busy_drive0.value = 1
    dut.busy_drive1.value = 1
    dut.busy_drive2.value = 1
    dut.busy_drive3.value = 1


    # next cycle should be in OP_READ
    await ClockCycles(dut.clk, 2)
    assert( dut.op.value.value == 1 )
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 1 )
    assert( dut.drive_busy.value == 1 )

    # Clear address, and read signal 
    dut.read_en.value = 0
    dut.addr.value = 0
    

    # Put one drive out of busy each cycle
    dut.r_drive_data0.value = data
    dut.busy_drive0.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data1.value = data
    dut.busy_drive1.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data2.value = data
    dut.busy_drive2.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data3.value = data
    dut.busy_drive3.value = 0
    await ClockCycles(dut.clk, 1)

    # Should be done with read, still there but no longer busy 
    assert( dut.drive_busy.value == 0 )
    assert( dut.op.value == 1 )
    assert( dut.r_raid1_eq == 1 )

    dut._log.info("read value")
    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.r_drive_data0.value, dut.r_drive_data1.value, dut.r_drive_data2.value, dut.r_drive_data3.value))

    dut.r_drive_data0.value = 0
    dut.r_drive_data1.value = 0
    dut.r_drive_data2.value = 0
    dut.r_drive_data3.value = 0

    await ClockCycles(dut.clk, 1)
    assert( dut.dout.value == data )
    dut._log.info("Read back data: %08x" %( dut.dout.value ))

    dut._log.info("Finished read test\n\n")

    # Should be back at NOP
    assert( dut.op.value == 0 )

    # make sure all things were cleaned up 
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 0 )
    assert( dut.w_drive_data0.value == 0 )
    assert( dut.w_drive_data1.value == 0 )
    assert( dut.w_drive_data2.value == 0 )
    assert( dut.w_drive_data3.value == 0 )
    assert( dut.tmp_data.value == 0 )
    assert( dut.busy == 0 )

    await ClockCycles(dut.clk, 5)

    # RAID0 test

    # Write test 
    dut._log.info("RAID0 test")
    dut._log.info("RAID0 write")
    dut.raid_type.value = 1 # 0 is RAID1
    dut.write_en.value = 1
    dut.read_en.value = 0
    dut.addr.value = addr
    dut.din.value = data

    # next cycle should be in OP_WRITE
    await ClockCycles(dut.clk, 2)
    assert( dut.op.value == 2 )
    assert( dut.w_drives.value == 1 )
    assert( dut.r_drives.value == 0 )

    # Remove address from input, clear write signal
    dut.addr.value = 0
    dut.write_en.value = 0

    # Stored data in temp value 
    assert( dut.tmp_data.value == data )

    # Make devices busy
    dut.busy_drive0.value = 1
    dut.busy_drive1.value = 1
    dut.busy_drive2.value = 1
    dut.busy_drive3.value = 1

    # Clock data into devices 
    await ClockCycles(dut.clk, 1)

    # Should be in write finish 
    assert( dut.op.value == 3 )

    # Busy signal should be high 
    assert( dut.drive_busy.value == 1 )

    # Turn off busy signals
    dut.busy_drive0.value = 0
    dut.busy_drive1.value = 0
    dut.busy_drive2.value = 0
    dut.busy_drive3.value = 0
    
    # Check that data is striped
    assert( dut.w_drive_data0.value == 0x000000CD )
    assert( dut.w_drive_data1.value == 0x000000AB )
    assert( dut.w_drive_data2.value == 0x00000034 )
    assert( dut.w_drive_data3.value == 0x00000012 )

    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.w_drive_data0.value, dut.w_drive_data1.value, dut.w_drive_data2.value, dut.w_drive_data3.value))

    # Write should still be enabled 
    assert( dut.w_drives.value == 1 )
    assert( dut.r_drives.value == 0 )
    
    # Finish up part of test; will require 2 cycles to get back to normal 
    await ClockCycles(dut.clk, 2)

    # Should be back at NOP
    assert( dut.op.value == 0 )

    # make sure all things were cleaned up 
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 0 )
    assert( dut.w_drive_data0.value == 0 )
    assert( dut.w_drive_data1.value == 0 )
    assert( dut.w_drive_data2.value == 0 )
    assert( dut.w_drive_data3.value == 0 )
    assert( dut.tmp_data.value == 0 )
    assert( dut.busy == 0 )

    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.w_drive_data0.value, dut.w_drive_data1.value, dut.w_drive_data2.value, dut.w_drive_data3.value))
    dut._log.info("Finish RAID0 Write Test\n\n")

    dut.r_drive_data0.value = 0
    dut.r_drive_data1.value = 0
    dut.r_drive_data2.value = 0
    dut.r_drive_data3.value = 0

    await ClockCycles(dut.clk, 5)

    # Read test 
    dut._log.info("RAID0 read")
    dut.raid_type.value = 1 # 1 is RAID0
    dut.write_en.value = 0
    dut.read_en.value = 1
    dut.addr.value = addr
    dut.din.value = 0

    # Set busy signal, reads should start on next cycle and this is the only
    # way this testbench could achieve this 
    dut.busy_drive0.value = 1
    dut.busy_drive1.value = 1
    dut.busy_drive2.value = 1
    dut.busy_drive3.value = 1


    # next cycle should be in OP_READ
    await ClockCycles(dut.clk, 2)
    assert( dut.op.value.value == 1 )
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 1 )
    assert( dut.drive_busy.value == 1 )

    # Clear address, and read signal 
    dut.read_en.value = 0
    dut.addr.value = 0
    

    # Put one drive out of busy each cycle
    dut.r_drive_data0.value = 0xCD
    dut.busy_drive0.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data1.value = 0xAB
    dut.busy_drive1.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data2.value = 0x34
    dut.busy_drive2.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data3.value = 0x12
    dut.busy_drive3.value = 0
    await ClockCycles(dut.clk, 1)

    # Should be done with read, still there but no longer busy 
    assert( dut.drive_busy.value == 0 )
    assert( dut.op.value == 1 )

    dut._log.info("read value")
    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.r_drive_data0.value, dut.r_drive_data1.value, dut.r_drive_data2.value, dut.r_drive_data3.value))

    dut.r_drive_data0.value = 0
    dut.r_drive_data1.value = 0
    dut.r_drive_data2.value = 0
    dut.r_drive_data3.value = 0

    await ClockCycles(dut.clk, 1)
    dut._log.info("Read back data: %08x" %( dut.dout.value ))
    assert( dut.dout.value == data )

    # Should be back at NOP
    assert( dut.op.value == 0 )

    # make sure all things were cleaned up 
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 0 )
    assert( dut.w_drive_data0.value == 0 )
    assert( dut.w_drive_data1.value == 0 )
    assert( dut.w_drive_data2.value == 0 )
    assert( dut.w_drive_data3.value == 0 )
    assert( dut.tmp_data.value == 0 )
    assert( dut.busy == 0 )

    dut._log.info("Finished read test\n\n")



    # RAID5 test 

    # Write test 
    dut._log.info("RAID5 test")
    dut._log.info("RAID5 write")
    dut.raid_type.value = 5 # 5 is RAID5
    dut.write_en.value = 1
    dut.read_en.value = 0
    dut.addr.value = addr
    dut.din.value = raid5_data

    # next cycle should be in OP_WRITE
    await ClockCycles(dut.clk, 2)
    assert( dut.op.value == 2 )
    assert( dut.w_drives.value == 1 )
    assert( dut.r_drives.value == 0 )

    # Remove address from input, clear write signal
    dut.addr.value = 0
    dut.write_en.value = 0

    # Stored data in temp value 
    assert( dut.tmp_data.value == raid5_data )

    # Make devices busy
    dut.busy_drive0.value = 1
    dut.busy_drive1.value = 1
    dut.busy_drive2.value = 1
    dut.busy_drive3.value = 1

    # Clock data into devices 
    await ClockCycles(dut.clk, 1)

    # Should be in write finish 
    assert( dut.op.value == 3 )

    # Busy signal should be high 
    assert( dut.drive_busy.value == 1 )

    # Turn off busy signals
    dut.busy_drive0.value = 0
    dut.busy_drive1.value = 0
    dut.busy_drive2.value = 0
    dut.busy_drive3.value = 0
    
    # Check that data is striped
    assert( dut.w_drive_data0.value == 0x000000AB )
    assert( dut.w_drive_data1.value == 0x000000CD )
    assert( dut.w_drive_data2.value == 0x000000EF )
    assert( dut.w_drive_data3.value == 0x00000089 )

    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.w_drive_data0.value, dut.w_drive_data1.value, dut.w_drive_data2.value, dut.w_drive_data3.value))

    # Write should still be enabled 
    assert( dut.w_drives.value == 1 )
    assert( dut.r_drives.value == 0 )
    
    # Finish up part of test; will require 2 cycles to get back to normal 
    await ClockCycles(dut.clk, 2)

    # Should be back at NOP
    assert( dut.op.value == 0 )

    # make sure all things were cleaned up 
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 0 )
    assert( dut.w_drive_data0.value == 0 )
    assert( dut.w_drive_data1.value == 0 )
    assert( dut.w_drive_data2.value == 0 )
    assert( dut.w_drive_data3.value == 0 )
    assert( dut.tmp_data.value == 0 )
    assert( dut.busy == 0 )

    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.w_drive_data0.value, dut.w_drive_data1.value, dut.w_drive_data2.value, dut.w_drive_data3.value))
    dut._log.info("Finish RAID 1 Write Test\n\n")

    dut.r_drive_data0.value = 0
    dut.r_drive_data1.value = 0
    dut.r_drive_data2.value = 0
    dut.r_drive_data3.value = 0

    await ClockCycles(dut.clk, 5)

    # Read test 
    dut._log.info("RAID5 read")
    dut.raid_type.value = 1 # 1 is RAID0
    dut.write_en.value = 0
    dut.read_en.value = 1
    dut.addr.value = addr
    dut.din.value = 0

    # Set busy signal, reads should start on next cycle and this is the only
    # way this testbench could achieve this 
    dut.busy_drive0.value = 1
    dut.busy_drive1.value = 1
    dut.busy_drive2.value = 1
    dut.busy_drive3.value = 1


    # next cycle should be in OP_READ
    await ClockCycles(dut.clk, 2)
    assert( dut.op.value.value == 1 )
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 1 )
    assert( dut.drive_busy.value == 1 )

    # Clear address, and read signal 
    dut.read_en.value = 0
    dut.addr.value = 0
    

    # Put one drive out of busy each cycle
    dut.r_drive_data0.value = 0xAB
    dut.busy_drive0.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data1.value = 0xCD
    dut.busy_drive1.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data2.value = 0xEF
    dut.busy_drive2.value = 0
    await ClockCycles(dut.clk, 1)

    # Check that still in read, and waiting for busy 
    assert( dut.drive_busy.value == 1 )
    assert( dut.op.value == 1 )

    dut.r_drive_data3.value = 0x89
    dut.busy_drive3.value = 0
    await ClockCycles(dut.clk, 1)

    # Should be done with read, still there but no longer busy 
    assert( dut.drive_busy.value == 0 )
    assert( dut.op.value == 1 )

    # Should not have parity issue, check 
    assert( dut.parity.value == 0 )

    dut._log.info("read value")
    dut._log.info("Drive 0: %08x\tDrive 1: %08x\tDrive 2: %08x\tDrive 3: %08x\t" %(dut.r_drive_data0.value, dut.r_drive_data1.value, dut.r_drive_data2.value, dut.r_drive_data3.value))

    await ClockCycles(dut.clk, 1)
    assert( dut.dout.value == raid5_data )
    dut._log.info("Read back data: %08x" %( dut.dout.value ))

    # Should be back at NOP
    assert( dut.op.value == 0 )

    # make sure all things were cleaned up 
    assert( dut.w_drives.value == 0 )
    assert( dut.r_drives.value == 0 )
    assert( dut.w_drive_data0.value == 0 )
    assert( dut.w_drive_data1.value == 0 )
    assert( dut.w_drive_data2.value == 0 )
    assert( dut.w_drive_data3.value == 0 )
    assert( dut.tmp_data.value == 0 )
    assert( dut.busy == 0 )

    dut._log.info("Finished read test\n\n")




