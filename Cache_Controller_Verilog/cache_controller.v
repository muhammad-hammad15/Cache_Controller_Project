`timescale 1ns/1ps

module cache_controller (
    input clk,
    input reset,

    input cpu_req,
    input cpu_we,
    input [15:0] cpu_addr,
    input [31:0] cpu_wdata,
    output reg [31:0] cpu_rdata,
    output reg cpu_ready,

    output reg mem_req,
    output reg mem_we,
    output reg [15:0] mem_addr,
    output reg [31:0] mem_wdata,
    input [31:0] mem_rdata,
    input mem_ready
);

    // 4 sets, 2 ways
    reg [13:0] tag_way0 [0:3];
    reg [13:0] tag_way1 [0:3];
    reg [31:0] data_way0 [0:3];
    reg [31:0] data_way1 [0:3];
    reg valid_way0 [0:3];
    reg valid_way1 [0:3];
    reg lru_way [0:3];

    reg [15:0] req_addr;
    reg [31:0] req_wdata;
    reg req_we;

    wire [1:0] req_index = req_addr[1:0];
    wire [13:0] req_tag = req_addr[15:2];

    wire hit_way0 = valid_way0[req_index] && (tag_way0[req_index] == req_tag);
    wire hit_way1 = valid_way1[req_index] && (tag_way1[req_index] == req_tag);

    localparam [1:0] IDLE = 2'b00,
                     LOOKUP = 2'b01,
                     MEM_READ = 2'b10,
                     MEM_WRITE = 2'b11;

    reg [1:0] state;
    integer set_i;

    // memory side control is based on the current FSM state
    always @(*) begin
        mem_req = 1'b0;
        mem_we = 1'b0;
        mem_addr = req_addr;
        mem_wdata = req_wdata;

        case (state)
            MEM_READ: begin
                mem_req = 1'b1;
                mem_we = 1'b0;
            end
            MEM_WRITE: begin
                mem_req = 1'b1;
                mem_we = 1'b1;
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            req_addr <= 16'd0;
            req_wdata <= 32'd0;
            req_we <= 1'b0;
            cpu_rdata <= 32'd0;
            cpu_ready <= 1'b0;

            for (set_i = 0; set_i < 4; set_i = set_i + 1) begin
                valid_way0[set_i] <= 1'b0;
                valid_way1[set_i] <= 1'b0;
                lru_way[set_i] <= 1'b0;
            end
        end
        else begin
            cpu_ready <= 1'b0;

            case (state)
                IDLE: begin
                    if (cpu_req) begin
                        req_addr <= cpu_addr;
                        req_wdata <= cpu_wdata;
                        req_we <= cpu_we;
                        state <= LOOKUP;
                    end
                end

                LOOKUP: begin
                    if (!req_we) begin
                        if (hit_way0) begin
                            cpu_rdata <= data_way0[req_index];
                            cpu_ready <= 1'b1;
                            lru_way[req_index] <= 1'b1;
                            state <= IDLE;
                        end
                        else if (hit_way1) begin
                            cpu_rdata <= data_way1[req_index];
                            cpu_ready <= 1'b1;
                            lru_way[req_index] <= 1'b0;
                            state <= IDLE;
                        end
                        else begin
                            state <= MEM_READ;
                        end
                    end
                    else begin
                        // write hit changes cache, write miss does not
                        if (hit_way0) begin
                            data_way0[req_index] <= req_wdata;
                            lru_way[req_index] <= 1'b1;
                        end
                        else if (hit_way1) begin
                            data_way1[req_index] <= req_wdata;
                            lru_way[req_index] <= 1'b0;
                        end

                        // write-through: every write also goes to memory
                        state <= MEM_WRITE;
                    end
                end

                MEM_READ: begin
                    if (mem_ready) begin
                        if (!valid_way0[req_index]) begin
                            tag_way0[req_index] <= req_tag;
                            data_way0[req_index] <= mem_rdata;
                            valid_way0[req_index] <= 1'b1;
                            lru_way[req_index] <= 1'b1;
                        end
                        else if (!valid_way1[req_index]) begin
                            tag_way1[req_index] <= req_tag;
                            data_way1[req_index] <= mem_rdata;
                            valid_way1[req_index] <= 1'b1;
                            lru_way[req_index] <= 1'b0;
                        end
                        else if (lru_way[req_index] == 1'b0) begin
                            tag_way0[req_index] <= req_tag;
                            data_way0[req_index] <= mem_rdata;
                            valid_way0[req_index] <= 1'b1;
                            lru_way[req_index] <= 1'b1;
                        end
                        else begin
                            tag_way1[req_index] <= req_tag;
                            data_way1[req_index] <= mem_rdata;
                            valid_way1[req_index] <= 1'b1;
                            lru_way[req_index] <= 1'b0;
                        end

                        cpu_rdata <= mem_rdata;
                        cpu_ready <= 1'b1;
                        state <= IDLE;
                    end
                end

                MEM_WRITE: begin
                    if (mem_ready) begin
                        cpu_ready <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
