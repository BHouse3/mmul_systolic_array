import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np


class AXIStreamDriver:
    def __init__(self, dut, name, clk, width, n):
        self.dut = dut
        self.name = name
        self.clk = clk
        self.width = width
        self.n = n
        self.tdata  = getattr(dut, f"{name}_tdata")
        self.tvalid = getattr(dut, f"{name}_tvalid")
        self.tready = getattr(dut, f"{name}_tready")
        self.tvalid.value = 0
        self.tdata.value = 0

    async def send_matrix(self, matrix_data):
        for col_idx, column in enumerate(matrix_data):
            flat_val = 0
            for r in range(self.n):
                val = int(column[r])
                flat_val |= (val & ((1 << self.width) - 1)) << (r * self.width)
            
            self.tdata.value = flat_val
            self.tvalid.value = 1
            
            while True:
                await RisingEdge(self.clk)
                if self.tready.value == 1: 
                    break 
        self.tvalid.value = 0

class AXIStreamMonitor:
    def __init__(self, dut, name, clk, width, n):
        self.dut = dut
        self.clk = clk
        self.width = width
        self.n = n
        self.captured_data = []
        self.tdata  = getattr(dut, f"{name}_tdata")
        self.tvalid = getattr(dut, f"{name}_tvalid")
        self.tready = getattr(dut, f"{name}_tready")
        self.tready.value = 1

    async def monitor(self):
        while True:
            await RisingEdge(self.clk)
            await ReadOnly()
            
            if self.tvalid.value == 1 and self.tready.value == 1:
                flat_val = int(self.tdata.value)
                
                col_data = []
                mask = (1 << self.width) - 1
                for r in range(self.n):
                    val = (flat_val >> (r * self.width)) & mask
                    col_data.append(val)
                self.captured_data.append(col_data)

@cocotb.test()
async def random_matmul_test(dut):
    N = 4
    DATA_WIDTH = 8
    RESULT_WIDTH = 32
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    driver = AXIStreamDriver(dut, "s_axis", dut.clk, DATA_WIDTH, N)
    monitor = AXIStreamMonitor(dut, "m_axis", dut.clk, RESULT_WIDTH, N)
    cocotb.start_soon(monitor.monitor())

    dut._log.info("Resetting DUT...")
    dut.reset.value = 1
    dut.load_weight.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    A = np.array([[1,2,3,4],[1,2,3,4],[1,2,3,4],[1,2,3,4]])
    B = np.array([[2,2,2,2],[2,2,2,2],[2,2,2,2],[2,2,2,2]])
    expected_C = np.matmul(A, B)

    dut._log.info(f"\nMatrix A:\n{A}\nMatrix B:\n{B}\nExpected C:\n{expected_C}")

    dut._log.info("Phase 1: Loading Weights...")
    dut.load_weight.value = 1
    
    weight_stream = []
    for c in reversed(range(N)):
        col = B[:, c]
        weight_stream.append(col)
        
    await driver.send_matrix(weight_stream)
    
    await RisingEdge(dut.clk)
    dut.load_weight.value = 0 
    
    dut._log.info("Phase 2: Streaming Activations...")
    activation_stream = []
    for c in range(N):
        col = A[:, c]
        activation_stream.append(col)
        
    zero_col = [0] * N
    for _ in range(3 * N):
        activation_stream.append(zero_col)

    await driver.send_matrix(activation_stream)

    timeout = 1000
    while len(monitor.captured_data) < N and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
    assert timeout > 0, "Timeout waiting for output data!"

    actual_C = np.array(monitor.captured_data[:N]).T 
    dut._log.info(f"\nActual Output:\n{actual_C}")
    
    if np.array_equal(actual_C, expected_C):
        dut._log.info("TEST PASSED! Output matches Gold Model.")
    else:
        dut._log.error(f"TEST FAILED!\nExpected:\n{expected_C}\nGot:\n{actual_C}")
        # FIXED: Use standard assert instead of deprecated TestFailure
        assert False, "Output mismatch"