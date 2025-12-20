/*
* Instantiate the entire grid of PEs and wire together appropriately
*/
module grid #(
    parameter N = 4,
    parameter data_width = 8,
    parameter result_width = 32
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire load_weight,
    input wire [data_width-1:0] inputs_left [0:N-1],     
    output wire [result_width-1:0] sums_bottom [0:N-1]     
);  
    //assign the top level wires to the interconnect wires that will be used to instantiate the grid
    wire [data_width-1:0] data_path_wires [0:N][0:N]; 
    wire [result_width-1:0] sum_path_wires [0:N][0:N];
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : drive_left
            assign data_path_wires[i][0] = inputs_left[i];
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
                    .data_width(data_width),
                    .result_width(result_width)
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

    generate
        for (j=0; j<N; j=j+1) begin
            assign sums_bottom[j] = sum_path_wires[N][j];
        end
    endgenerate
endmodule