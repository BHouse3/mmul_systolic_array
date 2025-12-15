import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly

# 1. ROBUST HEX FORMATTER
def to_hex(val):
    """Converts any value to a 2-digit Hex string."""
    try:
        return f"{int(val):02X}"
    except:
        return "??"

def split_bytes(value, n=4, width=8):
    """Splits a 32-bit int into list of hex strings."""
    if value is None: return ["XX"] * n
    try:
        val_int = int(value)
    except ValueError: return ["XX"] * n
        
    bytes_list = []
    mask = (1 << width) - 1
    for i in range(n):
        byte_val = (val_int >> (i * width)) & mask
        bytes_list.append(to_hex(byte_val))
    return bytes_list

# 2. UPDATED INTERNAL READER (Uses the flat debug wire)
async def print_internal_state(dut, N=4, D_W=8):
    print(f"      Internal Registers:")
    
    try:
        # Read the flattened debug wire (Big Integer)
        flat_val = int(dut.buff_inst.dbg_flat_regs.value)
    except:
        print("      [Error: Could not read dbg_flat_regs]")
        return

    # Loop to reconstruct the triangle from the flat integer
    # The mapping matches the Verilog generate loop: index = (row * N + col)
    for r in range(N):
        row_vals = []
        for c in range(r): # We only care about valid registers (0 to r)
             # Calculate bit slice
            idx = (r * N + c)
            shift = idx * D_W
            val = (flat_val >> shift) & 0xFF
            row_vals.append(to_hex(val))
            
        if r == 0:
            # print(f"      Row 0: Passthrough")
            pass
        else:
            # We join them so it looks like: Reg0 -> Reg1 -> Output
            fmt_row = " -> ".join(row_vals)
            print(f"      Row {r}: {fmt_row}")

@cocotb.test()
async def test_skew_buffer_visual(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.reset.value = 0
    dut.enable.value = 0
    dut.data.value = 0
    
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await FallingEdge(dut.clk) # Safe edge for driving

    print("\n" + "="*80)
    print("SKEW BUFFER VISUALIZATION")
    print("="*80)

    input_sequence = [0x11111111, 0x22222222, 0x33333333, 0x44444444, 0x55555555]
    dut.enable.value = 1
    
    for i in range(8):
        # Drive Input
        if i < len(input_sequence):
            dut.data.value = input_sequence[i]
        else:
            dut.data.value = 0

        await RisingEdge(dut.clk)
        await ReadOnly() 
        
        # Read Data
        in_bytes = split_bytes(input_sequence[i] if i < len(input_sequence) else 0)
        out_bytes = split_bytes(dut.final_res.value)
        
        # Format string nicely
        in_str = "".join(reversed(in_bytes)) # show MSB..LSB
        out_str = f"[{out_bytes[0]} | {out_bytes[1]} | {out_bytes[2]} | {out_bytes[3]}]"
        
        print(f"\nCYCLE {i}")
        print(f"   Input:  0x{in_str}")
        print(f"   Output: {out_str}")
        
        await print_internal_state(dut)
        print("-" * 40)
        
        await FallingEdge(dut.clk)

    print("="*80 + "\n")