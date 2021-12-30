import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, First, Timer, Event, ClockCycles
from collections import deque
from cocotbext.spi import SpiSlaveBase, SpiFrameError, SpiSignals, SpiConfig

class FM25C160B(SpiSlaveBase):
    # Only 2KB, 16Kbit, 8 byte addressable
    memsize = 2048

    def __init__(self, signals, spimode, dut):

        # Memory of device in 8 bit chunks
        self.mem = [0xFF] * FM25C160B.memsize
        self._out_queue = deque()
        self._out_queue.append(0)

        self.dut = dut

        # Internal Registers
        self.status = 0x00
        self.wp = 0x00

        if( spimode == 0 ):
            self._config = SpiConfig(
                word_width = 32,
                cpol = False,
                cpha = False,
                msb_first = True,
                frame_spacing_ns = 10
            )
        elif( spimode == 3 ):
            self._config = SpiConfig(
                word_width = 32,
                cpol = True,
                cpha = True,
                msb_first = True,
                frame_spacing_ns = 10
            )
        else:
            raise ValueError('FM25C160B Only supports spi modes 0 and 3, not %d' %(spimode))

        self.dut._log.info("Initialized FM25C160B")
        super().__init__(signals)


    async def get_mem(self, addr):
        await self.idle.wait()
        # Check if address is ok
        if( addr >= FM25C160B.memsize ):
            raise ValueError('FM25C160B: Write Address %04x is too large for memory size of %04x' %( addr, FM25C160B.memsize))

        return self.mem[addr]


    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()


        # Determine the incoming command
        cmd = int(await self._shift(7) )
        
        match cmd:
            # Write Status Register 
            case ( 0x01 ):
                self.dut._log.info("FM25C160B: Write Status Register command found")
                val = int(await self._shift(8))
                # Write to status register with mask
                self.status = self.status & ~(0x8C)
                self.status = (val & 0x8C) | self.status # 1000 1100
                await frame_end

            # Write Command
            case ( 0x02 ):
                # Check if WEL is set
                self.dut._log.info("FM25C160B: Write command found")
                if( (self.status & (1<<1)) != (1<<1)):
                    raise SpiFrameError('FM25C160B: Write enable latch was not set during this write cycle. Current status: %02x' %(self.status))

                else:
                    # Write is proper, can continue
                    addr = int( await self._shift(16) )

                    # Check if address is ok
                    if( addr >= FM25C160B.memsize ):
                        raise ValueError('FM25C160B: Write Address %04x is too large for memory size of %04x' %( addr, FM25C160B.memsize))

                    # Address is ok

                    #Save data to memory 
                    self.mem[addr] = int( await self._shift(8) )
                    self.dut._log.info("FM25C160B: Wrote %02x to address %04x", self.mem[addr], addr)

                    await frame_end

                    
                
            # Read command
            case ( 0x03 ):
                self.dut._log.info("FM25C160B: Read command found")
                addr = int( await self._shift(16) )

                # Check if address is ok
                if( addr >= FM25C160B.memsize ):
                    raise ValueError('FM25C160B: Read Address %04x is too large for memory size of %04x' %( addr, FM25C160B.memsize))

                # Address is ok

                #Write out data
                data = self.mem[addr]
                output = int(await self._shift(8, tx_word=data))
                self.dut._log.info("FM25C160B: Read %02x at address %04x", self.mem[addr], addr)
                await frame_end

            # Read Status Register 
            case ( 0x05 ):
                self.dut._log.info("FM25C160B: Read Status Register Command Found")
                int(await self._shift(8, tx_word=(self.status)))
                await frame_end


            # Write Enable; only 8 bit word, should be done now
            case ( 0x06 ):
                self.dut._log.info("FM25C160B: Write Enable Latch command found")
                # Set the WEN bit in status
                self.status = self.status | (1 << 1)
                await frame_end
            # Default case
            case _:
                raise SpiFrameError('FM25C160B: Unknown opcode: %02x' % (cmd))

