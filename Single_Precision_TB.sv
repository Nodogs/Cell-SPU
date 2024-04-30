/***********************************************************************************************************
 * Module: Single Precision Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module serves as the testbench for the single precision unit. It drives 
 *     inputs to the DUT (Design Under Test) and monitors its outputs. The testbench generates various test 
 *     scenarios to verify the functionality of the arithmetic unit.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Operation code
 *   - instr_format: Instruction format
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Source register A
 *   - src_reg_b: Source register B
 *   - temporary_register_c: Temporary register C
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating register write operation
 *   - branch_is_taken: Flag indicating branch taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back to the register file
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating register write operation in WB stage
 *   - int_data: Output data of the module
 *   - int_reg_addr: Destination register address for int_data
 *   - int_enable_reg_write: Flag indicating register write operation for int_data
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Delayed register data for forwarding
 *   - delayed_rt_addr: Delayed register address for forwarding
 *   - delayed_enable_reg_write: Delayed register write flag for forwarding
 *   - int_operation_flag: Flag indicating the type of operation
 ***********************************************************************************************************/

module Single_Precision_TB ();

  logic clock, reset;

  //Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  logic [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers	
  logic [0:127] src_reg_a, src_reg_b, temporary_register_c;
  // Immediate value, truncated based on instruction format
  logic [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table	
  logic enable_reg_write;

  //Write Back Stage
  // Output value of Stage 6
  logic [0:127] wb_data;
  // Destination register for write back data
  logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table	
  logic wb_enable_reg_write;

  // Output value of Stage 7
  logic [0:127] int_data;
  // Destination register for write back data
  logic [0:6] int_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  logic int_enable_reg_write;
  // Indicates whether a branch is taken
  logic branch_is_taken;
  // Represents the delayed register address
  logic delayed_rt_addr;
  // Represents the delayed enable register write signal
  logic delayed_enable_reg_write;
  // Indicates whether an integer operation is flagged
  logic int_operation_flag;


  Single_Precision dut (
      clock,
      reset,
      op_code,
      instr_format,
      dest_reg_addr,
      src_reg_a,
      src_reg_b,
      temporary_register_c,
      imm_value,
      enable_reg_write,
      wb_data,
      wb_reg_addr,
      wb_enable_reg_write,
      int_data,
      int_reg_addr,
      int_enable_reg_write,
      branch_is_taken,
      delayed_rt_addr,
      delayed_enable_reg_write,
      int_operation_flag
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
    // Multiply
    op_code = 11'b01111000100;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'h3F1A6D9E42B7C8F1A1E2D3F4A5B6C7D8;
    src_reg_b = 128'h9B8C7D6E5F4A3B2C1D2E3F4A5B6C7D8;
    temporary_register_c = 128'hF5E4D3C2B1A09876543210ABCDEF012;
    imm_value = 42;
    enable_reg_write = 1;
    #6;
    reset = 0;
    @(posedge clock);
    #8;
    // Multiply Unsigned
    op_code = 11'b01111001100;
    @(posedge clock);
    #8;
    // Multiply Immediate
    op_code = 8'b01110100;
    @(posedge clock);
    #8;
    // Multiply Unsigned Immediate
    op_code = 8'b01110101;
    @(posedge clock);
    #8;
    // Multiply and Add
    op_code = 4'b1100;
    @(posedge clock);
    #8;
    // Multiply High
    op_code = 11'b01111000101;
    @(posedge clock);
    #8;
    // Multiply and Shift Right
    op_code = 11'b01111000111;
    @(posedge clock);
    #8;
    // Multiply High High
    op_code = 11'b01111000110;
    @(posedge clock);
    #8;
    // Floating Add
    op_code = 11'b01011000100;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'hABCDEF0123456789ABCDEF012345678;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA987654321;
    temporary_register_c = 128'h0123456789ABCDEF0123456789ABCDEF;
    imm_value = 173;
    @(posedge clock);
    #8;
    // Floating Subtract
    op_code = 11'b01011000101;
    @(posedge clock);
    #8;
    // Floating Multiply
    op_code = 11'b01011000110;
    @(posedge clock);
    #8;
    // Floating Multiply and Add
    op_code = 4'b1110;
    @(posedge clock);
    #8;
    // Floating Negative Multiply and Subtract
    op_code = 4'b1101;
    @(posedge clock);
    #8;
    // Floating Multiply and Subtract
    op_code = 4'b1111;
    @(posedge clock);
    #8;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #200;
    op_code = 11'b00000000000;
    $stop;
  end
endmodule
