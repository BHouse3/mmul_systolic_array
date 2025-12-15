`timescale 1ns/1ps

module top (
    input clk, reset, enable,
    input [31:0] data,
    output reg [31:0] final_res // Changed to output reg [31:0]
);

    wire [31:0] final_res_wire;

    skew_buffer buff_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .flat_input(data),       // Added missing comma
        .skewed_output(final_res_wire)
    );

    always @(posedge clk) begin
        if (!reset)
            final_res <= 32'b0;
        else
            final_res <= final_res_wire;
    end

endmodule

// (Keep the skew_buffer module exactly as you wrote it, it logic looks correct)
module skew_buffer #(
    parameter N = 4,
    parameter D_W = 8
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [N*D_W-1:0] flat_input,
    output wire [N*D_W-1:0] skewed_output 
);
    wire [D_W-1:0] in_rows [0:N-1];
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : unpack_in
            assign in_rows[i] = flat_input[(i*D_W) +: D_W];
        end
    endgenerate

    reg [D_W-1:0] delay_regs [0:N-1][0:N-1];

    integer r, d;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (r = 0; r < N; r = r + 1) begin
                for (d = 0; d < N; d = d + 1) begin
                    delay_regs[r][d] <= {D_W{1'b0}};
                end
            end
        end else if (enable) begin
            for (r = 1; r < N; r = r + 1) begin
                delay_regs[r][0] <= in_rows[r]; 
                for (d = 1; d < r; d = d + 1) begin
                    delay_regs[r][d] <= delay_regs[r][d-1];
                end
            end
        end
    end

    genvar k;
    generate
        assign skewed_output[0 +: D_W] = in_rows[0]; 
        for (k = 1; k < N; k = k + 1) begin : pack_out
            assign skewed_output[(k*D_W) +: D_W] = delay_regs[k][k-1];
        end
    endgenerate

    // ==========================================
    // DEBUGGING ONLY: Flatten internals for test
    // ==========================================
    wire [N*N*D_W-1:0] dbg_flat_regs;
    genvar dr, dc;
    generate
        for (dr = 0; dr < N; dr = dr + 1) begin : flat_r
            for (dc = 0; dc < N; dc = dc + 1) begin : flat_c
                // Map 2D [row][col] to 1D vector
                assign dbg_flat_regs[((dr*N + dc)*D_W) +: D_W] = delay_regs[dr][dc];
            end
        end
    endgenerate
endmodule