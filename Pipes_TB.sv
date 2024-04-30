/***********************************************************************************************************
 * Module: Pipes Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module serves as the testbench for the Pipes module. It generates stimulus for the Pipes module
 *     and monitors its outputs for correctness.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - instruction_even: Instruction from the decoder for even pipeline stage
 *   - instruction_odd: Instruction from the decoder for odd pipeline stage
 *   - program_counter: Program counter from the IF stage
 *   - op_code_even, op_code_odd: op_code of the instruction for even and odd pipeline stages
 *   - format_is_even, format_is_odd: Format of the instruction for even and odd pipeline stages
 *   - unit_is_even, unit_is_odd: Destination unit of the instruction for even and odd pipeline stages
 *   - rt_address_even, rt_address_odd: Destination register addresses for even and odd pipeline stages
 *   - ra_even, rb_even, rc_even, ra_odd, rb_odd, rt_st_odd: Register values from the Register Table
 *   - immediate_even, immediate_odd: Immediate values for even and odd pipeline stages
 *   - register_write_even, register_write_odd: Flag indicating whether the current instruction writes to the register table
 *   - initial_odd: Flag indicating if the odd instruction is the first in the pair
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - program_counter_wb: New program counter for branch instruction handling
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - rt_even_wb, rt_odd_wb: Values to be written back to the register table for even and odd pipeline stages
 *   - rt_address_even_wb, rt_address_odd_wb: Destination register addresses for write-back for even and odd stages
 *   - register_write_even_wb, register_write_odd_wb: Flag indicating whether the write-back data will be written to the register table
 *   - fw_even_wb, fw_odd_wb: Pipe shift registers of values ready to be forwarded for even and odd pipeline stages
 *   - fw_addr_even_wb, fw_addr_odd_wb: Destination addresses of values to be forwarded for even and odd pipeline stages
 *   - fw_write_even_wb, fw_write_odd_wb: Flag indicating whether forwarded values will be written to the register table for even and odd stages
 *   - branch_kill: Signal indicating if a branch is taken and the branch instruction is first in the pair
 *   - format_is_even_live: Format of the instruction for the even stage, only valid if branch not taken by the first instruction
 *   - op_code_even_live: op_code of the instruction for the even stage, only valid if branch not taken by the first instruction
 *   - delay_rt_address_even, delay_rt_address_odd: Delayed destination register addresses for RAW hazard handling
 *   - delay_register_write_even, delay_register_write_odd: Delayed flag indicating whether the instruction writes to the register table for RAW hazard handling
 *   - delay_rt_address_fp1, delay_register_write_fp1, delay_integer_fp1: Delayed signals for FP1 stage for RAW hazard handling
 *   - delay_rt_address_fx2, delay_register_write_fx2: Delayed signals for FX2 stage for RAW hazard handling
 *   - delay_rt_address_b1, delay_register_write_b1: Delayed signals for B1 stage for RAW hazard handling
 *   - delay_rt_address_fx1, delay_register_write_fx1: Delayed signals for FX1 stage for RAW hazard handling
 *   - delay_rt_address_p1, delay_register_write_p1: Delayed signals for P1 stage for RAW hazard handling
 *   - delay_rt_address_ls1, delay_register_write_ls1: Delayed signals for LS1 stage for RAW hazard handling
 ***********************************************************************************************************/

