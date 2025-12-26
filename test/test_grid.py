import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random
import numpy as np

def to_signed(val, bits):
    """Interpret positive integer as 2's comp."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def to_unsigned(val, bits):
    """Convert int to unsigned bit vector."""
    return val & ((1 << bits) - 1)

def skew_activations(A, N):
    """Generate skewed input schedule for the grid."""
    rows_A = len(A)
    total_cycles = rows_A + (N - 1)
    skewed_stream = []
    
    for t in range(total_cycles):
        input_at_t = []
        for r in range(N):
            # Row r gets Col r of A, delayed by r cycles
            src_idx = t - r
            if 0 <= src_idx < rows_A:
                val = A[src_idx][r]
            else:
                val = 0
            input_at_t.append(val)
        skewed_stream.append(input_at_t)
    return skewed_stream

async def drive_inputs(dut, input_vector, n, width):
    #pack the vector into one large input
    flat_val = 0
    for i in range(n):
        val = int(input_vector[i])
        flat_val |= (val & ((1 << width) - 1)) << (i * width)    
    dut.inputs_left.value = flat_val

def read_outputs(dut, n, width):
    res = []
    try:
        flat_val = dut.sums_bottom.value.to_unsigned()
    except ValueError:
        return [0] * n
    single_element_mask = (1 << width) - 1
    for i in range(n):
        shifted_val = flat_val >> (i * width)
        val = shifted_val & single_element_mask
        res.append(to_signed(val, width))
        
    return res

# ==============================================================================
# Main Test
# ==============================================================================
@cocotb.test()
async def grid_test(dut):
    N = 4
    DATA_WIDTH = 8
    RESULT_WIDTH = 32
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    dut.reset.value = 1
    dut.enable.value = 0
    dut.load_weight.value = 0
    await drive_inputs(dut, [0]*N, N, DATA_WIDTH)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    dut.enable.value = 1

    A = [[random.randint(1, 5) for _ in range(N)] for _ in range(N)]    
    B = [[random.randint(1, 5) for _ in range(N)] for _ in range(N)]
    
    dut._log.info("Loading Weights...")

    dut.load_weight.value = 1
    for col_idx in reversed(range(N)):
        col_vec = [B[row][col_idx] for row in range(N)]
        await drive_inputs(dut, col_vec, N, DATA_WIDTH)
        await RisingEdge(dut.clk)
        
    dut.load_weight.value = 0
    await drive_inputs(dut, [0]*N, N, DATA_WIDTH)
    dut._log.info("Weights Loaded.")

    dut._log.info("Streaming Skewed Activations...")
    
    input_schedule = skew_activations(A, N)
    dut._log.info(f"Activations\n {np.array(input_schedule)}")

    raw_columns = [[] for _ in range(N)]
    
    for t, inputs_at_t in enumerate(input_schedule):
        await drive_inputs(dut, inputs_at_t, N, DATA_WIDTH)
        await RisingEdge(dut.clk)
    
        actual = read_outputs(dut, N, RESULT_WIDTH)
        for col_index in range(N):
            latency = col_index + N
            if t >= latency:
                raw_columns[col_index].append(actual[col_index])

    for n in range(N):
        await RisingEdge(dut.clk)
        actual = read_outputs(dut, N, RESULT_WIDTH)
        for col_index in range(N):
            if (col_index - n) >= 0:
                raw_columns[col_index].append(actual[col_index])

    dut._log.info(f"Raw columns\n {raw_columns}")

    final_matrix_c = [[] for _ in range(N)]
    for i in range(len(raw_columns)):
        for j in range(len(raw_columns)):
            final_matrix_c[j].append(raw_columns[i][j])
            
    np_a = np.array(A)
    np_b = np.array(B)
    expected_c = np.matmul(np_a, np_b)

    dut._log.info(f"\nConstructed Matrix C:\n{np.array(final_matrix_c)}")
    dut._log.info(f"\nExpected Matrix C (Golden):\n{expected_c}")

    assert np.array_equal(final_matrix_c, expected_c), "FINAL MATRIX MISMATCH! Hardware output does not match A @ B."
    
    dut._log.info("Test Complete.")