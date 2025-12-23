/*
 * we require a smart interface for providing the data to the input buffer
 * If we blindly blast data into the buffer, we run the risk of overwriting data
 * But we also need the interface to not bottleneck the system such that we can actually sense the real performance of the systolic array
 * 
 * AXI-stream is a simple interface that solves this coordination
 * It uses a handshake between producer and consumer to initiate data transfer
 * Producer and consumer share a clk and reset
 * The source produces the TVALID and TDATA signals 
 * The consumer produces the TREADY signals
 * Data transfer begins on posedge clk when Tvalid=1 and tready=1 (the only time tdata can be consumed)
 * If the consumer isn't ready, it keeps tready low. If the producer isn't ready then it keeps tvalid low.
*/
`timescale 1ns/1ps


//axi-stream slave
module axi_stream_input #(
    parameter N = 4,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset,
    input wire [N*DATA_WIDTH-1:0] tdata,
    input wire tvalid,
    output wire tready,
    output reg [N*DATA_WIDTH-1:0] inbuf_bus,
    output reg inbuf_valid,
    input wire inbuf_ready
);
    //we are ready to accept data if our data is not valid
    //or if input buffer is ready/enabled
    assign tready = ~inbuf_valid || inbuf_ready;

    always @(posedge clk) begin
        if (reset) begin
            inbuf_valid <= 1'b0;
            inbuf_bus <= {N*DATA_WIDTH{1'b0}};
        end 
        else begin
            if (tready && tvalid) begin
                inbuf_bus <= tdata;
                inbuf_valid <= 1'b1;
            end 
            else if (inbuf_ready) begin
                inbuf_valid <= 1'b0; 
            end
        end
    end
endmodule


// axi-stream master
module axi_stream_output #(
    parameter N = 4,
    parameter result_width = 32
)(
    input wire clk,
    input wire reset,
    input wire [N*result_width-1:0] out_buff_data,
    input wire out_buff_enabled,
    output wire out_buff_enable_feedback,
    output reg [N*result_width-1:0] tdata,
    output reg tvalid,
    input wire tready
);
    // we accept the output buffer data if our tdata is invalid or if the slave is ready
    // otherwise, we don't latch new values into the tdata registers
    wire transaction_ready;
    assign transaction_ready = (tready || !tvalid);

    //feedback enable signal to the system
    //if the axi slave is not ready to accept data, then the system must pause 
    assign out_buff_enable_feedback = transaction_ready;

    always @(posedge clk) begin
        if (reset) begin
            tvalid <= 1'b0;
            tdata  <= {N*result_width{1'b0}};
        end 
        else begin
            // clear the valid when the handshake occurs
            if (tvalid && tready) begin
                tvalid <= 1'b0;
            end
            //accept data if the buffer is enabled or we are ready to accept
            if (transaction_ready && out_buff_enabled) begin
                tdata  <= out_buff_data;
                tvalid <= 1'b1; 
            end
        end
    end
endmodule


/*
 * For testing purposes only
 * A top level wrapper to verify the axi_stream logic using both
 * the master and slave implementations in communication with each
 * testbench serves as datafeed to master and monitors the slave output
*/

module axi_stream_wrapper #(
    parameter N = 4,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset,

    input wire [N*DATA_WIDTH-1:0] outbuf_data,
    input wire outbuf_valid,
    output wire outbuf_ready,    

    output wire [N*DATA_WIDTH-1:0] inbuf_data,
    output wire inbuf_valid,
    input wire inbuf_ready
);

    wire [N*DATA_WIDTH-1:0] tdata;
    wire tvalid;
    wire tready;

    axi_stream_output #(
        .N(N),
        .result_width(DATA_WIDTH)
    ) master_inst (
        .clk(clk),
        .reset(reset),
        .out_buff_data(outbuf_data),
        .out_buff_enabled(outbuf_valid),
        .out_buff_enable_feedback(outbuf_ready),
        .tdata(tdata),
        .tvalid(tvalid),
        .tready(tready)
    );

    axi_stream_input #(
        .N(N),
        .data_width(DATA_WIDTH)
    ) slave_inst (
        .clk(clk),
        .reset(reset),
        .tdata(tdata),
        .tvalid(tvalid),
        .tready(tready),
        .inbuf_bus(inbuf_data),
        .inbuf_valid(inbuf_valid),
        .inbuf_ready(inbuf_ready)
    );
endmodule