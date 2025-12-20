`timescale 1ns/1ps

module top #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    
    input wire load_weight, 

    // AXI4-Stream Slave (Input)
    input wire [N*DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,

    // AXI4-Stream Master (Output)
    output wire [N*RESULT_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready
);

    // Internal Signals
    wire [N*DATA_WIDTH-1:0]     flat_input_data;
    wire                        input_valid_internal;
    wire                        input_ready_internal;
    
    // Unpacked Arrays
    wire [DATA_WIDTH-1:0]       flat_data_unpacked [0:N-1]; // New: For weight loading
    wire [DATA_WIDTH-1:0]       skewed_data_unpacked [0:N-1];
    wire [DATA_WIDTH-1:0]       grid_inputs [0:N-1];        // New: Mux output
    wire [RESULT_WIDTH-1:0]     grid_sums_unpacked [0:N-1];
    wire [RESULT_WIDTH-1:0]     deskewed_data_unpacked [0:N-1];
    wire [N*RESULT_WIDTH-1:0]   flat_output_data;
    wire                        output_row_valid;
    wire                        output_row_ready;

    // 1. AXI Input Interface
    axi_stream_input #(
        .N(N), .data_width(DATA_WIDTH)
    ) axis_in_inst (
        .clk(clk), .reset(reset),
        .tdata(s_axis_tdata), .tvalid(s_axis_tvalid), .tready(s_axis_tready),
        .col_bus(flat_input_data), .col_valid(input_valid_internal), .col_ready(input_ready_internal)
    );

    // 2. Unpack Flat Data (For direct weight loading)
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : unpack_flat
            assign flat_data_unpacked[i] = flat_input_data[(i*DATA_WIDTH) +: DATA_WIDTH];
        end
    endgenerate

    // 3. Input Skew Buffer
    assign input_ready_internal = 1'b1; // Always accept
    input_buffer #(
        .N(N), .data_width(DATA_WIDTH)
    ) skew_buff_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal),
        .streamed_input(flat_input_data),
        .skewed_output(skewed_data_unpacked)
    );

    // 4. MUX: Bypass Skew Buffer if loading weights
    // This ensures weights arrive at all rows simultaneously
    generate
        for (i = 0; i < N; i = i + 1) begin : mux_in
            assign grid_inputs[i] = (load_weight) ? flat_data_unpacked[i] : skewed_data_unpacked[i];
        end
    endgenerate

    // 5. Systolic Grid
    grid #(
        .N(N), .data_width(DATA_WIDTH), .result_width(RESULT_WIDTH)
    ) grid_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal),
        .load_weight(load_weight),
        .inputs_left(grid_inputs), // Connected to Mux
        .sums_bottom(grid_sums_unpacked)
    );

    // 6. Output Deskew Buffer
    deskew_buffer #(
        .N(N), .result_width(RESULT_WIDTH)
    ) deskew_buff_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal),
        .col_input(grid_sums_unpacked),
        .col_output(deskewed_data_unpacked)
    );

    // 7. Packing Logic
    generate
        for (i = 0; i < N; i = i + 1) begin : pack_output
            assign flat_output_data[(i*RESULT_WIDTH) +: RESULT_WIDTH] = deskewed_data_unpacked[i];
        end
    endgenerate
    assign output_row_valid = input_valid_internal; 

    // 8. AXI Stream Output
    axi_stream_output #(
        .N(N), .result_width(RESULT_WIDTH)
    ) axis_out_inst (
        .clk(clk), .reset(reset),
        .row_bus(flat_output_data), .row_valid(output_row_valid), .row_ready(output_row_ready),
        .tdata(m_axis_tdata), .tvalid(m_axis_tvalid), .tready(m_axis_tready)
    );


endmodule