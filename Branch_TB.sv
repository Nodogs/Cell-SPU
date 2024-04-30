/***********************************************************************************************************
 * Module: Branch Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module verifies the functionality of the Branch module by providing stimulus and 
 *     monitoring the outputs.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on instr_format
 *   - instr_format: instr_format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - store_reg: Value of the store register
 *   - imm_value: Immediate value truncated based on instr_format
 *   - enable_reg_write: Flag indicating whether current instruction writes to RegTable
 *   - program_counter_input: Program counter from IF stage
 *   - initial_: 1 if the initial_ instruction in pair; used for determining the order of a branch
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to RegTable
 *   - program_counter_wb: New program counter for branch
 *   - branch_is_taken: Was the branch taken?
 *   - disable_branch: If the branch is taken and branch instruction is initial_ in pair, kill twin instruction
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - rt_delay: Staging register for calculated values
 *   - rt_addr_delay: Destination register for wb_data
 *   - reg_write_delay: Will wb_data write to RegTable
 *   - pc_delay: Staging register for PC
 *   - branch_delay: Was the branch taken?
 ***********************************************************************************************************/

module Branch_TB ();
  logic clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction instr_format
  logic [0:10] op_code;
  // instr_format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers
  logic [0:127] src_reg_a, src_reg_b, store_reg;
  // Immediate value, truncated based on instruction instr_format
  logic [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  logic enable_reg_write;
  // Program counter from IF stage
  logic [7:0] program_counter_input;

  // Write Back Stage
  // Output value of Stage 3
  logic [0:127] wb_data;
  // Destination register for write back data
  logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  logic wb_enable_reg_write;
  // New program counter for branch
  logic [7:0] program_counter_wb;
  // Indicates whether a branch is taken
  logic branch_is_taken;
  // Indicates the initial state or condition
  logic initial_;
  // Indicates whether a branch is to be terminated
  logic disable_branch;

  Branch dut (
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
      program_counter_input,
      wb_data,
      wb_reg_addr,
      wb_enable_reg_write,
      program_counter_wb,
      branch_is_taken,
      initial_,
      disable_branch
  );

  // Set the initial state of the clock to zero
  initial clock = 0;

  // Toggle the clock value every 5 time units to simulate oscillation
  always begin
    #5 clock = ~clock;
    program_counter_input = program_counter_input + 1;
  end

  initial begin
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
