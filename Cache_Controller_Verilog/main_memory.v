`timescale 1ns/1ps

module main_memory (
    input clk,
    input mem_req,
    input mem_we,
    input [15:0] mem_addr,
    input [31:0] mem_wdata,
    output [31:0] mem_rdata,
    output mem_ready
);

    reg [31:0] memory [0:65535];

    assign mem_rdata = memory[mem_addr];
    assign mem_ready = mem_req;

    always @(posedge clk) begin
        if (mem_req && mem_we)
            memory[mem_addr] <= mem_wdata;
    end

endmodule
