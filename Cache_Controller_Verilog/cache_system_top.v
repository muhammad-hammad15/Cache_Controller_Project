`timescale 1ns/1ps

module cache_system_top (
    input             clk,
    input             reset,

    input      [15:0] cpu_address,
    input             cpu_read,
    input             cpu_write,
    input      [31:0] cpu_write_data,

    output     [31:0] cpu_read_data
);
     
    // CPU MODEL <-> CACHE CONTROLLER
    wire        cache_req;
    wire        cache_we;
    wire [15:0] cache_addr;
    wire [31:0] cache_wdata;
    wire [31:0] cache_rdata;
    wire        cache_ready;
     
    // CACHE CONTROLLER <-> MAIN MEMORY
    wire        mem_req;
    wire        mem_we;
    wire [15:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire        mem_ready;
     
    // CPU MODEL
    cpu_model u_cpu_model (
        .clk            (clk),
        .reset          (reset),
        .cpu_address    (cpu_address),
        .cpu_read       (cpu_read),
        .cpu_write      (cpu_write),
        .cpu_write_data (cpu_write_data),
        .cpu_read_data  (cpu_read_data),
        .cache_req      (cache_req),
        .cache_we       (cache_we),
        .cache_addr     (cache_addr),
        .cache_wdata    (cache_wdata),
        .cache_rdata    (cache_rdata),
        .cache_ready    (cache_ready)
    );
     
    // CACHE CONTROLLER
    cache_controller u_cache_controller (
        .clk        (clk),
        .reset      (reset),
        .cpu_req    (cache_req),
        .cpu_we     (cache_we),
        .cpu_addr   (cache_addr),
        .cpu_wdata  (cache_wdata),
        .cpu_rdata  (cache_rdata),
        .cpu_ready  (cache_ready),
        .mem_req    (mem_req),
        .mem_we     (mem_we),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_rdata  (mem_rdata),
        .mem_ready  (mem_ready)
    );
     
    // SIMPLE MAIN MEMORY
    main_memory u_main_memory (
        .clk       (clk),
        .mem_req   (mem_req),
        .mem_we    (mem_we),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );

endmodule
