/***********************************************************************************************************
 * Module: Pipes
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module orchestrates the pipeline stages of the processor, including the Register File, Instruction
 *     Fetch (IF), Even and Odd instruction decoding, forwarding logic, and branch handling.
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
 *   - initial_odd: Flag indicating if the odd instruction is the initial_ in the pair
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - program_counter_wb: New program counter for branch instruction handling
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - write_back_data_even, write_back_data_odd: Values to be written back to the register table for even and odd pipeline stages
 *   - rt_address_even_wb, rt_address_odd_wb: Destination register addresses for write-back for even and odd stages
 *   - register_write_even_wb, register_write_odd_wb: Flag indicating whether the write-back data will be written to the register table
 *   - forward_values_even, forward_values_odd: Pipe shift registers of values ready to be forwarded for even and odd pipeline stages
 *   - forward_address_even_wb, forward_address_odd_wb: Destination addresses of values to be forwarded for even and odd pipeline stages
 *   - forward_write_even_wb, forward_write_odd_wb: Flag indicating whether forwarded values will be written to the register table for even and odd stages
 *   - disable_branch: Signal indicating if a branch is taken and the branch instruction is initial_ in the pair
 *   - format_is_even_live: Format of the instruction for the even stage, only valid if branch not taken by the initial_ instruction
 *   - op_code_even_live: op_code of the instruction for the even stage, only valid if branch not taken by the initial_ instruction
 *   - delay_rt_address_even, delay_rt_address_odd: Delayed destination register addresses for RAW Error handling
 *   - delay_register_write_even, delay_register_write_odd: Delayed flag indicating whether the instruction writes to the register table for RAW Error handling
 *   - delay_rt_address_fp1, delay_register_write_fp1, delay_integer_fp1: Delayed signals for FP1 stage for RAW Error handling
 *   - delay_rt_address_fx2, delay_register_write_fx2: Delayed signals for FX2 stage for RAW Error handling
 *   - delay_rt_address_b1, delay_register_write_b1: Delayed signals for B1 stage for RAW Error handling
 *   - delay_rt_address_fx1, delay_register_write_fx1: Delayed signals for FX1 stage for RAW Error handling
 *   - delay_rt_address_p1, delay_register_write_p1: Delayed signals for P1 stage for RAW Error handling
 *   - delay_rt_address_ls1, delay_register_write_ls1: Delayed signals for LS1 stage for RAW Error handling
 ***********************************************************************************************************/

