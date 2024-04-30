/***********************************************************************************************************
 * Module: Register File
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 * 		This module handles register file operations including forwarding logic in a processor.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - instruction_even: Instruction from even pipeline stage
 *   - instruction_odd: Instruction from odd pipeline stage
 *   - ra_even_input: Value of register A for even pipeline stage
 *   - rb_even_input: Value of register B for even pipeline stage
 *   - rc_even_input: Value of register C for even pipeline stage
 *   - ra_odd_input: Value of register A for odd pipeline stage
 *   - rb_odd_input: Value of register B for odd pipeline stage
 *   - rt_st_odd_input: Value of temporary register rt_st for odd pipeline stage
 *   - rt_address_even_input: Destination register address to write to for even pipeline stage
 *   - rt_address_odd_input: Destination register address to write to for odd pipeline stage
 *   - rt_even_input: Value to write to the destination register for the even pipeline stage
 *   - rt_odd_input: Value to write to the destination register for the odd pipeline stage
 *   - register_write_even_input: Flag indicating whether the even instruction will write to a register
 *   - register_write_odd_input: Flag indicating whether the odd instruction will write to a register
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - ra_even_input: Value of register A for the even pipeline stage
 *   - rb_even_input: Value of register B for the even pipeline stage
 *   - rc_even_input: Value of register C for the even pipeline stage
 *   - ra_odd_input: Value of register A for the odd pipeline stage
 *   - rb_odd_input: Value of register B for the odd pipeline stage
 *   - rt_st_odd_input: Value of temporary register rt_st for the odd pipeline stage
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - registers: Register file storing register values
 *   - i: 8-bit counter for the reset loop
 ***********************************************************************************************************/

module Register_File (
    clock,
    reset,
    instruction_even,
    instruction_odd,
    ra_even_input,
    rb_even_input,
    rc_even_input,
    ra_odd_input,
    rb_odd_input,
    rt_st_odd_input,
    rt_address_even_input,
    rt_address_odd_input,
    rt_even_input,
    rt_odd_input,
    register_write_even_input,
    register_write_odd_input
);

  input clock, reset;

  //Register File/Forwarding Stage
  // Input instructions for both even and odd cycles, received from the decoder
  input [0:31] instruction_even, instruction_odd;
  // Input values for 'ra', 'rb', 'rc' for both even and odd instructions, and 'rt_st' for odd instruction, retrieved from the Register Table
  output logic [0:127] ra_even_input, rb_even_input, rc_even_input, ra_odd_input, rb_odd_input, rt_st_odd_input;

  //Write Back Stage
  // Destination registers for even and odd instructions
  input [0:6] rt_address_even_input, rt_address_odd_input;
  // Values to be written to destination registers for even and odd instructions
  input [0:127] rt_even_input, rt_odd_input;
  // Flags indicating if the even and odd instructions will write to the register table
  input register_write_even_input, register_write_odd_input;

  //Internal Signals
  // Register File storing 128 128-bit registers
  logic [0:127] registers[0:127];
  // 8-bit counter used in reset loop
  logic [  7:0] i;

  always_comb begin
    // Read source register addresses from instructions
    rc_even_input = registers[instruction_even[25:31]];
    ra_even_input = registers[instruction_even[18:24]];
    rb_even_input = registers[instruction_even[11:17]];
    ra_odd_input = registers[instruction_odd[18:24]];
    rb_odd_input = registers[instruction_odd[11:17]];
    rt_st_odd_input = registers[instruction_odd[25:31]];

    // Forward data from even instruction if writing to register table
    if (register_write_even_input) begin
      if (instruction_even[25:31] == rt_address_even_input) rc_even_input = rt_even_input;
      if (instruction_even[18:24] == rt_address_even_input) ra_even_input = rt_even_input;
      if (instruction_even[11:17] == rt_address_even_input) rb_even_input = rt_even_input;
      if (instruction_odd[25:31] == rt_address_even_input) rt_st_odd_input = rt_even_input;
      if (instruction_odd[18:24] == rt_address_even_input) ra_odd_input = rt_even_input;
      if (instruction_odd[11:17] == rt_address_even_input) rb_odd_input = rt_even_input;
    end

    // Forward data from odd instruction if writing to register table
    if (register_write_odd_input) begin
      if (instruction_even[25:31] == rt_address_odd_input) rc_even_input = rt_odd_input;
      if (instruction_even[18:24] == rt_address_odd_input) ra_even_input = rt_odd_input;
      if (instruction_even[11:17] == rt_address_odd_input) rb_even_input = rt_odd_input;
      if (instruction_odd[25:31] == rt_address_odd_input) rt_st_odd_input = rt_odd_input;
      if (instruction_odd[18:24] == rt_address_odd_input) ra_odd_input = rt_odd_input;
      if (instruction_odd[11:17] == rt_address_odd_input) rb_odd_input = rt_odd_input;
    end
  end

  /* Sequential logic for updating the register file. On a reset, all registers are cleared. On each clock cycle, if the even or odd instruction 
is writing to the register table, the corresponding register is updated with the new value. */
  always_ff @(posedge clock) begin
    if (reset) begin
      registers[127] <= 0;
      for (i = 0; i < 127; i = i + 1) registers[i] <= 0;
    end else begin
      if (register_write_even_input) registers[rt_address_even_input] <= rt_even_input;
      if (register_write_odd_input) registers[rt_address_odd_input] <= rt_odd_input;
    end
  end
endmodule
