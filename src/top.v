`timescale 1ns/1ps

module top #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    
    input wire load_weight, 
    input wire [N*DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    output wire [N*RESULT_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready
);

    wire [N*DATA_WIDTH-1:0] flat_input_data;
    wire input_valid_internal;
    wire system_ready;
    wire [DATA_WIDTH-1:0] flat_data_unpacked [0:N-1];
    wire [DATA_WIDTH-1:0] skewed_data_unpacked [0:N-1];
    wire [DATA_WIDTH-1:0] grid_inputs [0:N-1];
    wire [RESULT_WIDTH-1:0] grid_sums_unpacked [0:N-1];
    wire [RESULT_WIDTH-1:0] deskewed_data_unpacked [0:N-1];
    wire [N*RESULT_WIDTH-1:0] flat_output_data;
    
    wire output_row_valid;
    wire output_row_ready;

    axi_stream_input #(
        .N(N), .data_width(DATA_WIDTH)
    ) axis_in_inst (
        .clk(clk), .reset(reset),
        .tdata(s_axis_tdata), .tvalid(s_axis_tvalid), .tready(s_axis_tready),
        .inbuf_bus(flat_input_data), 
        .inbuf_valid(input_valid_internal), 
        .inbuf_ready(system_ready) 
    );

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : unpack_flat
            assign flat_data_unpacked[i] = flat_input_data[(i*DATA_WIDTH) +: DATA_WIDTH];
        end
    endgenerate

    assign system_ready = output_row_ready;

    input_buffer #(
        .N(N), .data_width(DATA_WIDTH)
    ) skew_buff_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal && system_ready), 
        .streamed_input(flat_input_data),
        .skewed_output(skewed_data_unpacked)
    );

    //mux to bypass the input buffer if we are loading weights
    generate
        for (i = 0; i < N; i = i + 1) begin : mux_in
            assign grid_inputs[i] = (load_weight) ? flat_data_unpacked[i] : skewed_data_unpacked[i];
        end
    endgenerate

    grid #(
        .N(N), .data_width(DATA_WIDTH), .result_width(RESULT_WIDTH)
    ) grid_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal && system_ready), 
        .load_weight(load_weight),
        .inputs_left(grid_inputs), 
        .sums_bottom(grid_sums_unpacked)
    );

    output_buffer #(
        .N(N), .result_width(RESULT_WIDTH)
    ) deskew_buff_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal && system_ready), 
        .col_input(grid_sums_unpacked),
        .col_output(deskewed_data_unpacked)
    );

    generate
        for (i = 0; i < N; i = i + 1) begin : pack_output
            assign flat_output_data[(i*RESULT_WIDTH) +: RESULT_WIDTH] = deskewed_data_unpacked[i];
        end
    endgenerate

    //need a shift register to coordinate tvalid timing 
    localparam LATENCY = 2*N + 1; 
    reg [LATENCY-1:0] valid_pipe;
    always @(posedge clk) begin
        if (reset) begin
            valid_pipe <= {LATENCY{1'b0}};
        end 
        // only shift a 1 if the system is moving data and we aren't loading weights
        else if (system_ready && !load_weight) begin
            valid_pipe <= {valid_pipe[LATENCY-2:0], input_valid_internal};
        end
    end
    //tvalid assignment 
    assign output_row_valid = valid_pipe[LATENCY-1];

    axi_stream_output #(
        .N(N), .result_width(RESULT_WIDTH)
    ) axis_out_inst (
        .clk(clk), .reset(reset),
        .out_buff_data(flat_output_data), 
        .out_buff_enabled(output_row_valid), 
        .out_buff_enable_feedback(output_row_ready), 
        .tdata(m_axis_tdata), 
        .tvalid(m_axis_tvalid), 
        .tready(m_axis_tready)
    );

endmodule