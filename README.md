# mmul_systolic_array
Verilog implementation of a weight stationary systolic array for matrix multiplication, with skew/deskew data orchestration and AXI4-stream integration

## Overview
This project is a Verilog implementation of a 4x4 Weight-Stationary Systolic Array designed for matrix multiplication. The design targets the SkyWater 130nm technology node using the OpenLane physical design flow. It features AXI4-Stream interfaces for integration with larger system-on-chip (SoC) architectures.

## Architecture
The system computes `C = A x B` where weights (`B`) are pre-loaded into the array, and activations (`A`) are streamed in.

### 1. Data Flow Orchestration
To maximize throughput in a systolic array, input data must be "skewed" (time-delayed) so that the correct activation meets the correct partial sum at the right Processing Element (PE).
* **Input Skew Buffer:** Delays input rows triangularly. Row 0 has 0 delay, Row `i` has `i` cycle delays.
* **Output Deskew Buffer:** Re-aligns the output partial sums. Column 0 (finishing first) is delayed by `N-1` cycles, while the last column passes through immediately.

### 2. Processing Element (PE)
Each PE performs a Multiply-Accumulate (MAC) operation:
* **Weight Loading:** Weights are daisy-chained through the array during the setup phase.
* **Computation:** `Sum_Out = Sum_In + (Activation * Weight)`.
* **Precision:** 8-bit integer inputs with 32-bit accumulation to prevent overflow.

## Directory Structure
* `src/`: Synthesizable Verilog source code.
    * `grid.v`: The 4x4 interconnected array of PEs.
    * `pe.v`: Individual processing element logic.
    * `input_buffer.v` / `output_buffer.v`: Data alignment logic.
* `test/`: Cocotb verification environment.
    * `test_skew.py`: Visualization tests for data orchestration buffers.

## Tools Used
* **Simulation:** Icarus Verilog & Cocotb
* **Physical Design:** OpenLane (RTL-to-GDSII)
* **PDK:** SkyWater 130nm