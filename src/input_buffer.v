/*
 * Activation inputs need to be coordinated when being input into the grid
 * The rows need to be offset from each other
 * The top row of the input can be streamed in as soon as it is available
 * The next row must wait a cycle before it can be streamed
 * The last row has to wait N-1 cycles before it can begin streaming
 * This results in the below pattern
 * B13 B12 B11 A14 A13 A12 A11
 * B22 B21 A24 A23 A22 A21  -
 * B31 A34 A33 A32 A31  -   -
 * A44 A43 A42 A41  -   -   -

    So our job is to simply as a delay based on which column is being inserted
    The buffer accepts a top level streamed column data input
    It will send the top row immediately 
    The next row has to go through 1 shift register
    The last row has to go through N-1 shift registers
 */
// `timescale 1ns/1ps

// module input_buffer #(
//     parameter N = 4,
//     parameter DATA_WIDTH = 8
// )(
//     input wire clk,
//     input wire reset,
//     input wire enable,
//     input wire [N*DATA_WIDTH-1:0] streamed_input,
//     output wire [DATA_WIDTH-1:0] skewed_output [0:N-1]
// );

//     // Unpack the streamed input
//     wire [DATA_WIDTH-1:0] in_rows [0:N-1];
//     genvar i;
//     generate
//         for (i = 0; i < N; i = i + 1) begin : unpack_in
//             assign in_rows[i] = streamed_input[(i*DATA_WIDTH) +: DATA_WIDTH];
//         end
//     endgenerate

//     generate
//         for (i = 0; i < N; i = i + 1) begin : row
//             reg [DATA_WIDTH-1:0] output_reg;
//             if (i == 0) begin : no_delay
//                 always @(posedge clk) begin
//                     if (reset) output_reg <= {DATA_WIDTH{1'b0}};
//                     else if (enable) output_reg <= in_rows[i];
//                 end
//             end 
//             else begin : has_delay
//                 reg [DATA_WIDTH-1:0] shift_reg [0:i-1];
//                 integer k;

//                 always @(posedge clk) begin
//                     if (reset) begin
//                         output_reg <= {DATA_WIDTH{1'b0}};
//                         for (k = 0; k < i; k = k + 1) begin
//                             shift_reg[k] <= {DATA_WIDTH{1'b0}};
//                         end
//                     end 
//                     else if (enable) begin
//                         shift_reg[0] <= in_rows[i];
//                         for (k = 1; k < i; k = k + 1) begin
//                             shift_reg[k] <= shift_reg[k-1];
//                         end
//                         output_reg <= shift_reg[i-1];
//                     end
//                 end
//             end            
//             assign skewed_output[i] = output_reg;
//         end
//     endgenerate
// endmodule

`timescale 1ns/1ps

module input_buffer #(
    parameter N = 4,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [N*DATA_WIDTH-1:0] streamed_input,
    output wire [N*DATA_WIDTH-1:0] skewed_output
);

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : row
            reg [DATA_WIDTH-1:0] output_reg;
            wire [DATA_WIDTH-1:0] row_input;
            
            assign row_input = streamed_input[(i*DATA_WIDTH) +: DATA_WIDTH];

            if (i == 0) begin : no_delay
                always @(posedge clk) begin
                    if (reset) output_reg <= {DATA_WIDTH{1'b0}};
                    else if (enable) output_reg <= row_input;
                end
            end 
            else begin : has_delay
                reg [DATA_WIDTH-1:0] shift_reg [0:i-1];
                integer k;

                always @(posedge clk) begin
                    if (reset) begin
                        output_reg <= {DATA_WIDTH{1'b0}};
                        for (k = 0; k < i; k = k + 1) begin
                            shift_reg[k] <= {DATA_WIDTH{1'b0}};
                        end
                    end 
                    else if (enable) begin
                        shift_reg[0] <= row_input;
                        for (k = 1; k < i; k = k + 1) begin
                            shift_reg[k] <= shift_reg[k-1];
                        end
                        output_reg <= shift_reg[i-1];
                    end
                end
            end
            assign skewed_output[(i*DATA_WIDTH) +: DATA_WIDTH] = output_reg;
        end
    endgenerate
endmodule
