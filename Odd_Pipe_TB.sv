/***********************************************************************************************************
 * Module: Odd Pipe Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module simulates the behavior of the odd pipeline stage in a processor, providing input 
 *     stimuli and capturing output responses.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Operation code for the instruction
 *   - instr_format: Instruction format
 *   - unit: Destination unit for the instruction
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - store_reg: Value of store register
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating whether register write is enabled
 *   - program_counter_input: Program counter from IF stage
 *   - initial_: Flag indicating if the instruction is the initial_ in a pair
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating whether register write is enabled for write-back stage
 *   - program_counter_wb: New program counter for branch
 *   - branch_is_taken: Flag indicating whether branch is taken
 *   - disable_branch: If branch is taken and branch instruction is initial_ in pair, kill twin instruction
 *   - forwarded_data_wb: Forwarded data for write-back stage
 *   - forwarded_address_wb: Forwarded address for write-back stage
 *   - forwarded_write_flag_wb: Forwarded write flag for write-back stage
 *   - delayed_ls1_register_address: Delayed register addresses for ls1 unit
 *   - delayed_ls1_register_write: Delayed enable register write for ls1 unit
 *   - delayed_p1_register_address: Delayed register addresses for p1 unit
 *   - delayed_p1_register_write: Delayed enable register write for p1 unit
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - p1_op_code, ls1_op_code, br1_op_code: Operation codes for units
 *   - p1_instr_format, ls1_instr_format, br1_instr_format: Instruction formats for units
 *   - p1_enable_reg_write, ls1_enable_reg_write, br1_enable_reg_write: 
 *     Enable register write flags for units
 *   - p1_out, ls1_out, br1_out: Output data for units
 *   - p1_addr_out, ls1_addr_out, br1_addr_out: Output register addresses for units
 *   - p1_write_out, ls1_write_out, br1_write_out: Write flags for units
 ***********************************************************************************************************/

module Odd_Pipe_TB ();
  logic clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  logic [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Execution unit of instruction 
  logic [ 1:0] unit;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers
  logic [0:127] src_reg_a, src_reg_b, store_reg, store_reg_odd;
  // Immediate value, truncated based on instruction format
  logic [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  logic enable_reg_write;
  // Program counter from IF stage
  logic [7:0] program_counter_input;
  // Output value of Stage 7
  logic [0:127] wb_data;
  // Destination register for write back data
  logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  logic wb_enable_reg_write;
  // New program counter for branch
  logic [7:0] program_counter_wb;
  // Indicates whether a branch instruction is taken
  logic branch_is_taken;
  // Indicates if data is forwarded from the write-back stage
  logic forwarded_data_wb;
  // Indicates if address is forwarded from the write-back stage
  logic forwarded_address_wb;
  // Indicates if write flag is forwarded from the write-back stage
  logic forwarded_write_flag_wb;
  // Indicates if the system is in initial state
  logic initial_;
  // Indicates if branch operations are disabled
  logic disable_branch;
  // Indicates the delayed register address in Local Store Unit 1
  logic delayed_ls1_register_address;
  // Indicates if register write is delayed in Local Store Unit 1
  logic delayed_ls1_register_write;
  // Indicates the delayed register address in Permute Unit 1
  logic delayed_p1_register_address;
  // Indicates if register write is delayed in Permute Unit 1
  logic delayed_p1_register_write;

  Odd_Pipe dut (
      clock,
      reset,
      op_code,
      instr_format,
      unit,
      dest_reg_addr,
      src_reg_a,
      src_reg_b,
      store_reg,
      imm_value,
      enable_reg_write,
      program_counter_input,
      wb_data,
      wb_reg_addr,
      wb_enable_reg_write,
      program_counter_wb,
      branch_is_taken,
      forwarded_data_wb,
      forwarded_address_wb,
      forwarded_write_flag_wb,
      initial_,
      disable_branch,
      delayed_ls1_register_address,
      delayed_ls1_register_write,
      delayed_p1_register_address,
      delayed_p1_register_write
  );

  // Set the initial state of the clock to zero
  initial clock = 0;

  // Toggle the clock value every 5 time units to simulate oscillation
  always begin
    #5 clock = ~clock;
    program_counter_input = program_counter_input + 1;
  end

  initial begin
    //***********************************************************************************************************	
    //Permute_TB
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
    //***********************************************************************************************************			
    //Local_Store_TB
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
    //***********************************************************************************************************			
    //Branch_TB
    reset = 1;
    instr_format = 3'b000;
    // Set the opcode for the Branch Indirect instruction (bi)
    op_code = 11'b00110101000;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A
    src_reg_a = 128'h5204ED1AF5A69782CD43F0BE5204ED1A;
    // Set the value of source register B
    src_reg_b = 128'hCA3D19E84B26F7A0D5A8C1B7CA3D19E8;
    // Set the value of the store register
    store_reg = 128'h5204ED1AF5A69782CD43F0BE5204ED1A;
    imm_value = 12;
    enable_reg_write = 1;
    program_counter_input = 0;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #1;
    // Branch Relative (br)
    op_code = 9'b001100100;
    @(posedge clock);
    #1;
    // Branch absolute (bra) operation
    op_code = 9'b001100000;
    @(posedge clock);
    #1;
    // Branch Relative and Set Link (brsl)
    op_code = 9'b001100110;
    @(posedge clock);
    #1;
    // Branch Absolute and Set Link (brasl)
    op_code = 9'b001100010;
    @(posedge clock);
    #1;
    // Branch Indirect (bi)
    op_code = 11'b00110101000;
    @(posedge clock);
    #1;
    // Branch If Not Zero Word (brnz)
    op_code = 9'b001000010;
    @(posedge clock);
    #1;
    // Branch If Zero Word (brz)
    op_code = 9'b001000000;
    @(posedge clock);
    #1;
    // Branch If Not Zero Halfword (brnzh)
    op_code = 9'b001000110;
    @(posedge clock);
    #1;
    // Branch If Zero Halfword (brzh)
    op_code = 9'b001000100;
    @(posedge clock);
    #1;
    // Branch Indirect If Not Zero (binz)
    op_code = 11'b00100101001;
    @(posedge clock);
    #1;
    // Branch Indirect If Zero (biz)
    op_code = 11'b00100101000;
    @(posedge clock);
    #1;
    // Branch Indirect If Not Zero Halfword (binzh)
    op_code = 11'b00100101011;
    @(posedge clock);
    #1;
    // Branch Indirect If Zero Halfword (bihz)
    op_code = 11'b00100101010;
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
