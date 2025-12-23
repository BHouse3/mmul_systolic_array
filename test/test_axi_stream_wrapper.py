import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly
import random

async def axi_master_driver(dut, values):
    idx = 0
    dut.outbuf_valid.value = 0
    dut.outbuf_data.value = 0

    while idx < len(values):
        await RisingEdge(dut.clk)

        #handshake condition
        if dut.outbuf_valid.value and dut.outbuf_ready.value:
            idx += 1
            dut.outbuf_valid.value = 0  #clear tvalid after acceptance

        #if the data isn't valid, then accept new data from the output buffer
        if not dut.outbuf_valid.value and idx < len(values):
            dut.outbuf_data.value = values[idx]
            dut.outbuf_valid.value = 1

    dut.outbuf_valid.value = 0

#randomly deassert tready to simulate backpressure
async def slave_ready_driver(dut):
    while True:
        await RisingEdge(dut.clk)
        dut.inbuf_ready.value = 1 if random.random() > 0.2 else 0

async def axi_monitor(dut, expected_values):
    captured = 0
    prev_tvalid = 0
    prev_tdata  = None

    while captured < len(expected_values):
        await RisingEdge(dut.clk)
        await ReadOnly()

        tvalid = int(dut.tvalid.value)
        tready = int(dut.tready.value)
        tdata  = int(dut.tdata.value)

        #tvalid must stay high until handshake
        if prev_tvalid and not (prev_tvalid and prev_tready):
            assert tvalid == 1, "ERROR: tvalid deasserted before handshake"

        # tdata must be stable while stalled
        if prev_tvalid and not prev_tready:
            assert tdata == prev_tdata, "ERROR: tdata changed while waiting for tready"

        if tvalid and tready:
            actual = tdata
            expected = expected_values[captured]
            assert actual == expected, f"Data mismatch at beat {captured+1}: exp={hex(expected)} got={hex(actual)}"
            dut._log.info(f"Beat {captured+1} OK: {hex(actual)}")
            captured += 1

        prev_tvalid = tvalid
        prev_tready = tready
        prev_tdata  = tdata

@cocotb.test()
async def test_axi_stream_loopback(dut):
    N = 4
    DATA_WIDTH = 8

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.reset.value = 1
    dut.outbuf_valid.value = 0
    dut.inbuf_ready.value = 0

    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.reset.value = 0
    await RisingEdge(dut.clk)

    # Reset assertions
    assert dut.inbuf_valid.value == 0, "Reset failed: inbuf_valid high"
    assert dut.tvalid.value == 0, "Reset failed: tvalid high"

    test_len = 50
    test_values = [random.randint(0, (1 << (N * DATA_WIDTH)) - 1) for _ in range(test_len)]

    cocotb.start_soon(slave_ready_driver(dut))
    monitor_task = cocotb.start_soon(axi_monitor(dut, test_values))
    await axi_master_driver(dut, test_values)

    await monitor_task

    dut._log.info("=======================================")
    dut._log.info(" AXI-STREAM PROTOCOL & DATA TEST PASSED ")
    dut._log.info("=======================================")
