/***********************************************************************************************************
 * Module: Instruction Fetch Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module verifies the functionality of the Instruction Fetch module by providing stimulus 
 *     and monitoring the outputs.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - ins_cache: Instruction cache containing 64B instructions
 *   - branch_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - read_enable: Signal indicating if the Instruction Fetch unit is ready to read the next set of instructions
 *   - program_counter: Current program counter value
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - instr_d: Array storing the fetched instructions
 *   - stall: Signal indicating if the Instruction Fetch unit should stall fetching new instructions
 *   - program_counter_wb: Program counter to be used as the reset program_counter signal for Instruction Fetch to start reading new instructions
 *   - program_counter_check: Integer used for checkpointing to adjust the program counter while reading from ins_cache
 ***********************************************************************************************************/

module Instruction_Fetch_TB ();

  logic clock, reset;
  logic [0:31] instruction_memory[0:255];
  logic [0:31] instruction[0:255];
  logic read_enable, stall;
  logic [7:0] program_counter;

  Instruction_Fetch instructions_fetch (
      clock,
      reset,
      instruction,
      program_counter,
      read_enable
  );

  initial clock = 0;

  always begin
    #5 clock = ~clock;
  end
  initial begin
    $readmemb("./Compiler/memory_contents.txt", instruction_memory);
    #1;
    reset = 1;
    @(posedge clock);
    #1;
    reset = 1;
    @(posedge clock);
    #1;
    reset = 0;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #300;
    $stop;
  end
  always @(posedge clock) begin
    if (read_enable == 1) begin
      instruction[0:255] = instruction_memory[(program_counter)+:256];
    end
  end
endmodule
