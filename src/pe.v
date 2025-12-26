/*
* Each processing element has identical functionality
* 1. Hold a weight value
* 2. Receive an activation input from the left
* 3. Receive a partial sum input from above
* 4. Compute the new sum (input*weight+sum_input)
* 5. Pass the activation input to the right
* 6. Pass the new sum below
*/
`timescale 1ns/1ps

module pe #(
    parameter DATA_WIDTH = 8,  
    parameter RESULT_WIDTH = 32 
)(
    input wire clk,
    input wire reset,
    input wire enable, 
    input wire load_weight,
    input wire [DATA_WIDTH-1:0] activ_input,  
    input wire [RESULT_WIDTH-1:0] top_sum_input, 
    output reg [DATA_WIDTH-1:0] activ_output,  
    output reg [RESULT_WIDTH-1:0] sum_output
);

    reg [DATA_WIDTH-1:0] weight_reg;

    always @(posedge clk) begin
        if (reset) begin
            weight_reg <= {DATA_WIDTH{1'b0}};
            activ_output <= {DATA_WIDTH{1'b0}};
            sum_output <= {RESULT_WIDTH{1'b0}};
        end 
        else if (enable) begin 
            if (load_weight) begin
                weight_reg <= activ_input;
                activ_output <= activ_input; 
            end 
            else begin
                activ_output <= activ_input;
                sum_output <= $signed(top_sum_input) + ($signed(activ_input) * $signed(weight_reg));
            end
        end
    end
endmodule
