`timescale 1ns/1ps

module main_memory (
    input             clk,
    input             mem_req,
    input             mem_we,        // 0 = read, 1 = write
    input      [15:0] mem_addr,
    input      [31:0] mem_wdata,
    output     [31:0] mem_rdata,
    output            mem_ready
);

    // 16-bit address space with 32-bit data at each address.
    reg [31:0] memory [0:65535];

    // combinational read path.
    assign mem_rdata = memory[mem_addr];

    // Synchronous memory write.
    always @(posedge clk) begin
        if (mem_req && mem_we)
            memory[mem_addr] <= mem_wdata;
    end

    // Request from Cache
    assign mem_ready = mem_req;

endmodule
