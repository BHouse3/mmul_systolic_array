/*
 * Top level parameterized integration of all modules
*/
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
    wire [N*DATA_WIDTH-1:0] skewed_data_packed;
    wire [N*DATA_WIDTH-1:0] grid_inputs_packed;
    wire [N*RESULT_WIDTH-1:0] grid_sums_packed;
    wire [N*RESULT_WIDTH-1:0] deskewed_data_packed;
    wire output_row_valid;
    wire output_row_ready;

    axi_stream_input #(
        .N(N), .DATA_WIDTH(DATA_WIDTH)
    ) axis_in_inst (
        .clk(clk), .reset(reset),
        .tdata(s_axis_tdata), .tvalid(s_axis_tvalid), .tready(s_axis_tready),
        .inbuf_bus(flat_input_data), 
        .inbuf_valid(input_valid_internal), 
        .inbuf_ready(system_ready) 
    );

    assign system_ready = output_row_ready;

    input_buffer #(
        .N(N), .DATA_WIDTH(DATA_WIDTH)
    ) skew_buff_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal && system_ready), 
        .streamed_input(flat_input_data),
        .skewed_output(skewed_data_packed)
    );

    //mux to bypass the input buffer if we are loading weights
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : mux_in
            assign grid_inputs_packed[(i*DATA_WIDTH) +: DATA_WIDTH] = (load_weight) ? 
                flat_input_data[(i*DATA_WIDTH) +: DATA_WIDTH] : 
                skewed_data_packed[(i*DATA_WIDTH) +: DATA_WIDTH];
        end
    endgenerate

    grid #(
        .N(N), .DATA_WIDTH(DATA_WIDTH), .RESULT_WIDTH(RESULT_WIDTH)
    ) grid_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal && system_ready), 
        .load_weight(load_weight),
        .inputs_left(grid_inputs_packed), 
        .sums_bottom(grid_sums_packed)    
    );

    output_buffer #(
        .N(N), .RESULT_WIDTH(RESULT_WIDTH)
    ) deskew_buff_inst (
        .clk(clk), .reset(reset),
        .enable(input_valid_internal && system_ready), 
        .col_input(grid_sums_packed),   
        .col_output(deskewed_data_packed)  
    );

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
        .N(N), .RESULT_WIDTH(RESULT_WIDTH)
    ) axis_out_inst (
        .clk(clk), .reset(reset),
        .out_buff_data(deskewed_data_packed),
        .out_buff_enabled(output_row_valid), 
        .out_buff_enable_feedback(output_row_ready), 
        .tdata(m_axis_tdata), 
        .tvalid(m_axis_tvalid), 
        .tready(m_axis_tready)
    );

endmodule

