# Hammad Cache Controller — Verilog-2001 Project

## 1. Project overview

This project implements a **2-way set-associative cache controller** using **Verilog-2001** RTL.

Cache configuration:

- **16-bit address**
- **32-bit data**
- **8 total cache lines**
- **4 sets × 2 ways**
- **LRU (Least Recently Used)** replacement
- **Write-Through** write policy
- **No-Write-Allocate** on a write miss

---

## 2. Project files

- `cpu_model.v` — synthesizable CPU-side request adapter
- `cache_controller.v` — synthesizable 2-way cache controller and the only FSM
- `main_memory.v` — synthesizable simple memory model
- `cache_system_top.v` — synthesizable top-level RTL integration
- `cache_system_top_tb.v` — Verilog directed testbench for simulation only
- `README.md` — project documentation

> **Important:** The four design `.v` files are synthesizable RTL. The testbench is intentionally non-synthesizable because testbenches use simulation-only constructs such as delays, `$display`, `$dumpfile`, and hierarchical test initialization.

---

## 3. Design hierarchy

```text
cache_system_top_tb
        |
        v
cache_system_top
        |
        +-- u_cpu_model
        |
        +-- u_cache_controller   <-- only FSM
        |
        +-- u_main_memory        <-- no FSM
```

---

## 4. Address organization

The assignment uses:

```text
15                         2 1      0
+---------------------------+--------+
|          TAG              | INDEX  |
+---------------------------+--------+
       14 bits                2 bits
```

- `Tag = address[15:2]`
- `Index = address[1:0]`
- 2 index bits select one of 4 cache sets.
- Each selected set contains Way 0 and Way 1.

There is no separate byte-offset field in this project because the implementation follows the supplied assignment address split exactly.

---

## 5. Module descriptions

### 5.1 `cpu_model.v`

The CPU model converts the external level-based controls into a one-clock cache request pulse.

External signals:

- `cpu_address`
- `cpu_read`
- `cpu_write`
- `cpu_write_data`
- `cpu_read_data`

Cache-controller interface:

- `cache_req`
- `cache_we`
- `cache_addr`
- `cache_wdata`
- `cache_rdata`
- `cache_ready`

The module uses a `request_sent` flag so holding `cpu_read` or `cpu_write` high for several cycles still creates only one cache request. The flag is cleared after both CPU control signals return low.

### 5.2 `cache_controller.v`

The cache controller contains:

- tag storage
- data storage
- valid bits
- one LRU bit per set
- request registers
- hit detection
- a four-state FSM

It handles:

- read hit
- read miss
- write hit
- write miss
- LRU replacement
- Write-Through
- No-Write-Allocate

### 5.3 `main_memory.v`

The memory contains:

```verilog
reg [31:0] memory [0:65535];
```

Behavior:

- asynchronous/combinational read
- synchronous write
- `mem_ready = mem_req`
- no FSM
- no artificial delay model

The RTL does **not** contain an `initial` block. Test data is initialized by the testbench instead. This keeps the memory RTL independent of simulation-only initialization.

### 5.4 `cache_system_top.v`

The top module instantiates and wires together:

```text
CPU Model <-> Cache Controller <-> Main Memory
```

---

## 6. Cache-controller FSM

The FSM uses four Verilog `localparam` states:

```verilog
localparam [1:0] IDLE      = 2'b00;
localparam [1:0] LOOKUP    = 2'b01;
localparam [1:0] MEM_READ  = 2'b10;
localparam [1:0] MEM_WRITE = 2'b11;
```

### IDLE
Waits for `cpu_req`. When a request arrives, the controller stores the address, write data, and read/write type, then enters `LOOKUP`.

### LOOKUP
Compares the requested tag against both ways of the selected set.

- read hit → return cache data, update LRU, go to `IDLE`
- read miss → go to `MEM_READ`
- write hit → update cache data/LRU, then go to `MEM_WRITE`
- write miss → do not modify cache, go to `MEM_WRITE`

### MEM_READ
Used only for a read miss.

When memory is ready:

1. use invalid Way 0 if available
2. otherwise use invalid Way 1
3. otherwise replace the LRU way
4. return the memory data to the CPU
5. update LRU
6. return to `IDLE`

### MEM_WRITE
Used for both write hits and write misses.

While in this state:

```text
mem_req = 1
mem_we  = 1
```

The controller forwards the saved request:

```text
mem_addr  = req_addr
mem_wdata = req_wdata
```

`main_memory.v` performs the actual write on the clock edge:

```verilog
if (mem_req && mem_we)
    memory[mem_addr] <= mem_wdata;
```

After `mem_ready` is seen, the cache controller asserts `cpu_ready` and returns to `IDLE`.

---

## 7. Read behavior

### Read hit

```text
CPU request
   -> LOOKUP
   -> matching valid tag found
   -> cache data returned
   -> LRU updated
   -> no memory read
```

### Read miss

