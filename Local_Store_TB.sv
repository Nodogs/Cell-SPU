/***********************************************************************************************************
 * Module: Local Store Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module verifies the functionality of the Local Store module by providing stimulus and
 *     monitoring the outputs.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on instr_format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - store_reg: Value to be stored in memory
 *   - imm_value: Immediate value truncated based on instr_format
 *   - enable_reg_write: Flag indicating whether the current instruction writes to the register table
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to the register table
 *   - delayed_rt_addr: Destination register for wb_data, delayed by one clock cycle
 *   - delayed_enable_reg_write: Will wb_data write to the register table, delayed by one clock cycle
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Staging register for calculated values, delayed by one clock cycle
 *   - local_mem: 32KB local memory for storing quadwords
 *   - program_counter: Current program counter value
 ***********************************************************************************************************/

module Local_Store_TB ();
  logic clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  logic [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers
  logic [0:127] src_reg_a, src_reg_b, store_reg_odd;
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
  // Represents the store register signal
  logic store_reg;
  // Indicates whether a branch is taken
  logic branch_is_taken;
  // Represents the delayed register address
  logic delayed_rt_addr;
  // Represents the delayed enable register write signal
  logic delayed_enable_reg_write;


  Local_Store dut (
      clock,
      reset,
      op_code,
      instr_format,
      dest_reg_addr,
      src_reg_a,
      src_reg_b,
      store_reg,
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
    // Set the opcode for the Store Quadword (stqx) operation
    op_code = 11'b00101000100;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    //Halfwords: 16'h0001
    src_reg_a = 128'hF9EBA5CD6078C31425F79B42F9EBA5CD;
    //Halfwords: 16'h0001
    src_reg_b = 128'hD5B91E846F7A3CE590D2E4D9D5B91E84;
    store_reg_odd = 128'h1F34BE0A6D8C92F7B5A19E1A1F34BE0A;
    imm_value = 12;
    enable_reg_write = 1;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #1;
    // Load Quadword (d-form)
    op_code = 8'b00110100;
    instr_format = 4'b1100;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'hC39A50EB8FD64B12A7EFC3BBC39A50EB;
    imm_value = 7'b0000000;
    @(posedge clock);
    #1;
    // Load Quadword (x-form)
    op_code = 11'b00111000100;
    instr_format = 4'b1101;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'h7DC680A1EF59D438A1CDE2A27DC680A1;
    src_reg_b = 128'h9C86514EBDA07F53A1E25DC69C86514E;
    @(posedge clock);
    #1;
    // Load Quadword (a-form)
    op_code = 9'b001100001;
    instr_format = 4'b1110;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'h9C13F6DB0E24A85CB6F9A2F69C13F6DB;
    imm_value = 7'b0000000;
    @(posedge clock);
    #1;
    // Load Quadword Instruction Relative (a-form)
    op_code = 9'b001100111;
    instr_format = 4'b1111;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'hF6D5803C29B6E8C14A3F01D7F6D5803C;
    imm_value = 7'b0000000;
    @(posedge clock);
    #1;
    // Store Quadword (d-form)
    op_code = 8'b00100100;
    instr_format = 4'b1100;
    src_reg_a = 128'h86E2A70D5F1D48CB9F3E0A5A86E2A70D;
    store_reg_odd = 128'h8F7E20BC64F5A1C3E9D0B73F8F7E20BC;
    imm_value = 7'b0000000;
    @(posedge clock);
    #1;
    // Store Quadword (x-form)
    op_code = 11'b00101000100;
    instr_format = 4'b1101;
    src_reg_a = 128'hCA3D19E84B26F7A0D5A8C1B7CA3D19E8;
    src_reg_b = 128'h5204ED1AF5A69782CD43F0BE5204ED1A;
    store_reg_odd = 128'hCA3D19E84B26F7A0D5A8C1B7CA3D19E8;
    @(posedge clock);
    #1;
    // Store Quadword (a-form)
    op_code = 9'b001000001;
    instr_format = 4'b1110;
    src_reg_a = 128'h5204ED1AF5A69782CD43F0BE5204ED1A;
    store_reg_odd = 128'hCA3D19E84B26F7A0D5A8C1B7CA3D19E8;
    imm_value = 7'b0000000;
    @(posedge clock);
    #1;
    // Store Quadword Instruction Relative (a-form)
    op_code = 9'b001000111;
    instr_format = 4'b1111;
    src_reg_a = 128'h5204ED1AF5A69782CD43F0BE5204ED1A;
    store_reg_odd = 128'hCA3D19E84B26F7A0D5A8C1B7CA3D19E8;
    imm_value = 7'b0000000;
    @(posedge clock);
    #1;
    // Set the opcode for the No Operation (nop) instruction
    op_code = 0;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    $stop;
  end
endmodule
