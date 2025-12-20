import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.types import LogicArray

@cocotb.test()
async def pe_test(dut):
    """
    Comprehensive verification of the Processing Element (PE).
    Covers: Reset, Enable, Weight Loading, Positive/Negative MAC operations.
    """
    
    DATA_WIDTH = 8
    RESULT_WIDTH = 32
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut._log.info("Test 1: Reset Logic")
    dut.reset.value = 1
    dut.enable.value = 0
    dut.load_weight.value = 0
    dut.activ_input.value = 0xFF # Garbage input
    dut.top_sum_input.value = 0xFFFF 
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    assert dut.activ_output.value == 0, "Reset Failed: activ_output not 0"
    assert dut.sum_output.value == 0, "Reset Failed: sum_output not 0"
    
    dut._log.info("Test 1 Passed")


    dut._log.info("Test 2: Loading Weight")
    
    dut.reset.value = 0
    test_weight = 5
    dut.enable.value = 1
    dut.load_weight.value = 1
    dut.activ_input.value = test_weight
    dut.top_sum_input.value = 0 
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    actual_out = dut.activ_output.value
    assert actual_out == test_weight, f"Weight Load Failed: Expected pass-through {test_weight}, got {actual_out}"
    
    dut._log.info(f"Weight {test_weight} loaded successfully.")

    dut._log.info("Test 3: Basic MAC (Positive)")
    
    dut.load_weight.value = 0
    
    a_in = 3
    s_in = 10
    
    dut.activ_input.value = a_in
    dut.top_sum_input.value = s_in
    
    await RisingEdge(dut.clk) # Capture inputs
    await RisingEdge(dut.clk) # Wait for synchronous output (PE has registered outputs)
    
    actual_sum = int(dut.sum_output.value)
    expected_sum = s_in + (a_in * test_weight)
    
    actual_activ = int(dut.activ_output.value)
    
    assert actual_sum == expected_sum, f"MAC Error: {s_in} + ({a_in} * {test_weight}) should be {expected_sum}, got {actual_sum}"
    assert actual_activ == a_in, f"Activation Pass-through Error: Expected {a_in}, got {actual_activ}"
    
    dut._log.info(f"MAC Correct: {s_in} + ({a_in} * {test_weight}) = {actual_sum}")

    dut._log.info("Test 4: Signed MAC (Negative Input)")
    
    a_in_neg = -2
    s_in = 50
    
    dut.activ_input.value = a_in_neg
    dut.top_sum_input.value = s_in
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    signed_sum_out = LogicArray(dut.sum_output.value).to_signed()
    expected_signed = s_in + (a_in_neg * test_weight)
    
    assert signed_sum_out == expected_signed, f"Signed MAC Error: {s_in} + ({a_in_neg} * {test_weight}) should be {expected_signed}, got {signed_sum_out}"
    
    dut._log.info(f"Signed MAC Correct: {s_in} + ({a_in_neg} * {test_weight}) = {signed_sum_out}")

    dut._log.info("Test 5: Enable Logic")
    
    prev_sum = dut.sum_output.value
    prev_activ = dut.activ_output.value
    
    dut.enable.value = 0
    
    dut.activ_input.value = 100
    dut.top_sum_input.value = 1000
    
    await RisingEdge(dut.clk)
    
    assert dut.sum_output.value == prev_sum, "Enable Error: Sum output changed while disabled!"
    assert dut.activ_output.value == prev_activ, "Enable Error: Activ output changed while disabled!"
    
    dut._log.info("Enable Logic Verified: State held correctly.")
    
    dut._log.info("------------------------------------------------")
    dut._log.info("ALL PE TESTS PASSED")
    dut._log.info("------------------------------------------------")