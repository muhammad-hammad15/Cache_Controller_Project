`timescale 1ns/1ps

module cache_system_top_tb;

     
    // TESTBENCH SIGNALS
    reg         clk;
    reg         reset;
    reg  [15:0] cpu_address;
    reg         cpu_read;
    reg         cpu_write;
    reg  [31:0] cpu_write_data;
    wire [31:0] cpu_read_data;

     
    // COUNTER VARIABLES
    integer memory_read_count;
    integer memory_write_count;
    integer passed_tests;
    integer failed_tests;
    integer i;
    
    // Test counter
    reg test_pass [1:15];

    // DUT
    cache_system_top DUT (
        .clk            (clk),
        .reset          (reset),
        .cpu_address    (cpu_address),
        .cpu_read       (cpu_read),
        .cpu_write      (cpu_write),
        .cpu_write_data (cpu_write_data),
        .cpu_read_data  (cpu_read_data)
    );
     
    // CLOCK: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
     
    // WAVEFORM DUMP
    initial begin
        $dumpfile("cache.vcd");
        $dumpvars(0, cache_system_top_tb);
    end

     
    // COUNT MAIN-MEMORY ACCESSES
    always @(posedge clk) begin
        if (!reset && DUT.mem_req) begin
            if (DUT.mem_we)
                memory_write_count = memory_write_count + 1;
            else
                memory_read_count = memory_read_count + 1;
        end
    end

     
    // READ TEST TASK
    task read_test;
        input [31:0] test_no;
        input [8*48-1:0] test_name;
        input [15:0] address;
        input [31:0] expected_data;
        input expected_hit;

        reg [1:0]  index;
        reg [13:0] tag;
        reg hit_way0_before;
        reg hit_way1_before;
        reg actual_hit;

        integer reads_before;
        integer reads_this_test;

        begin
            index = address[1:0];
            tag   = address[15:2];

            // Check cache contents BEFORE the CPU request.
            hit_way0_before =
                DUT.u_cache_controller.valid_way0[index] &&
                (DUT.u_cache_controller.tag_way0[index] == tag);

            hit_way1_before =
                DUT.u_cache_controller.valid_way1[index] &&
                (DUT.u_cache_controller.tag_way1[index] == tag);

            actual_hit = hit_way0_before | hit_way1_before;
            reads_before = memory_read_count;

            // Apply CPU read request.
            cpu_address = address;
            cpu_write   = 1'b0;
            cpu_read    = 1'b1;

            #50;
            cpu_read = 1'b0;
            #20;

            reads_this_test = memory_read_count - reads_before;

            // Compact console output.
            $display("");
            $display("------------------------------------------------------------");
            $display("TEST %0d : %s", test_no, test_name);
            $display("------------------------------------------------------------");
            $display("READ");
            $display("  Address      = 0x%04h", address);
            $display("  Index        = %0d", index);
            $display("  Tag          = 0x%04h", tag);
            $display("  Way 0 Hit    = %0b", hit_way0_before);
            $display("  Way 1 Hit    = %0b", hit_way1_before);
            $display("  Cache Hit    = %0b", actual_hit);
            $display("  Memory Read  = %0d", reads_this_test);
            $display("  CPU Data     = 0x%08h", cpu_read_data);

            if (actual_hit)
                $display("  Operation    = READ HIT");
            else
                $display("  Operation    = READ MISS");

            // PASS / FAIL checks.
            test_pass[test_no] = 1'b1;

            if (actual_hit !== expected_hit)
                test_pass[test_no] = 1'b0;

            if (cpu_read_data !== expected_data)
                test_pass[test_no] = 1'b0;

            if (expected_hit && (reads_this_test != 0))
                test_pass[test_no] = 1'b0;

            if (!expected_hit && (reads_this_test != 1))
                test_pass[test_no] = 1'b0;

            if (test_pass[test_no])
                $display("  Status       = PASS");
            else
                $display("  Status       = FAIL");

            $display("------------------------------------------------------------");
        end
    endtask

     
    // WRITE TEST TASK
    task write_test;
        input [31:0] test_no;
        input [8*48-1:0] test_name;
        input [15:0] address;
        input [31:0] write_data;
        input expected_hit;

        reg [1:0]  index;
        reg [13:0] tag;
        reg hit_way0_before;
        reg hit_way1_before;
        reg actual_hit;
        reg cached_after_write;

        integer writes_before;
        integer writes_this_test;

        begin
            index = address[1:0];
            tag   = address[15:2];

            // Check cache contents BEFORE the CPU write.
            hit_way0_before =
                DUT.u_cache_controller.valid_way0[index] &&
                (DUT.u_cache_controller.tag_way0[index] == tag);

            hit_way1_before =
                DUT.u_cache_controller.valid_way1[index] &&
                (DUT.u_cache_controller.tag_way1[index] == tag);

            actual_hit = hit_way0_before | hit_way1_before;
            writes_before = memory_write_count;

            // Apply CPU write request.
            cpu_address    = address;
            cpu_write_data = write_data;
            cpu_read       = 1'b0;
            cpu_write      = 1'b1;

            #50;
            cpu_write = 1'b0;
            #20;

            writes_this_test = memory_write_count - writes_before;

            // Check whether the line is cached after the write.
            cached_after_write =
                (DUT.u_cache_controller.valid_way0[index] &&
                 (DUT.u_cache_controller.tag_way0[index] == tag)) ||
                (DUT.u_cache_controller.valid_way1[index] &&
                 (DUT.u_cache_controller.tag_way1[index] == tag));

            // Compact console output.
            $display("");
            $display("------------------------------------------------------------");
            $display("TEST %0d : %s", test_no, test_name);
            $display("------------------------------------------------------------");
            $display("WRITE");
            $display("  Address      = 0x%04h", address);
            $display("  Write Data   = 0x%08h", write_data);
            $display("  Index        = %0d", index);
            $display("  Tag          = 0x%04h", tag);
            $display("  Way 0 Hit    = %0b", hit_way0_before);
            $display("  Way 1 Hit    = %0b", hit_way1_before);
            $display("  Cache Hit    = %0b", actual_hit);
            $display("  Memory Write = %0d", writes_this_test);

            if (actual_hit) begin
                $display("  Operation    = WRITE HIT");
                $display("  Action       = Cache + Memory updated");
            end
            else begin
                $display("  Operation    = WRITE MISS");
                $display("  Action       = Memory only");
                $display("  Policy       = No-Write-Allocate");
            end

            // PASS / FAIL checks.
            test_pass[test_no] = 1'b1;

            if (actual_hit !== expected_hit)
                test_pass[test_no] = 1'b0;

            // Write-Through requires one main-memory write.
            if (writes_this_test != 1)
                test_pass[test_no] = 1'b0;

            if (DUT.u_main_memory.memory[address] !== write_data)
                test_pass[test_no] = 1'b0;

            // Write hit: line remains in cache.
            if (expected_hit && !cached_after_write)
                test_pass[test_no] = 1'b0;

            // Write miss: No-Write-Allocate means line is not inserted.
            if (!expected_hit && cached_after_write)
                test_pass[test_no] = 1'b0;

            if (test_pass[test_no])
                $display("  Status       = PASS");
            else
                $display("  Status       = FAIL");

            $display("------------------------------------------------------------");
        end
    endtask

     
    // FINAL SUMMARY TASK 
    task print_summary;
        begin
            passed_tests = 0;
            failed_tests = 0;

            for (i = 1; i <= 15; i = i + 1) begin
                if (test_pass[i])
                    passed_tests = passed_tests + 1;
                else
                    failed_tests = failed_tests + 1;
            end

            $display("");
            $display("============================================================");
            $display("                 DETAILED CACHE TEST SUMMARY");
            $display("============================================================");
            $display("Test 1  : First Read / Read Miss           : %s", test_pass[1]  ? "PASS" : "FAIL");
            $display("Test 2  : Same Address / Read Hit          : %s", test_pass[2]  ? "PASS" : "FAIL");
            $display("Test 3  : Second Way Fill                  : %s", test_pass[3]  ? "PASS" : "FAIL");
            $display("Test 4  : Multiple Read Hit                : %s", test_pass[4]  ? "PASS" : "FAIL");
            $display("Test 5  : Read Hit / LRU Update            : %s", test_pass[5]  ? "PASS" : "FAIL");
            $display("Test 6  : LRU Replacement                  : %s", test_pass[6]  ? "PASS" : "FAIL");
            $display("Test 7  : Read Evicted Address             : %s", test_pass[7]  ? "PASS" : "FAIL");
            $display("Test 8  : Write Hit                        : %s", test_pass[8]  ? "PASS" : "FAIL");
            $display("Test 9  : Read After Write Hit             : %s", test_pass[9]  ? "PASS" : "FAIL");
            $display("Test 10 : Multiple Write Hit               : %s", test_pass[10] ? "PASS" : "FAIL");
            $display("Test 11 : Read After Multiple Writes       : %s", test_pass[11] ? "PASS" : "FAIL");
            $display("Test 12 : Write Miss                       : %s", test_pass[12] ? "PASS" : "FAIL");
            $display("Test 13 : Multiple Write Miss              : %s", test_pass[13] ? "PASS" : "FAIL");
            $display("Test 14 : Read After Write Miss            : %s", test_pass[14] ? "PASS" : "FAIL");
            $display("Test 15 : Read After Multiple Write Miss   : %s", test_pass[15] ? "PASS" : "FAIL");

            $display("");
            $display("------------------------------------------------------------");
            $display("TOTAL TESTS : 15");
            $display("PASSED      : %0d", passed_tests);
            $display("FAILED      : %0d", failed_tests);
            $display("------------------------------------------------------------");
            $display("CACHE BEHAVIORS VERIFIED");
            $display("  - Read Miss / Read Hit / Multiple Read Hits");
            $display("  - Two-Way Set Filling and LRU Replacement");
            $display("  - Write Hit / Multiple Write Hits");
            $display("  - Write-Through");
            $display("  - Write Miss / Multiple Write Misses");
            $display("  - No-Write-Allocate");
            $display("  - Read After Write Hit / Miss");
            $display("============================================================");
        end
    endtask

     
    // MAIN DIRECTED TEST SEQUENCE
    initial begin
        reset              = 1'b1;
        cpu_address        = 16'd0;
        cpu_read           = 1'b0;
        cpu_write          = 1'b0;
        cpu_write_data     = 32'd0;
        memory_read_count  = 0;
        memory_write_count = 0;
        passed_tests       = 0;
        failed_tests       = 0;

        for (i = 1; i <= 15; i = i + 1)
            test_pass[i] = 1'b0;

        // Test-only memory initialization. This is intentionally located in
        // the testbench rather than the synthesizable main_memory RTL.
        #1;
        DUT.u_main_memory.memory[16'h1000] = 32'hAAAA_1111;
        DUT.u_main_memory.memory[16'h2000] = 32'hBBBB_2222;
        DUT.u_main_memory.memory[16'h3000] = 32'hCCCC_3333;

        // Reset cache/controller.
        #19;
        reset = 1'b0;
        #20;

        $display("");
        $display("============================================================");
        $display("              CACHE CONTROLLER DIRECTED TESTS");
        $display("============================================================");
        $display("Cache Type        : 2-Way Set Associative");
        $display("Replacement       : LRU");
        $display("Write Policy      : Write-Through");
        $display("Write Miss Policy : No-Write-Allocate");
        $display("============================================================");

        // Test 1: first access -> read miss.
        read_test(1, "First Read / Read Miss", 16'h1000, 32'hAAAA_1111, 1'b0);

        // Test 2: same address -> read hit.
        read_test(2, "Same Address / Read Hit", 16'h1000, 32'hAAAA_1111, 1'b1);

        // Test 3: same Set 0, different tag -> fill second way.
        read_test(3, "Second Way Fill", 16'h2000, 32'hBBBB_2222, 1'b0);

        // Test 4: repeated access -> another read hit.
        read_test(4, "Multiple Read Hit", 16'h2000, 32'hBBBB_2222, 1'b1);

        // Test 5: hit 0x1000 to make 0x2000 the LRU line.
        read_test(5, "Read Hit / LRU Update", 16'h1000, 32'hAAAA_1111, 1'b1);

        // Test 6: third block in Set 0 -> LRU replacement.
        read_test(6, "LRU Replacement", 16'h3000, 32'hCCCC_3333, 1'b0);

        // Test 7: 0x2000 was evicted -> miss and bring it back.
        read_test(7, "Read Evicted Address", 16'h2000, 32'hBBBB_2222, 1'b0);

        // Test 8: write hit -> cache + memory updated.
        write_test(8, "Write Hit", 16'h2000, 32'h1234_5678, 1'b1);

        // Test 9: read after write hit -> returns updated value from cache.
        read_test(9, "Read After Write Hit", 16'h2000, 32'h1234_5678, 1'b1);

        // Test 10: repeated write hit.
        write_test(10, "Multiple Write Hit", 16'h2000, 32'h8765_4321, 1'b1);

        // Test 11: latest write value must be returned.
        read_test(11, "Read After Multiple Writes", 16'h2000, 32'h8765_4321, 1'b1);

        // Test 12: write miss -> memory only, no cache allocation.
        write_test(12, "Write Miss", 16'h4001, 32'hEEAA_CEFF, 1'b0);

        // Test 13: second write miss at another set.
        write_test(13, "Multiple Write Miss", 16'h5002, 32'hCAEE_ADDE, 1'b0);

        // Test 14: must miss because Test 12 did not allocate the line.
        read_test(14, "Read After Write Miss", 16'h4001, 32'hEEAA_CEFF, 1'b0);

        // Test 15: must also miss because Test 13 did not allocate the line.
        read_test(15, "Read After Multiple Write Miss", 16'h5002, 32'hCAEE_ADDE, 1'b0);

        print_summary;

        #20;
        $finish;
    end

endmodule
