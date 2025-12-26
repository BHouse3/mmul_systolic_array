//Need to remove all parameters from the module to run through openlane

`timescale 1ns/1ps

module top_hardened (
    input wire clk,
    input wire reset,
    input wire load_weight, 
    input wire [31:0] input_tdata,
    input wire input_tvalid,
    output wire input_tready,
    output wire [127:0] output_tdata,
    output wire output_tvalid,
    input wire output_tready
);

    top #(
        .N(4),
        .DATA_WIDTH(8),
        .RESULT_WIDTH(32)
    ) top_inst (
        .clk(clk),
        .reset(reset),
        .load_weight(load_weight),
        .s_axis_tdata(input_tdata),
        .s_axis_tvalid(input_tvalid),
        .s_axis_tready(input_tready),
        .m_axis_tdata(output_tdata),
        .m_axis_tvalid(output_tvalid),
        .m_axis_tready(output_tready)
    );

endmodule