module Pipes_TB ();
  logic clock, reset;

  // Instructions from the decoder
  logic [0:31] instruction_even, instruction_odd;
  // Program counter from the Instruction Fetch stage
  logic [7:0] program_counter;

  // Signals for handling branches
  // New program counter for branch
  logic [7:0] program_counter_wb;
  // Was branch taken?
  logic branch_is_taken;
  // Signal indicating the opcode for the even pipeline
  logic op_code_even;
  // Signal indicating the opcode for the odd pipeline
  logic op_code_odd;
  // Signal indicating whether the execution unit for the even pipeline is active
  logic unit_is_even;
  // Signal indicating whether the execution unit for the odd pipeline is active
  logic unit_is_odd;
  // Signal representing the register address for the even pipeline
  logic rt_address_even;
  // Signal representing the register address for the odd pipeline
  logic rt_address_odd;
  // Signal indicating the instruction format for the even pipeline
  logic format_is_even;
  // Signal indicating the instruction format for the odd pipeline
  logic format_is_odd;
  // Signal representing the immediate value for the even pipeline
  logic immediate_even;
  // Signal representing the immediate value for the odd pipeline
  logic immediate_odd;
  // Signal indicating whether register write is enabled for the even pipeline
  logic register_write_even;
  // Signal indicating whether register write is enabled for the odd pipeline
  logic register_write_odd;
  // Signal indicating the initial state for the odd pipeline
  logic initial_odd;
  // Signal representing the delayed register address for the even pipeline
  logic delay_rt_address_even;
  // Signal representing the delayed register write for the even pipeline
  logic delay_register_write_even;
  // Signal representing the delayed register address for the odd pipeline
  logic delay_rt_address_odd;
  // Signal representing the delayed register write for the odd pipeline
  logic delay_register_write_odd;
  // Signal representing the delayed register address for the FP1 unit
  logic delay_rt_address_fp1;
  // Signal representing the delayed register write for the FP1 unit
  logic delay_register_write_fp1;
  // Signal representing the delayed integer for the FP1 unit
  logic delay_integer_fp1;
  // Signal representing the delayed register address for the FX2 unit
  logic delay_rt_address_fx2;
  // Signal representing the delayed register write for the FX2 unit
  logic delay_register_write_fx2;
  // Signal representing the delayed register address for the B1 unit
  logic delay_rt_address_b1;
  // Signal representing the delayed register write for the B1 unit
  logic delay_register_write_b1;
  // Signal representing the delayed register address for the FX1 unit
  logic delay_rt_address_fx1;
  // Signal representing the delayed register write for the FX1 unit
  logic delay_register_write_fx1;
  // Signal representing the delayed register address for the P1 unit
  logic delay_rt_address_p1;
  // Signal representing the delayed register write for the P1 unit
  logic delay_register_write_p1;
  // Signal representing the delayed register address for the LS1 unit
  logic delay_rt_address_ls1;
  // Signal representing the delayed register write for the LS1 unit
  logic delay_register_write_ls1;

  Pipes dut (
      clock,
      reset,
      instruction_even,
      instruction_odd,
      program_counter,
      program_counter_wb,
      branch_is_taken,
      op_code_even,
      op_code_odd,
      unit_is_even,
      unit_is_odd,
      rt_address_even,
      rt_address_odd,
      format_is_even,
      format_is_odd,
      immediate_even,
      immediate_odd,
      register_write_even,
      register_write_odd,
      initial_odd,
      delay_rt_address_even,
      delay_register_write_even,
      delay_rt_address_odd,
      delay_register_write_odd,
      delay_rt_address_fp1,
      delay_register_write_fp1,
      delay_integer_fp1,
      delay_rt_address_fx2,
      delay_register_write_fx2,
      delay_rt_address_b1,
      delay_register_write_b1,
      delay_rt_address_fx1,
      delay_register_write_fx1,
      delay_rt_address_p1,
      delay_register_write_p1,
      delay_rt_address_ls1,
      delay_register_write_ls1
  );

  // Set the initial state of the clock to zero
  initial clock = 0;

  // Toggle the clock value every 5 time units to simulate oscillation
  always begin
    #5 clock = ~clock;
    program_counter = program_counter + 1;
  end

  initial begin
    reset = 1;
    program_counter = 0;
    instruction_even = 0;
    instruction_odd = 0;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 15ns
    @(posedge clock);
    // Set the op_code for the "Immediate Load Halfword" operation (ilh) 
    op_code_even = 9'b010000011;
    instruction_even = 32'b10101111110011001010111000100100;
    // Set the op_code for the "No Operation" operation (nop)
    instruction_odd = 32'b0;
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 15ns
    @(posedge clock);
    // Set the op_code for the "Immediate Load Halfword" operation (ilh) 
    op_code_even = 9'b010000011;
    instruction_even = 32'b11011011000100110111101100001011;
    // Set the op_code for the "No Operation" operation (nop)
    instruction_odd = 32'b0;
    @(posedge clock);
    #1;
    instruction_even = 0;
    instruction_odd  = 0;
    @(posedge clock);
    @(posedge clock);
    #1;
    // Set the op_code for the "Add Halfword" operation (ah)
    op_code_even = 11'b00011001000;
    instruction_even = 32'b01010101001111100000110011101000;
    // Set the op_code for the "No Operation" operation (nop)
    instruction_odd = 32'b0;
    @(posedge clock);
    #1;
    instruction_even = 0;
    instruction_odd  = 0;
    @(posedge clock);
    @(posedge clock);
    #1;
    // Set the op_code for the "Immediate Load Halfword" operation (ilh)
    instruction_even = 32'b11101010100001010111101001101110;
    // Set the op_code for the "No Operation" operation (nop)
    instruction_odd  = 32'b0;
    @(posedge clock);
    #1;
    instruction_even = 0;
    instruction_odd  = 0;
    @(posedge clock);
    @(posedge clock);
    #1;
    // Set the op_code for the "Shift Left Halfword Immediate" operation (shlhi)
    op_code_even = 11'b00001111111;
    instruction_even = 32'b00110010111011100001101101011110;
    instruction_odd = 0;
    @(posedge clock);
    #1;
    instruction_even = 0;
    instruction_odd  = 0;
    @(posedge clock);
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 35ns
    @(posedge clock);
    #1;
    // Set the opcode for the "Rotate Halfword" operation (roth)
    op_code_even = 11'b00001011100;
    instruction_even = 32'b10011100100100100110101111000101;
    // Set the opcode for the "Rotate Halfword Immediate" operation (rothi)
    op_code_even = 11'b00001111100;
    instruction_odd = 32'b01101001111010100110010001111011;
    @(posedge clock);
    #1;
    instruction_even = 0;
    instruction_odd  = 0;
    @(posedge clock);
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 35ns
    @(posedge clock);
    #1;
    // Set the op_code for the "Rotate Halfword Immediate" operation (rotmah) 
    op_code_even = 11'b00001111100;
    instruction_even = 32'b11010011111000100101101010100011;
    instruction_odd = 0;
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 40ns
    @(posedge clock);
    #1;
    instruction_even = 0;
    instruction_odd  = 0;
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 45ns
    @(posedge clock);
    #1;
    // Wait for the positive edge of the clock, then pause the simulation for 1 time unit; This occurs at 50ns
    @(posedge clock);
    #1;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #200;
    $stop;
  end
endmodule
