import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
import random

async def master_data_driver(dut, values):
    for i in range(len(values)):
        await FallingEdge(dut.clk)
        dut.outbuf_data.value = values[i]
        if random.random() > 0.3:
            #disable the output buffer 
            dut.outbuf_valid.value = 0
        else:
            dut.outbuf_valid.value = 1
            # dut._log.info(f"Master data: {values[i]}")

        # await RisingEdge(dut.clk)

async def slave_ready_driver(dut):
    while True:
        await FallingEdge(dut.clk)
        if random.random() > 0.3:
            dut.inbuf_ready.value = 0
        else:
            dut.inbuf_ready.value = 1
    
async def output_monitor(dut):
    while True:
        await RisingEdge(dut.clk)
        #condition for the slave to accept the tdata 
        if (not dut.inbuf_valid.value or dut.inbuf_ready.value) and (not dut.outbuf_valid.value):
            dut._log.info(f"Transaction conditions met.")
            dut._log.info(f"Slave data: {dut.inbuf_data.value.to_unsigned()}")

@cocotb.test()
async def basic_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    cocotb.start_soon(slave_ready_driver(dut))
    cocotb.start_soon(output_monitor(dut))
    await master_data_driver(dut, [random.randint(0,0xffffffff) for _ in range(50)])