```text
CPU request
   -> LOOKUP
   -> no matching tag
   -> MEM_READ
   -> main memory data fetched
   -> invalid or LRU way filled
   -> CPU receives data
```

---

## 8. Write behavior

### Write hit

```text
CPU write
   -> LOOKUP
   -> cache hit
   -> cached copy updated
   -> LRU updated
   -> MEM_WRITE
   -> main memory updated
```

This implements **Write-Through**.

### Write miss

```text
CPU write
   -> LOOKUP
   -> cache miss
   -> cache remains unchanged
   -> MEM_WRITE
   -> main memory updated
```

This implements **No-Write-Allocate**.

---

## 9. LRU behavior

Each set uses one bit:

- `lru_way[set] = 0` → Way 0 is the next victim
- `lru_way[set] = 1` → Way 1 is the next victim

After accessing Way 0:

```text
Way 0 = MRU
Way 1 = LRU
lru_way = 1
```

After accessing Way 1:

```text
Way 1 = MRU
Way 0 = LRU
lru_way = 0
```

---

## 10. Testbench

`cache_system_top_tb.v` is a **Verilog-2001 simulation testbench**.

It uses:

- `read_test` task
- `write_test` task
- `print_summary` task
- memory read/write counters
- 15 directed test cases

### Directed tests

1. First Read / Read Miss
2. Same Address / Read Hit
3. Second Way Fill
4. Multiple Read Hit
5. Read Hit / LRU Update
6. LRU Replacement
7. Read Evicted Address
8. Write Hit
9. Read After Write Hit
10. Multiple Write Hit
11. Read After Multiple Writes
12. Write Miss
13. Multiple Write Miss
14. Read After Write Miss
15. Read After Multiple Write Miss

The testbench initializes only the memory locations required for deterministic read testing:

```verilog
DUT.u_main_memory.memory[16'h1000] = 32'hAAAA_1111;
DUT.u_main_memory.memory[16'h2000] = 32'hBBBB_2222;
DUT.u_main_memory.memory[16'h3000] = 32'hCCCC_3333;
```

This initialization is simulation-only and does not affect RTL synthesizability.

---

## 11. Synthesis notes

The synthesizable RTL files are:

```text
cpu_model.v
cache_controller.v
main_memory.v
cache_system_top.v
```

They contain no:

- `$display`
- `#` delays
- `initial` blocks
- assertions/properties
- classes
- randomization
- SystemVerilog-only `logic`/`always_ff`/`always_comb`

The reset loop in `cache_controller.v` has a fixed bound of four cache sets and is intended to synthesize into reset logic for the valid/LRU registers.

`main_memory.v` describes a large 65,536 × 32-bit memory. It is valid synthesizable RTL, but the exact hardware implementation (registers, distributed RAM, block RAM, or external memory mapping) depends on the synthesis target and tool. Its asynchronous read behavior can also affect which memory primitive a particular FPGA tool can infer.

---

## 12. Simulation

### Icarus Verilog

```bash
iverilog -g2001 -o cache_sim \
    cpu_model.v \
    cache_controller.v \
    main_memory.v \
    cache_system_top.v \
    cache_system_top_tb.v

vvp cache_sim
```

### Questa / ModelSim / Riviera-PRO

```tcl
vlog cpu_model.v
vlog cache_controller.v
vlog main_memory.v
vlog cache_system_top.v
vlog cache_system_top_tb.v

vsim cache_system_top_tb
run -all
```

### EDA Playground

Select **Verilog** rather than SystemVerilog.

Design files:

```text
cpu_model.v
cache_controller.v
main_memory.v
cache_system_top.v
```

Testbench:

```text
cache_system_top_tb.v
```

Top module:

```text
cache_system_top_tb
```

---

## 13. Useful waveform signals

Inside `DUT.u_cache_controller`, watch:

```text
state
req_addr
req_index
req_tag
req_we
hit_way0
hit_way1
valid_way0
valid_way1
tag_way0
tag_way1
data_way0
data_way1
lru_way
cpu_ready
cpu_rdata
mem_req
mem_we
mem_addr
mem_wdata
mem_rdata
```

---

## 14. Summary

The project is written in **Verilog-2001** while preserving the original cache behavior:

- 2-way set associativity
- 4 sets / 8 total lines
- LRU replacement
- Write-Through
- No-Write-Allocate
- read hit/miss handling
- write hit/miss handling
- 15 directed verification tests

The design RTL is kept synthesizable, while all simulation-only functionality remains isolated in the testbench.

---

## 15. EDA Playground convenience files

The `EDA_Playground/` folder contains:

- `design.v` — all four synthesizable RTL modules combined into one design file
- `testbench.v` — the complete Verilog testbench

This is useful because EDA Playground commonly compiles one design editor and one testbench editor. Paste/upload `design.v` on the Design side and `testbench.v` on the Testbench side.

Do **not** compile `EDA_Playground/design.v` together with the four separate RTL module files in the same simulation, because that would define the same modules twice.
