import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np

class AXIStreamDriver:
    def __init__(self, dut, name, clk, width, n):
        self.dut = dut
        self.clk = clk
        self.width = width
        self.n = n
        self.tdata  = getattr(dut, f"{name}_tdata")
        self.tvalid = getattr(dut, f"{name}_tvalid")
        self.tready = getattr(dut, f"{name}_tready")
        self.tvalid.value = 0
        self.tdata.value = 0

    async def send_rows(self, rows_data):
        for row in rows_data:
            flat_val = 0
            for i in range(self.n):
                val = int(row[i])
                flat_val |= (val & ((1 << self.width) - 1)) << (i * self.width)
            
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
                row_data = []
                mask = (1 << self.width) - 1
                for i in range(self.n):
                    val = (flat_val >> (i * self.width)) & mask
                    if val >= (1 << (self.width - 1)): 
                        val -= (1 << self.width)
                    row_data.append(val)
                self.captured_data.append(row_data)

@cocotb.test()
async def test_matmul_full_design(dut):
    N = 4
    DATA_WIDTH = 8
    RESULT_WIDTH = 32
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    driver = AXIStreamDriver(dut, "s_axis", dut.clk, DATA_WIDTH, N)
    monitor = AXIStreamMonitor(dut, "m_axis", dut.clk, RESULT_WIDTH, N)
    cocotb.start_soon(monitor.monitor())

    dut.reset.value = 1
    dut.load_weight.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

    A = np.random.randint(0, 10, (N, N))
    B = np.random.randint(0, 10, (N, N))
    expected_C = np.matmul(A, B)

    dut._log.info(f"\nMatrix A:\n{A}\nMatrix B:\n{B}\nExpected C:\n{expected_C}")

    dut.load_weight.value = 1
    
    weight_stream = []
    for c in reversed(range(N)):
        weight_stream.append(B[:, c])

    await driver.send_rows(weight_stream)
    await RisingEdge(dut.clk)
    dut.load_weight.value = 0
    
    assert len(monitor.captured_data) == 0, "Error: Valid data detected during weight loading"

    activation_stream = []
    for r in range(N):
        activation_stream.append(A[r, :])

    for _ in range(3 * N):
        activation_stream.append([0]*N)

    await driver.send_rows(activation_stream)

    timeout = 1000
    while len(monitor.captured_data) < N and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
    assert timeout > 0, "Timeout: Output pipeline stalled."

    actual_C = np.array(monitor.captured_data[:N])
    dut._log.info(f"\nActual Output:\n{actual_C}")
    
    if np.array_equal(actual_C, expected_C):
        dut._log.info("TEST PASSED: Output matches Model.")
    else:
        dut._log.error(f"TEST FAILED.\nExpected:\n{expected_C}\nGot:\n{actual_C}")
        assert False, "Matrix Mismatch"