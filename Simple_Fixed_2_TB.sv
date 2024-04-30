/***********************************************************************************************************
 * Module: Simple Fixed 2 Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module simulates the behavior of the Simple Fixed 2 module, which implements a simple
 *     fixed-point arithmetic unit. It tests various arithmetic and logical operations based on the given 
 *     instructions and inputs. The module contains separate stages for the register file/forwarding and 
 *     write back.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Operation code
 *   - instr_format: Instruction format
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Source register A
 *   - src_reg_b: Source register B
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating register write operation
 *   - branch_is_taken: Flag indicating branch taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back to the register file
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating register write operation in WB stage
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Delayed register data for forwarding
 *   - delayed_rt_addr: Delayed register address for forwarding
 *   - delayed_enable_reg_write: Delayed register write flag for forwarding
 ***********************************************************************************************************/

module Simple_Fixed_2_TB ();

  logic clock, reset;

  //Register File/Forwarding Stage
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

  //Write Back Stage
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


  Simple_Fixed_2 dut (
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
    // Set the opcode for the Shift Left Halfword (shlh) operation
    op_code = 11'b00001011111;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A, Halfwords: 16'h0010
    src_reg_a = 128'h7F8A9BACBDBECFD0E1F2030405060708;
    // Set the value of source register B, Halfwords: 16'h0001
    src_reg_b = 128'h0123456789ABCDEFABCDEF012345678;
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
    op_code = 11'b01000000001;
    @(posedge clock);
    #1;
    op_code = 0;
    @(posedge clock);
    #1;
    op_code = 11'b01000000001;
    @(posedge clock);
    #1;
    op_code = 0;
    @(posedge clock);
    #1;
    op_code = 11'b01000000001;
    @(posedge clock);
    #1;
    // Handling the "Shift Left Word" operation (shl)
    op_code   = 11'b00001011011;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA987654321;
    src_reg_a = 128'hA1B2C3D4E5F67890A1B2C3D4E5F6789;
    @(posedge clock);
    #4;
    // Handling the "Rotate Halfword" operation (roth)
    op_code   = 11'b00001011100;
    src_reg_b = 128'h1234567890ABCDEF1234567890ABCDEF;
    src_reg_a = 128'hFEDCBA0987654321FEDCBA098765432;
    @(posedge clock);
    #4;
    // Handling the "Rotate Word" operation (rot)
    op_code   = 11'b00001011000;
    src_reg_b = 128'h9876543210ABCDEF0123456789ABCDEF;
    src_reg_a = 128'hFEDCBA98765432100123456789ABCDEF;
    @(posedge clock);
    #4;
    // Handling the "Rotate Word" operation (rot)
    op_code   = 11'b00001011000;
    src_reg_b = 128'hABCDEFFEDCBA9876543210ABCDEF012;
    src_reg_a = 128'h0123456789ABCDEFABCDEF012345678;
    @(posedge clock);
    #4;
    // Shift Left Halfword
    op_code   = 11'b00001011111;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA9876543210;
    src_reg_a = 128'h13579BDF2468ACE02468ACE13579BDF;
    @(posedge clock);
    #4;
    // Shift Left Halfword Immediate
    op_code = 11'b00001111111;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'hFEDCBA9876543210ABCDEF012345678;
    src_reg_a = 128'h0123456789ABCDEFABCDEF0123456789;
    @(posedge clock);
    #4;
    // Shift Left Word
    op_code   = 11'b00001011011;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA987654321;
    src_reg_a = 128'hABCDEFFEDCBA9876543210ABCDEFABC;
    @(posedge clock);
    #4;
    // Shift Left Word Immediate
    op_code = 11'b00001111011;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'h5A23F8F5A0CDE28F50E78A5A23F8F5A0;
    src_reg_a = 128'h3B7912D6EFD84AB41021A683B7912D6E;
    @(posedge clock);
    #4;
    // Rotate Word
    op_code   = 11'b00001011000;
    src_reg_b = 128'h8EBA1945D1C7F26378EBA1945D1C7F26;
    src_reg_a = 128'hF4C65329B71D890F9DC17E8F4C65329B;
    @(posedge clock);
    #4;
    // Rotate Word Immediate
    op_code = 11'b00001111000;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'hE2A719385F2B91CDE89E2A719385F2B9;
    src_reg_a = 128'h620DF4EAC1723B856BCA55B620DF4EAC;
    @(posedge clock);
    #4;
    // Rotate Halfword
    op_code   = 11'b00001011100;
    src_reg_b = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    src_reg_a = 128'h478D6AC01257E3FBA7C3DEA478D6AC01;
    @(posedge clock);
    #4;
    // Rotate Halfword Immediate
    op_code = 11'b00001111100;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'hC1E9B54AD6F30E271BDE5A1C1E9B54AD;
    src_reg_a = 128'h3C2FA791D68BFE92EDD6B7B3C2FA791D;
    @(posedge clock);
    #4;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    $stop;
  end
endmodule
