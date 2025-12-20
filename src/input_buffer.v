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
module input_buffer #(
    parameter N = 4,
    parameter data_width = 8
)(
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [N*data_width-1:0] streamed_input,
    // output wire [N*data_width-1:0] skewed_output 
    output wire [data_width-1:0] skewed_output [0:N-1]
);

    //unpack the streamed input (assign each section of the data to a row index)
    wire [data_width-1:0] in_rows [0:N-1];
    genvar i,j;
    generate
        for (i = 0; i < N; i = i + 1) begin : unpack_in
            assign in_rows[i] = streamed_input[(i*data_width) +: data_width];
        end
    endgenerate

    //create delay registers
    //number of delay stages matches the row index
    generate
        for (i=0; i < N; i = i+1) begin : row
            for (j=0; j < i; j = j+1) begin : stage
                reg [data_width-1:0] delay;
                if (j==0) begin
                    always @(posedge clk ) begin
                        if (reset) delay <= {data_width{1'b0}};
                        else if (enable) delay <= in_rows[i];
                    end
                end 
                else begin
                    always @(posedge clk ) begin
                        if (reset) delay <= {data_width{1'b0}};
                        else if (enable) delay <= row[i].stage[j-1].delay;
                    end
                end
            end

            // output register for each row
            //updates on the clk which enforces alignment to the clk signal
            reg [data_width-1:0] output_reg;
            always @(posedge clk) begin
                if (reset) output_reg <= {data_width{1'b0}};
                else if (enable) begin
                    if (i==0) output_reg <= in_rows[0]; //top row has no delay and is sent on the 
                    else output_reg <= row[i].stage[i-1].delay;
                end
            end
            assign skewed_output[i] = output_reg;
        end
    endgenerate
endmodule