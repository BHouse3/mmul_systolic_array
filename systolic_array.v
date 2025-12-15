`timescale 1ns/1ps

module systolic_top #(
    parameter N = 4,
    parameter D_W = 8,
    parameter A_W = 32
)(
    input wire clk,
    input wire reset,
    input wire load_weight,      // Control Signal
    input wire data_enable,      // Control Signal for Skew Buffer
    input wire [N*D_W-1:0] data_in, // Flat column input
    output wire [N*A_W-1:0] sum_out // Flat row output (Deskwed)
);

    // 1. Skew Buffer Signals
    wire [N*D_W-1:0] skewed_data_wire;
    
    skew_buffer #(.N(N), .D_W(D_W)) input_skew (
        .clk(clk),
        .reset(reset),
        .enable(data_enable),
        .flat_input(data_in),
        .skewed_output(skewed_data_wire)
    );

    // 2. Systolic Array Signals
    wire [N*A_W-1:0] raw_array_out;
    wire [N*A_W-1:0] zeros_top = {(N*A_W){1'b0}}; // Initialize top sums to 0

    systolic_array #(.N(N), .D_W(D_W), .A_W(A_W)) array_core (
        .clk(clk),
        .reset(reset),
        .load_weight(load_weight),
        .inputs_left(skewed_data_wire),
        .sums_top(zeros_top),
        .sums_bottom(raw_array_out)
    );

    // 3. Deskew Buffer
    deskew_buffer #(.N(N), .A_W(A_W)) output_deskew (
        .clk(clk),
        .reset(reset),
        .skewed_input(raw_array_out),
        .flat_output(sum_out)
    );

endmodule


module pe #(
    parameter D_W = 8,  // Data Width (Activations/Weights)
    parameter A_W = 32  // Accumulator Width (Sums)
)(
    input wire clk,
    input wire reset,
    input wire load_weight,
    input wire [D_W-1:0] activ_input,  
    input wire [A_W-1:0] top_sum_input, 
    output reg [D_W-1:0] activ_output,  
    output reg [A_W-1:0] sum_output
);

    reg [D_W-1:0] weight_reg;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            weight_reg   <= {D_W{1'b0}};
            activ_output <= {D_W{1'b0}};
            sum_output   <= {A_W{1'b0}};
        end else begin
            if (load_weight) begin
                // Pass weights through for daisy-chain loading
                weight_reg   <= activ_input;
                activ_output <= activ_input; 
            end else begin
                // Standard MAC operation
                activ_output <= activ_input;
                // Cast to signed to ensure correct math interpretation
                sum_output   <= $signed(top_sum_input) + 
                                ($signed(activ_input) * $signed(weight_reg));
            end
        end
    end
endmodule

module systolic_array #(
    parameter N = 4,
    parameter D_W = 8,
    parameter A_W = 32
)(
    input wire clk,
    input wire reset,
    input wire load_weight,
    input wire [N*D_W-1:0] inputs_left, // Column data entering from left
    input wire [N*A_W-1:0] sums_top,    // Partial sums entering from top (usually 0)
    output wire [N*A_W-1:0] sums_bottom // Results exiting bottom
);

    // Unpack inputs
    wire [D_W-1:0] rows_in [0:N-1];
    wire [A_W-1:0] cols_in [0:N-1];
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : unpack
            assign rows_in[k] = inputs_left[(k*D_W) +: D_W];
            assign cols_in[k] = sums_top[(k*A_W) +: A_W];
        end
    endgenerate
    
    // Interconnect wires
    wire [D_W-1:0] pe_h_wires [0:N][0:N]; 
    wire [A_W-1:0] pe_v_wires [0:N][0:N];

    // Drive edges
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : drive_left
            assign pe_h_wires[i][0] = rows_in[i];
        end
        for (j = 0; j < N; j = j + 1) begin : drive_top
            assign pe_v_wires[0][j] = cols_in[j];
        end
    endgenerate

    // Instantiate PEs
    generate
        for (i = 0; i < N; i = i + 1) begin : rows
            for (j = 0; j < N; j = j + 1) begin : cols
                pe #(
                    .D_W(D_W),
                    .A_W(A_W)
                ) pe_inst (
                    .clk(clk),
                    .reset(reset),
                    .load_weight(load_weight),
                    .activ_input(pe_h_wires[i][j]),
                    .top_sum_input(pe_v_wires[i][j]),
                    .activ_output(pe_h_wires[i][j+1]),
                    .sum_output(pe_v_wires[i+1][j])
                );
            end
        end
    endgenerate

    // Pack outputs
    generate
        for (j = 0; j < N; j = j + 1) begin : pack_out
            assign sums_bottom[(j*A_W) +: A_W] = pe_v_wires[N][j];
        end
    endgenerate
endmodule

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

endmodule

module deskew_buffer #(
    parameter N = 4,
    parameter A_W = 32
)(
    input wire clk,
    input wire reset, // Note: No enable needed usually, just runs
    input wire [N*A_W-1:0] skewed_input,
    output wire [N*A_W-1:0] flat_output
);

    wire [A_W-1:0] in_cols [0:N-1];
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : unpack
            assign in_cols[i] = skewed_input[(i*A_W) +: A_W];
        end
    endgenerate

    // Triangular Delay Registers
    // Col 0 needs N-1 delays. Col N-1 needs 0.
    reg [A_W-1:0] delay_regs [0:N-1][0:N-1];

    integer c, d;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (c = 0; c < N; c = c + 1) begin
                for (d = 0; d < N; d = d + 1) begin
                    delay_regs[c][d] <= {A_W{1'b0}};
                end
            end
        end else begin
            for (c = 0; c < N-1; c = c + 1) begin // Last col needs no regs
                // Chain head
                delay_regs[c][0] <= in_cols[c];
                // Chain body
                for (d = 1; d < (N-1-c); d = d + 1) begin
                    delay_regs[c][d] <= delay_regs[c][d-1];
                end
            end
        end
    end

    genvar k;
    generate
        // Col N-1 is pass-through
        assign flat_output[((N-1)*A_W) +: A_W] = in_cols[N-1];
        
        // Other cols take from the end of their delay chain
        for (k = 0; k < N-1; k = k + 1) begin : pack
            // The chain length for col k is (N-1-k)
            // The last index is (N-1-k) - 1
            assign flat_output[(k*A_W) +: A_W] = delay_regs[k][N-1-k-1];
        end
    endgenerate

endmodule


// module data_streamer #(
//     parameter N = 4,
//     parameter D_W = 8,
//     parameter MEM_DEPTH = 16
// )(
//     input wire clk,
//     input wire reset,
//     input wire start_stream,
//     output wire [N*D_W-1:0] data_to_buffer,
//     output wire valid_data
// );

//     reg [N*D_W-1:0] memory [0:MEM_DEPTH-1];
//     reg [$clog2(MEM_DEPTH)-1:0] addr_ptr;
//     reg streaming;

//     integer i;
//     initial begin
//         for (i = 0; i < MEM_DEPTH; i = i + 1) begin
//             memory[i] = {(N*D_W){1'b0}}; // Default 0
//         end
//         memory[0] = 32'h01010101; 
//         memory[1] = 32'h02020202;
//         memory[2] = 32'h03030303; 
//         memory[3] = 32'h04040404;
//     end

//     assign data_to_buffer = (streaming) ? memory[addr_ptr] : {N*D_W{1'b0}};
//     assign valid_data = streaming;

//     always @(posedge clk or negedge reset) begin
//         if (!reset) begin
//             addr_ptr <= 0;
//             streaming <= 0;
//         end else begin
//             if (start_stream && !streaming) begin
//                 streaming <= 1;
//                 addr_ptr <= 0;
//             end else if (streaming) begin
//                 if (addr_ptr == MEM_DEPTH - 1) begin
//                     streaming <= 0;
//                 end else begin
//                     addr_ptr <= addr_ptr + 1;
//                 end
//             end
//         end
//     end

// endmodule

// module top_system_integration (
//     input wire clk,
//     input wire reset,
//     input wire load_weight_cmd, 
//     // input wire start_compute_cmd,
//     input wire [31:0] weight_data_in, 
//     output wire [63:0] final_results
// );

//     wire [31:0] mem_data_out;
//     wire [31:0] skewed_data_out;
//     wire valid_stream;
    
//     wire [31:0] array_inputs;
    
//     assign array_inputs = (load_weight_cmd) ? weight_data_in : skewed_data_out;

//     data_streamer u_mem (
//         .clk(clk),
//         .reset(reset),
//         .start_stream(start_compute_cmd),
//         .data_to_buffer(mem_data_out),
//         .valid_data(valid_stream)
//     );

//     skew_buffer u_skew (
//         .clk(clk),
//         .reset(reset),
//         .enable(valid_stream), 
//         .flat_input(mem_data_out),
//         .skewed_output(skewed_data_out)
//     );

//     systolic_array u_array (
//         .clk(clk),
//         .reset(reset),
//         .load_weight(load_weight_cmd),
//         .activations(array_inputs),
//         .sum_inputs(64'b0),
//         .sum_output(final_results)
//     );

// endmodule