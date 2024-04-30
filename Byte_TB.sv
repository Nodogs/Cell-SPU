/***********************************************************************************************************
 * Module: Byte Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module verifies the functionality of the Byte module by providing stimulus and 
 *     monitoring the outputs.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - imm_value: Immediate value truncated based on format
 *   - enable_reg_write: Flag indicating whether current instruction writes to RegTable
 *   - branch_is_taken: Was branch taken?
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to RegTable
 *   - delayed_rt_addr: Destination register for wb_data, delayed by one clock cycle
 *   - delayed_enable_reg_write: Will wb_data write to RegTable, delayed by one clock cycle
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Staging register for calculated values, delayed by one clock cycle
 ***********************************************************************************************************/

module Byte_TB ();
  logic clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  logic [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers
  logic [0:127] src_reg_a, src_reg_b;
  // Immediate value, truncated based on instruction format
  logic [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  logic enable_reg_write;

  // Write Back Stage
  // Output value of Stage 3
  logic [0:127] wb_data;
  // Destination register for write back data
  logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  logic wb_enable_reg_write;
  // Indicates whether a branch is taken
  logic branch_is_taken;
  // Represents the delayed register address
  logic delayed_rt_addr;
  // Represents the delayed enable register write signal
  logic delayed_enable_reg_write;


  Byte dut (
      clock,
      reset,
      op_code,
      instr_format,
      dest_reg_addr,
      src_reg_a,
      src_reg_b,
      imm_value,
      enable_reg_write,
      wb_data,
      wb_reg_addr,
      wb_enable_reg_write,
      branch_is_taken,
      delayed_rt_addr,
      delayed_enable_reg_write
  );

  // Set the initial state of the clock to zero
  initial clock = 0;

  // Toggle the clock value every 5 time units to simulate oscillation
  always begin
    #5 clock = ~clock;
  end

  initial begin
    reset = 1;
    instr_format = 3'b000;
    // Set the opcode for the Count Ones in Bytes (cntb) operation
    op_code = 11'b01010110100;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A,  Halfwords: 16'h0010
    src_reg_a = 128'hABCDEF1234567890ABCDEF123456789;
    // Set the value of source register B, Halfwords: 16'h0001
    src_reg_b = 128'hFEDCBA0987654321FEDCBA098765432;
    imm_value = 0;
    enable_reg_write = 1;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #4;
    // Set the opcode for the Average Bytes (avgb) operation
    op_code = 11'b00011010011;
    @(posedge clock);
    #4;
    // Set the opcode for the Absolute Differences of Bytes (absdb) operation
    op_code = 11'b00001010011;
    @(posedge clock);
    #4;
    // Set the opcode for the Sum Bytes into Halfwords (sumb) operation
    op_code = 11'b01001010011;
    @(posedge clock);
    #4;
    // Set the opcode for the No Operation (nop) instruction
    op_code = 0;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    $stop;
  end
endmodule
