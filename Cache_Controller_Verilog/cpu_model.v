`timescale 1ns/1ps

module cpu_model (
    input clk,
    input reset,
    input [15:0] cpu_address,
    input cpu_read,
    input cpu_write,
    input [31:0] cpu_write_data,
    output reg [31:0] cpu_read_data,

    output reg cache_req,
    output reg cache_we,
    output reg [15:0] cache_addr,
    output reg [31:0] cache_wdata,
    input [31:0] cache_rdata,
    input cache_ready
);

    reg request_sent;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cache_req <= 1'b0;
            cache_we <= 1'b0;
            cache_addr <= 16'd0;
            cache_wdata <= 32'd0;
            cpu_read_data <= 32'd0;
            request_sent <= 1'b0;
        end
        else begin
            cache_req <= 1'b0;

            // new request is allowed after both controls go low
            if (!cpu_read && !cpu_write)
                request_sent <= 1'b0;

            if ((cpu_read || cpu_write) && !request_sent) begin
                cache_req <= 1'b1;
                cache_we <= cpu_write;
                cache_addr <= cpu_address;
                cache_wdata <= cpu_write_data;
                request_sent <= 1'b1;
            end

            // only read transactions return data to the CPU side
            if (cache_ready && !cache_we)
                cpu_read_data <= cache_rdata;
        end
    end

endmodule
