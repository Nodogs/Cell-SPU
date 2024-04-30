/***********************************************************************************************************
 * Module: Permute Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module serves as the testbench for the Permute module. It provides stimulus to the Permute module
 *     by supplying input signals and monitors the outputs for correctness.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on instr_format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - imm_value: Immediate value truncated based on instr_format
 *   - enable_reg_write: Flag indicating whether the current instruction writes to the register table
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to the register table
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Staging register for calculated values
 *   - delayed_rt_addr: Destination register for wb_data, delayed by one clock cycle
 *   - delayed_enable_reg_write: Will wb_data write to the register table, delayed by one clock cycle
 ***********************************************************************************************************/

module Permute_TB ();
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


  Permute dut (
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
    for (int i = 0; i < 8; i++) src_reg_b[i*16+:16] = src_reg_b[i*16+:16] + 1;
  end

  initial begin
    reset = 1;
    instr_format = 3'b000;
    // Set the opcode for the Shift Left Halfword (shlh) operation
    op_code = 11'b01010110100;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A, Halfwords: 16'h0010
    src_reg_a = 128'h5A7F38E2B0C4D69E18F2C86B5A7F38E2;
    // Set the value of source register B, Halfwords: 16'h0001
    src_reg_b = 128'h1E9D83CAB4267F0E2B8A64C11E9D83CA;
    imm_value = 0;
    enable_reg_write = 1;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #1;
    // Set the opcode for the No Operation (nop) instruction
    op_code = 0;
    @(posedge clock);
    #1;
    op_code   = 11'b01000000001;
    src_reg_a = 128'hC7063E4F1B28D5A3F9A87F41C7063E4F;
    @(posedge clock);
    #1;
    src_reg_a = 128'hEF4528AB1D3976F825B6D843EF4528AB;
    @(posedge clock);
    #1;
    op_code   = 11'b00111011111;
    src_reg_a = 128'h1A73BF5D68294E1BCA053B921A73BF5D;
    @(posedge clock);
    #1;
    // Set the opcode for the "Shift Left Quadword by Bits Immediate" operation (shlqbii rt, src_reg_a, value)
    op_code = 11'b00111111011;
    // Set the destination register address to $r6
    dest_reg_addr = 7'b0000110;
    // Set the instruction format to RI7-type
    instr_format = 2;
    // Set the immediate value to 3
    imm_value = 7'b0000011;
    src_reg_a = 128'hB7D84231F6A905E378CD720EB7D84231;
    @(posedge clock);
    #4;
    // Testcase for Shift Left Quadword by Bits (shlqbi rt, src_reg_a, src_reg_b)
    src_reg_b = 128'h04987A6DB123FEDCFAE9080D04987A6D;
    src_reg_a = 128'h96FC4D1E82AB0E64F3D89B2A96FC4D1E;
    op_code = 11'b00111011011;
    dest_reg_addr = 7'b0000101;
    @(posedge clock);
    #4;
    // Set the opcode for the "Shift Left Quadword by Bits Immediate" operation (shlqbii rt, src_reg_a, value)
    op_code = 11'b00111111011;
    // Set the destination register address to $r6
    dest_reg_addr = 7'b0000110;
    // Set the instruction format to RI7-type
    instr_format = 2;
    // Set the immediate value to 3
    imm_value = 7'b0000011;
    src_reg_a = 128'h3E50187ABF6C9D24E6A3B59B3E50187A;
    @(posedge clock);
    #4;
    // Testcase for Shift Left Quadword by Bytes (shlqby rt, src_reg_a, src_reg_b)
    src_reg_b = 128'h8D7E20BC64F5A1C3E9D0B73F8D7E20BC;
    src_reg_a = 128'hFAC825D7B39461E20E37A7B5FAC825D7;
    op_code = 11'b00111011111;
    dest_reg_addr = 7'b0000110;
    @(posedge clock);
    #4;
    // Testcase for Shift Left Quadword by Bytes from Bit Shift Count (shlqbybi rt, src_reg_a, src_reg_b)
    src_reg_b = 128'h0E6D9CAB724F158D37A109380E6D9CAB;
    src_reg_a = 128'h29C673E10A4FEDB21B359A5629C673E1;
    op_code = 11'b00111001111;
    dest_reg_addr = 7'b0000111;
    @(posedge clock);
    #4;
    // Testcase for Rotate Quadword by Bytes (rotqby rt, src_reg_a, src_reg_b)
    src_reg_b = 128'hB804ED1AF5A69782CD43F0BEB804ED1A;
    src_reg_a = 128'hA6E9D8013FCB24A857D0ECA3A6E9D801;
    op_code = 11'b00111011100;
    dest_reg_addr = 7'b0001000;
    @(posedge clock);
    #4;
    // Testcase for Rotate Quadword by Bytes from Bit Shift Count (rotqbybi rt, src_reg_a, src_reg_b)
    src_reg_b = 128'h2D18C9F6E3A5B470F1E862492D18C9F6;
    src_reg_a = 128'hBEAF572C4D1E0F38C62B91E6BEAF572C;
    op_code = 11'b00111001100;
    dest_reg_addr = 7'b0001001;
    @(posedge clock);
    #4;
    // Set the opcode for the "Rotate Quadword by Bytes Immediate" operation (rotqbyi rt, src_reg_a, imm7)
    op_code = 11'b00111111100;
    // Set the destination register address to $r6
    dest_reg_addr = 7'b0000110;
    // Set the instruction format to RI7-type
    instr_format = 2;
    // Set the immediate value to 3
    imm_value = 7'b0000011;
    src_reg_a = 128'h2A49E815D0F3CB0E7ABD3C9D2A49E815;
    @(posedge clock);
    #4;
    op_code = 0;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    $stop;
  end
endmodule
