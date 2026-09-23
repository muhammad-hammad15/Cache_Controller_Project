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

`timescale 1ns/1ps

module cache_controller (
    input             clk,
    input             reset,
    // CPU-model side
    input             cpu_req,
    input             cpu_we,          // 0 = read, 1 = write
    input      [15:0] cpu_addr,
    input      [31:0] cpu_wdata,
    output reg [31:0] cpu_rdata,
    output reg        cpu_ready,
    // Main-memory side
    output reg        mem_req,
    output reg        mem_we,           // 0 = read, 1 = write
    output reg [15:0] mem_addr,
    output reg [31:0] mem_wdata,
    input      [31:0] mem_rdata,
    input             mem_ready);

    // CACHE STORAGE
    // Four entries per way = four sets.
    reg [13:0] tag_way0  [0:3];
    reg [13:0] tag_way1  [0:3];

    reg [31:0] data_way0 [0:3];
    reg [31:0] data_way1 [0:3];

    reg valid_way0 [0:3];
    reg valid_way1 [0:3];

    // 2-way LRU metadata for each set:
    //   0 -> Way 0 is the LRU victim
    //   1 -> Way 1 is the LRU victim
    reg lru_way [0:3];

    
    // LATCHED CPU REQUEST
    reg [15:0] req_addr;
    reg [31:0] req_wdata;
    reg        req_we;

    wire [1:0]  req_index;
    wire [13:0] req_tag;

    wire hit_way0;
    wire hit_way1;

    assign req_index = req_addr[1:0];
    assign req_tag   = req_addr[15:2];

    assign hit_way0 =
        valid_way0[req_index] &&
        (tag_way0[req_index] == req_tag);

    assign hit_way1 =
        valid_way1[req_index] &&
        (tag_way1[req_index] == req_tag);
    

    // FSM STATE ENCODING
    localparam [1:0] IDLE      = 2'b00;
    localparam [1:0] LOOKUP    = 2'b01;
    localparam [1:0] MEM_READ  = 2'b10;
    localparam [1:0] MEM_WRITE = 2'b11;

    reg [1:0] state;

    integer set_i;

    
    // MEMORY COMMAND GENERATION
    // req_addr and req_wdata hold the original CPU request. In MEM_READ or MEM_WRITE they are forwarded to main memory.   
    always @(*) begin
        mem_req   = 1'b0;
        mem_we    = 1'b0;
        mem_addr  = req_addr;
        mem_wdata = req_wdata;

        case (state)
            MEM_READ: begin
                mem_req = 1'b1;
                mem_we  = 1'b0;
            end

            MEM_WRITE: begin
                mem_req = 1'b1;
                mem_we  = 1'b1;
            end

        endcase
    end

    
    // MAIN SEQUENTIAL LOGIC
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            req_addr  <= 16'd0;
            req_wdata <= 32'd0;
            req_we    <= 1'b0;

            cpu_rdata <= 32'd0;
            cpu_ready <= 1'b0;

            // Reset invalidates every cache line and initializes LRU metadata.
            // Tag/data values do not need reset because valid bits determine whether a cache line contains usable information.
            for (set_i = 0; set_i < 4; set_i = set_i + 1) begin
                valid_way0[set_i] <= 1'b0;
                valid_way1[set_i] <= 1'b0;
                lru_way[set_i]    <= 1'b0;
            end
        end
        else begin
            // cpu_ready is a one-clock completion pulse.
            cpu_ready <= 1'b0;

            case (state)

                 
                // IDLE: wait for a new CPU request
                IDLE: begin
                    if (cpu_req) begin
                        req_addr  <= cpu_addr;
                        req_wdata <= cpu_wdata;
                        req_we    <= cpu_we;
                        state     <= LOOKUP;
                    end
                end


                // LOOKUP: compare both ways of the selected set
                LOOKUP: begin

                    //  READ 
                    if (!req_we) begin
                        if (hit_way0) begin
                            cpu_rdata <= data_way0[req_index];
                            cpu_ready <= 1'b1;

                            // Way 0 becomes MRU, so Way 1 becomes LRU.
                            lru_way[req_index] <= 1'b1;
                            state <= IDLE;
                        end
                        else if (hit_way1) begin
                            cpu_rdata <= data_way1[req_index];
                            cpu_ready <= 1'b1;

                            // Way 1 becomes MRU, so Way 0 becomes LRU.
                            lru_way[req_index] <= 1'b0;
                            state <= IDLE;
                        end
                        else begin
                            // Read miss: fetch the block from main memory.
                            state <= MEM_READ;
                        end
                    end

                    //  WRITE 
                    else begin
                        // Write hit in Way 0: update the cached copy and LRU.
                        if (hit_way0) begin
                            data_way0[req_index] <= req_wdata;
                            lru_way[req_index]   <= 1'b1;
                        end
                        // Write hit in Way 1: update the cached copy and LRU.
                        else if (hit_way1) begin
                            data_way1[req_index] <= req_wdata;
                            lru_way[req_index]   <= 1'b0;
                        end

                        /* On a write miss, neither cache way is changed. Every write still goes to main memory 
                           because the policy is Write-Through. Therefore both write hits
                           and write misses continue to MEM_WRITE.*/
                        state <= MEM_WRITE;
                    end
                end

                 
                // MEM_READ: allocate data after a read miss
                MEM_READ: begin
                    if (mem_ready) begin

                        // Prefer an invalid Way 0 before replacing anything.
                        if (!valid_way0[req_index]) begin
                            tag_way0[req_index]   <= req_tag;
                            data_way0[req_index]  <= mem_rdata;
                            valid_way0[req_index] <= 1'b1;

                            // Way 0 is now MRU -> Way 1 is LRU.
                            lru_way[req_index] <= 1'b1;
                        end

                        // Otherwise use invalid Way 1.
                        else if (!valid_way1[req_index]) begin
                            tag_way1[req_index]   <= req_tag;
                            data_way1[req_index]  <= mem_rdata;
                            valid_way1[req_index] <= 1'b1;

                            // Way 1 is now MRU -> Way 0 is LRU.
                            lru_way[req_index] <= 1'b0;
                        end

                        // Both ways valid: replace the LRU way.
                        else if (lru_way[req_index] == 1'b0) begin
                            tag_way0[req_index]   <= req_tag;
                            data_way0[req_index]  <= mem_rdata;
                            valid_way0[req_index] <= 1'b1;

                            // New Way 0 entry is MRU -> Way 1 is LRU.
                            lru_way[req_index] <= 1'b1;
                        end
                        else begin
                            tag_way1[req_index]   <= req_tag;
                            data_way1[req_index]  <= mem_rdata;
                            valid_way1[req_index] <= 1'b1;

                            // New Way 1 entry is MRU -> Way 0 is LRU.
                            lru_way[req_index] <= 1'b0;
                        end

                        // Return fetched memory data to the CPU.
                        cpu_rdata <= mem_rdata;
                        cpu_ready <= 1'b1;
                        state     <= IDLE;
                    end
                end

                 
                // MEM_WRITE: Write-Through to main memory
                MEM_WRITE: begin
                    // mem_req=1 and mem_we=1 are generated combinationally
                    // while the FSM is in this state. main_memory performs the
                    // actual memory write. When mem_ready is high, the CPU
                    // request is complete.
                    if (mem_ready) begin
                        cpu_ready <= 1'b1;
                        state     <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

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
