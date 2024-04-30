/***********************************************************************************************************
 * Module: Forward Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *      This testbench module verifies the functionality of the Register File module, which handles register
 *      file operations including forwarding logic in a processor. Forwarding logic allows data to be passed
 *      directly between pipeline stages, reducing stalls caused by data hazards and enhancing processor performance.
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
 *   - rt_addr_even_input: Destination register address to write to for even pipeline stage
 *   - rt_addr_odd_input: Destination register address to write to for odd pipeline stage
 *   - rt_even_input: Value to write to the destination register for the even pipeline stage
 *   - rt_odd_input: Value to write to the destination register for the odd pipeline stage
 *   - reg_write_even_input: Flag indicating whether the even instruction will write to a register
 *   - reg_write_odd_input: Flag indicating whether the odd instruction will write to a register
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

module Forward_TB ();
  logic clock, reset;

  // Input instructions for both even and odd cycles, received from the decoder
  logic [0:31] instruction_even, instruction_odd;
  // Input values for 'ra', 'rb', 'rc' for both even and odd instructions, retrieved from the Register Table
  logic [0:127] ra_even_input, rb_even_input, rc_even_input, ra_odd_input, rb_odd_input;
  // Destination registers for even and odd instructions
  logic [0:6] rt_addr_even, rt_addr_odd;
  // Values to be written to destination registers for even and odd instructions
  logic [0:127] rt_addr_even_input, rt_addr_odd_input;
  // Flags indicating if the even and odd instructions will write to the register table
  logic reg_write_even_input, reg_write_odd_input;
  // Indicates whether the data from the Store will be written to the odd pipe register file input
  logic rt_st_odd_input;
  // Indicates whether the data from the even pipe register file will be written to the odd pipe register file input
  logic rt_even_input;
  // Indicates whether the data from the odd pipe register file will be written to the odd pipe register file input
  logic rt_odd_input;

  Register_File dut (
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
      rt_addr_even_input,
      rt_addr_odd_input,
      rt_even_input,
      rt_odd_input,
      reg_write_even_input,
      reg_write_odd_input
  );

  initial clock = 0;

  always begin
    #5 clock = ~clock;
  end

  initial begin
    reset = 1;
    reg_write_even_input = 0;
    instruction_even = 32'h00000000;
    #6;
    // Enable unit at 11ns
    reset = 0;
    @(posedge clock);
    #1;
    @(posedge clock);
    #1;
    reg_write_even_input = 1;
    // shlh instruction with rb=3, ra=4, rt=5
    instruction_even = 32'b10100111000100100010111010000110;
    rt_addr_even = 7'b000101;
    rt_addr_even_input = 128'h3F8A1B9E2C7F1A5B3D6E9C2F5A8B1C4;
    // lnop instruction
    instruction_odd = 32'b10101011010101101010101010101010;
    reg_write_odd_input = 0;
    rt_addr_odd = 7'b0000000;
    // Writing the value rt_addr_even_input to address 7
    @(posedge clock) #1;
    // Attempting to read the value at address 7 for odd pipe while even pipe is also writing back to the same
    // register file (7). Odd pipe is able to read the value from reg 7 before even pipe writes back a new value to it.
    reg_write_even_input = 1;
    // shlh instruction with rb=3, ra=4, rt=5
    instruction_even = 32'b10100111000100100010111010000110;
    // shlqi instruction with rb=2, ra=5, rt=7
    instruction_odd = 32'b01011010101101010100101010100101;
    rt_addr_even = 7'b0000101;
    rt_addr_odd = 7'b0000101;
    rt_addr_even_input = 128'hA7E5F23D6C9B1A4E5F2C7F1A5B3D6E9;
    rt_addr_odd_input = 128'h1B3A5C7E9A2B4D6F8C9E2A4B6D8F1A5;
    @(posedge clock) #1;
    @(posedge clock) #8;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    $stop;
  end
endmodule
