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
module deskew_buffer #(
    parameter N = 4,
    parameter result_width = 32
)(
    input wire clk,
    input wire reset,
    input wire enable,
    // input wire [N*result_width-1:0] skewed_input,
    // output wire [N*result_width-1:0] flat_output
    input wire [result_width-1:0] col_input [0:N-1],
    output wire [result_width-1:0] col_output [0:N-1]
);

    // wire [result_width-1:0] in_cols [0:N-1];
    // genvar i;
    // generate
    //     for (i = 0; i < N; i = i + 1) begin : unpack
    //         assign in_cols[i] = skewed_input[(i*result_width) +: result_width];
    //     end
    // endgenerate

    // Triangular Delay Registers
    // Col 0 needs N-1 delays. Col N-1 needs 0.
    // reg [result_width-1:0] delay_regs [0:N-1][0:N-1];

    // integer c, d;
    // always @(posedge clk ) begin
    //     if (reset) begin
    //         for (c = 0; c < N; c = c + 1) begin
    //             for (d = 0; d < N; d = d + 1) begin
    //                 delay_regs[c][d] <= {result_width{1'b0}};
    //             end
    //         end
    //     end else begin
    //         for (c = 0; c < N-1; c = c + 1) begin // Last col needs no regs
    //             // Chain head
    //             delay_regs[c][0] <= in_cols[c];
    //             // Chain body
    //             for (d = 1; d < (N-1-c); d = d + 1) begin
    //                 delay_regs[c][d] <= delay_regs[c][d-1];
    //             end
    //         end
    //     end
    // end

    // genvar k;
    // generate
    //     // Col N-1 is pass-through
    //     assign flat_output[((N-1)*result_width) +: result_width] = in_cols[N-1];
        
    //     // Other cols take from the end of their delay chain
    //     for (k = 0; k < N-1; k = k + 1) begin : pack
    //         // The chain length for col k is (N-1-k)
    //         // The last index is (N-1-k) - 1
    //         assign flat_output[(k*result_width) +: result_width] = delay_regs[k][N-1-k-1];
    //     end
    // endgenerate


    //deskew logic is similar to skew logic, just inverted 
    genvar i,j;
    generate
        for (i=0; i < N; i = i+1) begin : row
            for (j=0; j < N-1-i; j = j+1) begin : stage
                reg [result_width-1:0] delay;
                if (j==0) begin
                    always @(posedge clk ) begin
                        if (reset) delay <= {result_width{1'b0}};
                        else if (enable) delay <= col_input[i];
                    end
                end 
                else begin
                    always @(posedge clk ) begin
                        if (reset) delay <= {result_width{1'b0}};
                        else if (enable) delay <= row[i].stage[j-1].delay;
                    end
                end
            end

            // output register for each row
            //updates on the clk which enforces alignment to the clk signal
            reg [result_width-1:0] output_reg;
            always @(posedge clk) begin
                if (reset) output_reg <= {result_width{1'b0}};
                else if (enable) begin
                    if (i==(N-1)) output_reg <= col_input[N-1];  
                    else output_reg <= row[i].stage[N-2-i].delay;
                end
            end
            assign col_output[i] = output_reg;
        end
    endgenerate
endmodule