module Pipes (
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

  input logic clock, reset;

  // Instructions from the decoder
  input logic [0:31] instruction_even, instruction_odd;
  // Program counter from the Instruction Fetch stage
  input logic [7:0] program_counter;

  // Nets from decode logic
  // Format of instruction
  input logic [2:0] format_is_even, format_is_odd;
  // op_code of instruction (used with format)
  input logic [0:10] op_code_even, op_code_odd;
  // Destination unit of instruction; Order of: FP, FX2, Byte, FX1 (Even); Perm, LS, Br (Odd)
  input logic [1:0] unit_is_even, unit_is_odd;
  // Destination register addresses
  input logic [0:6] rt_address_even, rt_address_odd;
  // Register values from Register Table
  logic [0:127] ra_even, rb_even, rc_even, ra_odd, rb_odd, rt_st_odd;
  // Full possible immediate value (used with format)
  input logic [0:17] immediate_even, immediate_odd;
  // 1 if instruction will write to rt, else 0
  input logic register_write_even, register_write_odd;
  // 1 if odd instruction is initial_ in pair, 0 else; Used for branch flushing
  input initial_odd;

  // Signals for writing back to Register Table
  // Values to be written back to Register Table
  logic [0:127] write_back_data_even, write_back_data_odd;
  // Destination register addresses
  logic [0:6] rt_address_even_wb, rt_address_odd_wb;
  // 1 if instruction will write to rt, else 0
  logic register_write_even_wb, register_write_odd_wb;

  // Pipe shift registers of values ready to be forwarded
  logic [6:0][0:127] forward_values_even, forward_values_odd;
  // Destinations of values to be forwarded
  logic [6:0][0:6] forward_address_even_wb, forward_address_odd_wb;
  // Will forwarded values be written to register?
  logic [6:0] forward_write_even_wb, forward_write_odd_wb;
  // Updated input values
  logic [0:127]
      forward_even_ra,
      forward_even_rb,
      forward_even_rc,
      forward_odd_ra,
      forward_odd_rb,
      forward_odd_store_reg;

  // New program counter for branch
  output logic [7:0] program_counter_wb;
  // Was branch taken?
  output logic branch_is_taken;
  // If branch is taken and branch instruction is initial_ in pair, kill twin instruction
  logic disable_branch;
  // Format of instruction, only valid if branch not taken by initial_ instruction
  logic [2:0] format_is_even_live;
  // op_code of instruction, only valid if branch not taken by initial_ instruction
  logic [0:10] op_code_even_live;

  // Destination register for rt_wb
  output logic [0:6] delay_rt_address_even, delay_rt_address_odd;
  // Will rt_wb write to Register Table
  output logic delay_register_write_even, delay_register_write_odd;
  // Destination register for rt_wb
  output logic [6:0][0:6] delay_rt_address_fp1;
  // Will rt_wb write to Register Table
  output logic [6:0] delay_register_write_fp1;
  // Will fp1 write an int result
  output logic [6:0] delay_integer_fp1;
  // Destination register for rt_wb
  output logic [3:0][0:6] delay_rt_address_fx2;
  // Will rt_wb write to Register Table
  output logic [3:0] delay_register_write_fx2;
  // Destination register for rt_wb
  output logic [3:0][0:6] delay_rt_address_b1;
  // Will rt_wb write to Register Table
  output logic [3:0] delay_register_write_b1;
  // Destination register for rt_wb
  output logic [1:0][0:6] delay_rt_address_fx1;
  // Will rt_wb write to Register Table
  output logic [1:0] delay_register_write_fx1;
  // Destination register for rt_wb
  output logic [3:0][0:6] delay_rt_address_p1;
  // Will rt_wb write to Register Table
  output logic [3:0] delay_register_write_p1;
  // Destination register for rt_wb
  output logic [5:0][0:6] delay_rt_address_ls1;
  // Will rt_wb write to Register Table
  output logic [5:0] delay_register_write_ls1;

  Register_File rf (
      .clock(clock),
      .reset(reset),
      .instruction_even(instruction_even),
      .instruction_odd(instruction_odd),
      .ra_even_input(ra_even),
      .rb_even_input(rb_even),
      .rc_even_input(rc_even),
      .ra_odd_input(ra_odd),
      .rb_odd_input(rb_odd),
      .rt_st_odd_input(rt_st_odd),
      .rt_address_even_input(rt_address_even_wb),
      .rt_address_odd_input(rt_address_odd_wb),
      .rt_even_input(write_back_data_even),
      .rt_odd_input(write_back_data_odd),
      .register_write_even_input(register_write_even_wb),
      .register_write_odd_input(register_write_odd_wb)
  );
  Even_Pipe ev (
      .clock(clock),
      .reset(reset),
      .op_code(op_code_even_live),
      .instr_format(format_is_even_live),
      .unit(unit_is_even),
      .dest_reg_addr(rt_address_even),
      .src_reg_a(forward_even_ra),
      .src_reg_b(forward_even_rb),
      .temporary_register_c(forward_even_rc),
      .imm_value(immediate_even),
      .enable_reg_write(register_write_even),
      .wb_data(write_back_data_even),
      .wb_reg_addr(rt_address_even_wb),
      .wb_enable_reg_write(register_write_even_wb),
      .branch_is_taken(branch_is_taken),
      .forwarded_data_wb(forward_values_even),
      .forwarded_address_wb(forward_address_even_wb),
      .forwarded_write_flag_wb(forward_write_even_wb),
      .delayed_rt_addr_fp1(delay_rt_address_fp1),
      .delayed_enable_reg_write_fp1(delay_register_write_fp1),
      .delayed_int_fp1(delay_integer_fp1),
      .delayed_rt_addr_fx2(delay_rt_address_fx2),
      .delayed_enable_reg_write_fx2(delay_register_write_fx2),
      .delayed_rt_addr_b1(delay_rt_address_b1),
      .delayed_enable_reg_write_b1(delay_register_write_b1),
      .delayed_rt_addr_fx1(delay_rt_address_fx1),
      .delayed_enable_reg_write_fx1(delay_register_write_fx1)
  );
  Odd_Pipe od (
      .clock(clock),
      .reset(reset),
      .op_code(op_code_odd),
      .instr_format(format_is_odd),
      .unit(unit_is_odd),
      .dest_reg_addr(rt_address_odd),
      .src_reg_a(forward_odd_ra),
      .src_reg_b(forward_odd_rb),
      .store_reg(forward_odd_store_reg),
      .imm_value(immediate_odd),
      .enable_reg_write(register_write_odd),
      .program_counter_input(program_counter),
      .wb_data(write_back_data_odd),
      .wb_reg_addr(rt_address_odd_wb),
      .wb_enable_reg_write(register_write_odd_wb),
      .program_counter_wb(program_counter_wb),
      .branch_is_taken(branch_is_taken),
      .forwarded_data_wb(forward_values_odd),
      .forwarded_address_wb(forward_address_odd_wb),
      .forwarded_write_flag_wb(forward_write_odd_wb),
      .initial_(initial_odd),
      .disable_branch(disable_branch),
      .delayed_ls1_register_address(delay_rt_address_p1),
      .delayed_ls1_register_write(delay_register_write_p1),
      .delayed_p1_register_address(delay_rt_address_ls1),
      .delayed_p1_register_write(delay_register_write_ls1)
  );
  Forward fwd (
      .clock(clock),
      .reset(reset),
      .instruction_even(instruction_even),
      .instruction_odd(instruction_odd),
      .ra_even_input(ra_even),
      .rb_even_input(rb_even),
      .rc_even_input(rc_even),
      .ra_odd_input(ra_odd),
      .rb_odd_input(rb_odd),
      .rt_st_odd_input(rt_st_odd),
      .ra_even_fwd_output(forward_even_ra),
      .rb_even_fwd_output(forward_even_rb),
      .rc_even_fwd_output(forward_even_rc),
      .ra_odd_fwd_output(forward_odd_ra),
      .rb_odd_fwd_output(forward_odd_rb),
      .rt_st_odd_fwd_output(forward_odd_store_reg),
      .fw_even_wb_input(forward_values_even),
      .fw_addr_even_wb_input(forward_address_even_wb),
      .fw_write_even_wb_input(forward_write_even_wb),
      .fw_odd_wb_input(forward_values_odd),
      .fw_addr_odd_wb_input(forward_address_odd_wb),
      .fw_write_odd_wb_input(forward_write_odd_wb)
  );

  always_comb begin
    // Check if the branch instruction is taken and if it is the initial_ instruction in the pair
    if (disable_branch == 0) begin
      format_is_even_live = format_is_even;
      op_code_even_live   = op_code_even;
    end else begin
      format_is_even_live = 0;
      op_code_even_live   = 0;
    end
    delay_rt_address_even = rt_address_even;
    delay_register_write_even = register_write_even;
    delay_rt_address_odd = rt_address_odd;
    delay_register_write_odd = register_write_odd;
  end
endmodule
