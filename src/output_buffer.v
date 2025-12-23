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
module output_buffer #(
    parameter N = 4,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [RESULT_WIDTH-1:0] col_input [0:N-1],
    output wire [RESULT_WIDTH-1:0] col_output [0:N-1]
);

    //deskew logic is similar to skew logic, just inverted 
    genvar i,j;
    generate
        for (i=0; i < N; i = i+1) begin : row
            for (j=0; j < N-1-i; j = j+1) begin : stage
                reg [RESULT_WIDTH-1:0] delay;
                if (j==0) begin
                    always @(posedge clk ) begin
                        if (reset) delay <= {RESULT_WIDTH{1'b0}};
                        else if (enable) delay <= col_input[i];
                    end
                end 
                else begin
                    always @(posedge clk ) begin
                        if (reset) delay <= {RESULT_WIDTH{1'b0}};
                        else if (enable) delay <= row[i].stage[j-1].delay;
                    end
                end
            end

            // output register for each row
            //updates on the clk which enforces alignment to the clk signal
            reg [RESULT_WIDTH-1:0] output_reg;
            always @(posedge clk) begin
                if (reset) output_reg <= {RESULT_WIDTH{1'b0}};
                else if (enable) begin
                    if (i==(N-1)) output_reg <= col_input[N-1];  
                    else output_reg <= row[i].stage[N-2-i].delay;
                end
            end
            assign col_output[i] = output_reg;
        end
    endgenerate
endmodule