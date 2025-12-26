/*
* Instantiate the entire grid of PEs and wire together appropriately
*/
`timescale 1ns/1ps

module grid #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire load_weight,
    input wire [N*DATA_WIDTH-1:0] inputs_left,     
    output wire [N*RESULT_WIDTH-1:0] sums_bottom     
);

    //unpack the input wires to map to rows    
    //instantiate the interconnect wires
    wire [DATA_WIDTH-1:0] data_path_wires [0:N][0:N];
    wire [RESULT_WIDTH-1:0] sum_path_wires [0:N][0:N];
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : drive_left
            // Slice the flat input
            assign data_path_wires[i][0] = inputs_left[(i*DATA_WIDTH) +: DATA_WIDTH];
        end
        for (j = 0; j < N; j = j + 1) begin : drive_top
            assign sum_path_wires[0][j] = 0;
        end
    endgenerate

    //instantiate the grid of PEs
    //left input should be data_path[i][j] and right output should be data_path[i][j+1] (last column of PEs will have a meaningless output wire)
    //top input should be sum_path[i][j] and bottom output should be sum_path[i+1][j]
    generate
        for (i = 0; i < N; i = i + 1) begin : rows
            for (j = 0; j < N; j = j + 1) begin : cols
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .RESULT_WIDTH(RESULT_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .reset(reset),
                    .enable(enable),
                    .load_weight(load_weight),
                    .activ_input(data_path_wires[i][j]),
                    .top_sum_input(sum_path_wires[i][j]),
                    .activ_output(data_path_wires[i][j+1]),
                    .sum_output(sum_path_wires[i+1][j])
                );
            end
        end
    endgenerate

    //pack the output back into flattened bus wires
    generate
        for (j = 0; j < N; j = j + 1) begin : pack_bottom
            assign sums_bottom[(j*RESULT_WIDTH) +: RESULT_WIDTH] = sum_path_wires[N][j];
        end
    endgenerate

endmodule
