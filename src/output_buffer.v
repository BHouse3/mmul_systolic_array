/*
 * The output is skewed similarly to the input 
 * The first row of output data is the first to stream out of the grid from the first column 
 * The next row begins streaming out a cycle later from the second column
 * The last row begins streaming out of the last column N-1 cycles after the first column began
 * Thus, we can use a similar strategy to deskew the data

   The first column output needs to be passed through N-1 delay registers
   The second column output needs to be passed through N-2 delay registers
   The last column output can be passed through
 */
`timescale 1ns/1ps

module output_buffer #(
    parameter N = 4,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [N*RESULT_WIDTH-1:0] col_input,
    output wire [N*RESULT_WIDTH-1:0] col_output
);

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : row
            
            reg [RESULT_WIDTH-1:0] output_reg;
            wire [RESULT_WIDTH-1:0] row_in_val;

            assign row_in_val = col_input[(i*RESULT_WIDTH) +: RESULT_WIDTH];

            if (i == N-1) begin : direct_pass
                always @(posedge clk) begin
                    if (reset) output_reg <= {RESULT_WIDTH{1'b0}};
                    else if (enable) output_reg <= row_in_val;
                end
            end 
            else begin : delayed_pass
                localparam DEPTH = N - 1 - i;
                reg [RESULT_WIDTH-1:0] shift_reg [0:DEPTH-1];
                integer k;

                always @(posedge clk) begin
                    if (reset) begin
                        output_reg <= {RESULT_WIDTH{1'b0}};
                        for (k = 0; k < DEPTH; k = k + 1) begin
                            shift_reg[k] <= {RESULT_WIDTH{1'b0}};
                        end
                    end 
                    else if (enable) begin
                        shift_reg[0] <= row_in_val;
                        for (k = 1; k < DEPTH; k = k + 1) begin
                            shift_reg[k] <= shift_reg[k-1];
                        end
                        output_reg <= shift_reg[DEPTH-1];
                    end
                end
            end
            assign col_output[(i*RESULT_WIDTH) +: RESULT_WIDTH] = output_reg;
        end
    endgenerate
endmodule
