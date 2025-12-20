/*
 * we require a smart interface for providing the data to the input buffer
 * If we blindly blast data into the buffer, we run the risk of overwriting data
 * But we also need the interface to not bottleneck the system such that we can actually sense the real performance of the systolic array
 * 
 * AXI-stream is a simply interface that solves this coordination
 * It uses a handshake between producer and consumer to initiate data transfer
 * Producer and consumer share a clk and reset
 * The source produces the TVALID and TDATA signals 
 * The consumer produces the TREADY signals
 * Data transfer begins on posedge clk when Tvalid=1 and tready=1 (the only time tdata can be consumed)
 * If the consumer isn't ready, it keeps tready low. If the producer isn't ready then it keeps tvalid low.
*/
`timescale 1ns/1ps
/*
 * AXI-Stream Input Interface
 * Captures data from an upstream AXI master and presents it to the internal logic (Input Buffer).
 * Implements a simple register slice to decouple timing.
 */
module axi_stream_input #(
    parameter N = 4,
    parameter data_width = 8
)(
    input wire clk,
    input wire reset,
    
    // AXI4-Stream Slave Interface
    input wire [N*data_width-1:0] tdata,
    input wire tvalid,
    output reg tready,

    // Internal Interface (Source to Input Buffer)
    output reg [N*data_width-1:0] col_bus,
    output reg col_valid,
    input wire col_ready
);

    // Internal storage
    reg [N*data_width-1:0] internal_data;
    reg internal_valid;

    /* * AXI Handshake Logic:
     * We are ready to accept new data if:
     * 1. We don't have valid data currently holding (internal_valid == 0)
     * 2. OR, the downstream logic (Input Buffer) is ready to accept our holding data
     */
    always @(*) begin
        tready = (~internal_valid) || col_ready;
    end

    /*
     * Data Path & Valid Logic
     */
    always @(posedge clk) begin
        if (reset) begin
            internal_valid <= 1'b0;
            internal_data <= 'b0;
        end else begin
            // Load internal register if we are ready and source is valid
            if (tready && tvalid) begin
                internal_data <= tdata;
                internal_valid <= 1'b1;
            end 
            // Clear valid if downstream accepts the data and we don't have new data incoming
            else if (col_ready) begin
                internal_valid <= 1'b0; 
            end
        end
    end

    // Connect internal registers to output ports
    always @(*) begin
        col_bus = internal_data;
        col_valid = internal_valid;
    end

endmodule


/*
 * AXI-Stream Output Interface
 * Takes data from internal logic (Output Buffer) and streams it to a downstream AXI slave.
 */
module axi_stream_output #(
    parameter N = 4,
    parameter result_width = 32
)(
    input wire clk,
    input wire reset,

    // Internal Interface (Sink from Output Buffer)
    input wire [N*result_width-1:0] row_bus,
    input wire row_valid,
    output reg row_ready,

    // AXI4-Stream Master Interface
    output reg [N*result_width-1:0] tdata,
    output reg tvalid,
    input wire tready
);

    /*
     * Handshake Logic:
     * We are ready to accept from internal logic if:
     * 1. We aren't currently trying to send data (tvalid == 0)
     * 2. OR, the downstream AXI slave is accepting our current data (tready == 1)
     */
    always @(*) begin
        row_ready = (~tvalid) || tready;
    end

    /*
     * Data Path
     */
    always @(posedge clk) begin
        if (reset) begin
            tvalid <= 1'b0;
            tdata <= 'b0;
        end else begin
            // If we are ready and upstream has data, latch it
            if (row_ready && row_valid) begin
                tvalid <= 1'b1;
                tdata <= row_bus;
            end 
            // If downstream accepts data, and we didn't just latch new data, clear valid
            else if (tready) begin
                tvalid <= 1'b0;
            end
        end
    end

endmodule



    

