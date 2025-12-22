import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

def send_input(dut, vals, N):
    for i in range(N):
        dut.col_input[i].value = vals[i]

@cocotb.test()
async def test_output_skew_logic(dut):    
    N = 4
    RESULT_WIDTH = 32
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    dut._log.info("Resetting DUT...")
    dut.reset.value = 1
    dut.enable.value = 0
    
    send_input(dut, vals=[0 for _ in range(N)], N=N)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    
    dut.reset.value = 0
    dut.enable.value = 1
    
    dut._log.info("Phase 1: Continuous Streaming Verification")
    
    input_history = [[] for _ in range(N)]
    
    col_inputs = [[] for _ in range(N)]

    for i in range(N):
        for j in range(2*N):
            rand_input = random.randint(0, 2**32)
            col_inputs[i].append(rand_input)
            if j >= i and j < N+i:
                input_history[i].append(rand_input)

    actual_outputs = [[] for _ in range(N)]

    for t in range(2*N):
        cycle_inputs = []
        for i in range(N):
            cycle_inputs.append(col_inputs[i][t])
        
        send_input(dut, cycle_inputs, N)

        await RisingEdge(dut.clk)

        if t > (N-1):
            for i in range(N):
                actual_outputs[i].append(dut.col_output[i].value.to_unsigned())


    assert input_history == actual_outputs, "ERROR: NON-MATCHING INPUT and OUTPUT"


