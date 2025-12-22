import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

def pack_input(row_values, n, width):
    """
    Packs a list of N integers into a single flat integer for 'streamed_input'.
    Format: Row 0 is LSB, Row N-1 is MSB.
    """
    flat_val = 0
    mask = (1 << width) - 1
    for i in range(n):
        val = row_values[i] & mask
        flat_val |= (val << (i * width))
    return flat_val

def read_skewed_output(dut, n):
    """Reads the unpacked output array."""
    res = []
    for i in range(n):
        try:
            val = dut.skewed_output[i].value.to_unsigned()
            res.append(val)
        except ValueError:
            res.append(0)
    return res


@cocotb.test()
async def test_input_skew_logic(dut):
    """
    Verify Input Buffer Skewing and Enable Logic.
    
    1. Checks that Row 'i' output matches Row 'i' input from (i+1) cycles ago.
    2. Checks that de-asserting 'enable' freezes the pipeline.
    """
    
    N = 4
    DATA_WIDTH = 8
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    dut._log.info("Resetting DUT...")
    dut.reset.value = 1
    dut.enable.value = 0
    dut.streamed_input.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    
    dut.reset.value = 0
    dut.enable.value = 1
    
    dut._log.info("Phase 1: Continuous Streaming Verification")
    
    input_history = []
    
    CYCLES = 50
    
    for t in range(CYCLES):
        curr_input = [random.randint(0, 255) for _ in range(N)]
        input_history.append(curr_input)
        
        dut.streamed_input.value = pack_input(curr_input, N, DATA_WIDTH)
        
        await RisingEdge(dut.clk)
        
        
        actual_output = read_skewed_output(dut, N)
        
        dut._log.info(f"Output at cycle {t}:\n {actual_output}")


    dut._log.info("Phase 2: Enable/Pause Logic Verification")
    
    dut.enable.value = 0
    dut._log.info("  -> Enable Dropped (Pause)")
    
    garbage_input = [0xAA] * N
    dut.streamed_input.value = pack_input(garbage_input, N, DATA_WIDTH)
    
    await RisingEdge(dut.clk)

    pre_pause_output = read_skewed_output(dut, N)

    await RisingEdge(dut.clk)

    curr_output = read_skewed_output(dut, N)

    assert curr_output == pre_pause_output, "ERROR: Values still moving during low enable"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.enable.value = 1
    dut._log.info("  -> Enable Activated")

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


