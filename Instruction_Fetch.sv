/***********************************************************************************************************
 * Module: Instruction Fetch
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module fetches instructions from the instruction cache and sends them to the Decode stage. It also
 *     manages the program counter (program_counter) and controls the flow of instruction fetching.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - instruction_cache: Instruction cache containing 64B instructions
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - read_enable: Signal indicating if the Instruction Fetch unit is ready to read the next set of instructions
 *   - program_counter: Current program counter value
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - instr_decode: Array storing the fetched instructions
 *   - stall: Signal indicating if the Instruction Fetch unit should stall fetching new instructions
 *   - program_counter_wb: Program counter to be used as the reset program_counter signal for Instruction Fetch to start reading new instructions
 *   - program_counter_check: Integer used for checkpointing to adjust the program counter while reading from instruction_cache
 ***********************************************************************************************************/

module Instruction_Fetch (
    clock,
    reset,
    instruction_cache,
    program_counter,
    read_enable
);

  input logic clock;
  input logic reset;

  // Instruction line buffer, stores 64B instruction
  input logic [0:31] instruction_cache[0:255];
  // 2 instructions sent to DECODE stage
  logic [0:31] instr_decode[0:1];
  // Flag to indicate a stall. When set, Instruction fetch should stop fetching new instruction
  logic stall;
  // Flag to indicate if a branch was taken
  logic branch_is_taken;
  // Flag to signal that IF is ready to read next set of 64B instruction
  output logic read_enable;
  // Program Counter
  output logic [7:0] program_counter;
  // program_counter_wb acts as reset program_counter signal for IF to start new instruction read position
  logic [7:0] program_counter_wb;
  // Used for checkpointing, to adjust the program_counter while reading from instruction_cache
  integer program_counter_check;

  localparam [0:31] NOP = 32'b01000000001000000000000000000000;
  localparam [0:31] LNOP = 32'b00000000001000000000000000000000;

  Decode decode (
      clock,
      reset,
      instr_decode,
      program_counter,
      program_counter_wb,
      stall,
      branch_is_taken
  );

  always_comb begin : program_counter_counter
    if (reset == 1) begin
      program_counter_check = 0;
      read_enable = 1;
    end else begin
      read_enable = 0;
    end
  end

  always_ff @(posedge clock) begin : fetch_instruction
    if (reset == 1) begin
      program_counter <= 0;
      instr_decode[0] <= 32'h0000;
      instr_decode[1] <= 32'h0000;
    end else begin
      // The 'stall' flag is used to halt the Instruction Fetch (IF) from fetching new instructions. 
      // This is particularly useful in cases of dual issue conflicts where the decode stage 
      // inserts a No Operation (nop) instruction. 
      // The 'program_counter_wb' is then used to resume fetching a new stream of instructions.
      if (stall == 0) begin
        // stall<=0;
        instr_decode[0] <= instruction_cache[program_counter];
        instr_decode[1] <= instruction_cache[program_counter+1];
        if (program_counter < 254) program_counter <= program_counter + 2;
      end else begin
        if (branch_is_taken == 0) begin
          instr_decode[0] <= instruction_cache[program_counter_wb];
          instr_decode[1] <= instruction_cache[program_counter_wb+1];
        end else begin
          program_counter <= program_counter_wb & ~1;
          // If branching to an odd number instruction, indicated by the least significant bit of program_counter_wb being 1
          if (program_counter_wb & 256'h1) begin
            instr_decode[0] <= instruction_cache[program_counter_wb-2];
            instr_decode[1] <= 0;
          end else begin
            instr_decode[0] <= instruction_cache[program_counter_wb-2];
            instr_decode[1] <= instruction_cache[program_counter_wb-1];
          end
        end
      end
    end
  end
endmodule
