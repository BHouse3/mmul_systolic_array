/*
* Each processing element has identical functionality
* 1. Hold a weight value
* 2. Receive an activation input from the left
* 3. Receive a partial sum input from above
* 4. Compute the new sum (input*weight+sum_input)
* 5. Pass the activation input to the right
* 6. Pass the new sum below
*/
module pe #(
    parameter data_width = 8,  
    parameter result_width = 32 
)(
    input wire clk,
    input wire reset,
    input wire enable, 
    input wire load_weight,
    input wire [data_width-1:0] activ_input,  
    input wire [result_width-1:0] top_sum_input, 
    output reg [data_width-1:0] activ_output,  
    output reg [result_width-1:0] sum_output
);

    reg [data_width-1:0] weight_reg;

    always @(posedge clk) begin
        if (reset) begin
            weight_reg <= {data_width{1'b0}};
            activ_output <= {data_width{1'b0}};
            sum_output <= {result_width{1'b0}};
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