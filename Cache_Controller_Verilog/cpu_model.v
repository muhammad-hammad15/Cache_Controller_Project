`timescale 1ns/1ps

module cpu_model (
    input             clk,
    input             reset,
    // CPU-side interface
    input      [15:0] cpu_address,
    input             cpu_read,
    input             cpu_write,
    input      [31:0] cpu_write_data,
    output reg [31:0] cpu_read_data,
    // Cache-controller interface
    output reg        cache_req,
    output reg        cache_we,
    output reg [15:0] cache_addr,
    output reg [31:0] cache_wdata,
    input      [31:0] cache_rdata,
    input             cache_ready
);

    // Prevents the same HIGH cpu_read/cpu_write signal from generating more than one cache request.
    reg request_sent;

    always @(posedge clk or posedge reset) 
    begin
        if (reset) begin
            cache_req     <= 1'b0;
            cache_we      <= 1'b0;
            cache_addr    <= 16'd0;
            cache_wdata   <= 32'd0;
            cpu_read_data <= 32'd0;
            request_sent  <= 1'b0;
        end

        else 
        begin
            // cache_req is normally LOW.
            // It becomes HIGH for only one clock cycle when a new request starts.
            cache_req <= 1'b0;

            // When the CPU releases both controls,
            // allow the next CPU operation to generate a new request.
            if (!cpu_read && !cpu_write)
                request_sent <= 1'b0;

            // Send one new request to the cache controller.
            if ((cpu_read || cpu_write) && !request_sent) 
            begin

                cache_req   <= 1'b1;
                cache_we    <= cpu_write;       // 0 = READ, 1 = WRITE
                cache_addr  <= cpu_address;
                cache_wdata <= cpu_write_data;

                request_sent <= 1'b1;
            end


            // When the cache finishes a READ,
            // save the returned data for the CPU.
            // cache_we still represents the active request:
            //   0 = read request
            //   1 = write request
            if (cache_ready && !cache_we)
                cpu_read_data <= cache_rdata;

        end

    end

endmodule
