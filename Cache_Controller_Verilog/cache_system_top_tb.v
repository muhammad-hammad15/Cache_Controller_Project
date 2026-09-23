`timescale 1ns/1ps

module cache_system_top_tb;

    reg clk, reset;
    reg cpu_read, cpu_write;
    reg [15:0] cpu_address;
    reg [31:0] cpu_write_data;
    wire [31:0] cpu_read_data;

    integer memory_read_count;
    integer memory_write_count;
    integer passed_tests, failed_tests;
    integer i;

    reg test_pass [1:15];

    cache_system_top DUT (
        .clk(clk),
        .reset(reset),
        .cpu_address(cpu_address),
        .cpu_read(cpu_read),
        .cpu_write(cpu_write),
        .cpu_write_data(cpu_write_data),
        .cpu_read_data(cpu_read_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("cache.vcd");
        $dumpvars(0, cache_system_top_tb);
    end

    // count actual memory transactions
    always @(posedge clk) begin
        if (!reset && DUT.mem_req) begin
            if (DUT.mem_we)
                memory_write_count = memory_write_count + 1;
            else
                memory_read_count = memory_read_count + 1;
        end
    end

    task read_test;
        input [31:0] test_no;
        input [8*48-1:0] test_name;
        input [15:0] address;
        input [31:0] expected_data;
        input expected_hit;

        reg [1:0] index;
        reg [13:0] tag;
        reg h0, h1, actual_hit;
        integer before_reads;
        integer reads_used;

        begin
            index = address[1:0];
            tag = address[15:2];

            h0 = DUT.u_cache_controller.valid_way0[index] &&
                 (DUT.u_cache_controller.tag_way0[index] == tag);
            h1 = DUT.u_cache_controller.valid_way1[index] &&
                 (DUT.u_cache_controller.tag_way1[index] == tag);

            actual_hit = h0 | h1;
            before_reads = memory_read_count;

            cpu_address = address;
            cpu_write = 0;
            cpu_read = 1;
            #50;
            cpu_read = 0;
            #20;

            reads_used = memory_read_count - before_reads;

            $display("");
            $display("------------------------------------------------------------");
            $display("TEST %0d : %s", test_no, test_name);
            $display("READ addr=%h  index=%0d  tag=%h", address, index, tag);
            $display("way0 hit=%0b  way1 hit=%0b  cache hit=%0b", h0, h1, actual_hit);
            $display("memory reads=%0d  cpu data=%h", reads_used, cpu_read_data);

            test_pass[test_no] = 1'b1;
            if (actual_hit !== expected_hit)
                test_pass[test_no] = 1'b0;
            if (cpu_read_data !== expected_data)
                test_pass[test_no] = 1'b0;
            if (expected_hit && reads_used != 0)
                test_pass[test_no] = 1'b0;
            if (!expected_hit && reads_used != 1)
                test_pass[test_no] = 1'b0;

            if (actual_hit)
                $display("operation = READ HIT");
            else
                $display("operation = READ MISS");

            if (test_pass[test_no])
                $display("status = PASS");
            else
                $display("status = FAIL");
        end
    endtask

    task write_test;
        input [31:0] test_no;
        input [8*48-1:0] test_name;
        input [15:0] address;
        input [31:0] write_data;
        input expected_hit;

        reg [1:0] index;
        reg [13:0] tag;
        reg h0, h1, actual_hit;
        reg cached_after;
        integer before_writes;
        integer writes_used;

        begin
            index = address[1:0];
            tag = address[15:2];

            h0 = DUT.u_cache_controller.valid_way0[index] &&
                 (DUT.u_cache_controller.tag_way0[index] == tag);
            h1 = DUT.u_cache_controller.valid_way1[index] &&
                 (DUT.u_cache_controller.tag_way1[index] == tag);

            actual_hit = h0 | h1;
            before_writes = memory_write_count;

            cpu_address = address;
            cpu_write_data = write_data;
            cpu_read = 0;
            cpu_write = 1;
            #50;
            cpu_write = 0;
            #20;

            writes_used = memory_write_count - before_writes;

            cached_after =
                (DUT.u_cache_controller.valid_way0[index] &&
                 DUT.u_cache_controller.tag_way0[index] == tag) ||
                (DUT.u_cache_controller.valid_way1[index] &&
                 DUT.u_cache_controller.tag_way1[index] == tag);

            $display("");
            $display("------------------------------------------------------------");
            $display("TEST %0d : %s", test_no, test_name);
            $display("WRITE addr=%h  data=%h", address, write_data);
            $display("index=%0d tag=%h  way0 hit=%0b way1 hit=%0b", index, tag, h0, h1);
            $display("memory writes=%0d", writes_used);

            test_pass[test_no] = 1'b1;
            if (actual_hit !== expected_hit)
                test_pass[test_no] = 1'b0;
            if (writes_used != 1)
                test_pass[test_no] = 1'b0;
            if (DUT.u_main_memory.memory[address] !== write_data)
                test_pass[test_no] = 1'b0;
            if (expected_hit && !cached_after)
                test_pass[test_no] = 1'b0;
            if (!expected_hit && cached_after)
                test_pass[test_no] = 1'b0;

            if (actual_hit)
                $display("operation = WRITE HIT (cache + memory)");
            else
                $display("operation = WRITE MISS (memory only)");

            if (test_pass[test_no])
                $display("status = PASS");
            else
                $display("status = FAIL");
        end
    endtask

    task print_summary;
        begin
            passed_tests = 0;
            failed_tests = 0;

            for (i = 1; i <= 15; i = i + 1) begin
                if (test_pass[i]) passed_tests = passed_tests + 1;
                else failed_tests = failed_tests + 1;
            end

            $display("");
            $display("================ CACHE TEST SUMMARY ================");
            $display(" 1  First Read / Read Miss           : %s", test_pass[1]  ? "PASS" : "FAIL");
            $display(" 2  Same Address / Read Hit          : %s", test_pass[2]  ? "PASS" : "FAIL");
            $display(" 3  Second Way Fill                  : %s", test_pass[3]  ? "PASS" : "FAIL");
            $display(" 4  Multiple Read Hit                : %s", test_pass[4]  ? "PASS" : "FAIL");
            $display(" 5  Read Hit / LRU Update            : %s", test_pass[5]  ? "PASS" : "FAIL");
            $display(" 6  LRU Replacement                  : %s", test_pass[6]  ? "PASS" : "FAIL");
            $display(" 7  Read Evicted Address             : %s", test_pass[7]  ? "PASS" : "FAIL");
            $display(" 8  Write Hit                        : %s", test_pass[8]  ? "PASS" : "FAIL");
            $display(" 9  Read After Write Hit             : %s", test_pass[9]  ? "PASS" : "FAIL");
            $display("10  Multiple Write Hit               : %s", test_pass[10] ? "PASS" : "FAIL");
            $display("11  Read After Multiple Writes       : %s", test_pass[11] ? "PASS" : "FAIL");
            $display("12  Write Miss                       : %s", test_pass[12] ? "PASS" : "FAIL");
            $display("13  Multiple Write Miss              : %s", test_pass[13] ? "PASS" : "FAIL");
            $display("14  Read After Write Miss            : %s", test_pass[14] ? "PASS" : "FAIL");
            $display("15  Read After Multiple Write Miss   : %s", test_pass[15] ? "PASS" : "FAIL");
            $display("----------------------------------------------------");
            $display("TOTAL=%0d  PASSED=%0d  FAILED=%0d", 15, passed_tests, failed_tests);
            $display("====================================================");
        end
    endtask

    initial begin
        reset = 1;
        cpu_address = 0;
        cpu_read = 0;
        cpu_write = 0;
        cpu_write_data = 0;
        memory_read_count = 0;
        memory_write_count = 0;
        passed_tests = 0;
        failed_tests = 0;

        for (i = 1; i <= 15; i = i + 1)
            test_pass[i] = 0;

        // values used by the read tests
        #1;
        DUT.u_main_memory.memory[16'h1000] = 32'hAAAA_1111;
        DUT.u_main_memory.memory[16'h2000] = 32'hBBBB_2222;
        DUT.u_main_memory.memory[16'h3000] = 32'hCCCC_3333;

        #19;
        reset = 0;
        #20;

        $display("\n2-way cache controller test started");

        read_test (1,  "First Read / Read Miss",          16'h1000, 32'hAAAA_1111, 1'b0);
        read_test (2,  "Same Address / Read Hit",         16'h1000, 32'hAAAA_1111, 1'b1);
        read_test (3,  "Second Way Fill",                 16'h2000, 32'hBBBB_2222, 1'b0);
        read_test (4,  "Multiple Read Hit",               16'h2000, 32'hBBBB_2222, 1'b1);
        read_test (5,  "Read Hit / LRU Update",           16'h1000, 32'hAAAA_1111, 1'b1);
        read_test (6,  "LRU Replacement",                 16'h3000, 32'hCCCC_3333, 1'b0);
        read_test (7,  "Read Evicted Address",            16'h2000, 32'hBBBB_2222, 1'b0);

        write_test(8,  "Write Hit",                       16'h2000, 32'h1234_5678, 1'b1);
        read_test (9,  "Read After Write Hit",            16'h2000, 32'h1234_5678, 1'b1);
        write_test(10, "Multiple Write Hit",              16'h2000, 32'h8765_4321, 1'b1);
        read_test (11, "Read After Multiple Writes",      16'h2000, 32'h8765_4321, 1'b1);

        write_test(12, "Write Miss",                      16'h4001, 32'hEEAA_CEFF, 1'b0);
        write_test(13, "Multiple Write Miss",             16'h5002, 32'hCAEE_ADDE, 1'b0);
        read_test (14, "Read After Write Miss",           16'h4001, 32'hEEAA_CEFF, 1'b0);
        read_test (15, "Read After Multiple Write Miss",  16'h5002, 32'hCAEE_ADDE, 1'b0);

        print_summary;
        #20;
        $finish;
    end

endmodule
