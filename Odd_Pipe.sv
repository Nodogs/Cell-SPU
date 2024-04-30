/***********************************************************************************************************
 * Module: Odd Pipe
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module represents the odd pipeline stage in a processor, handling instructions and forwarding 
 *     logic.
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
 *   - p1_instruction_format, ls1_instruction_format, br1_instruction_format: Instruction formats for units
 *   - p1_enable_register_write, ls1_enable_register_write, br1_enable_register_write: 
 *     Enable register write flags for units
 *   - p1_output_stage4, ls1_output_stage6, br1_output_stage1: Output data for units
 *   - p1_output_register, ls1_output_register, br1_output_register: Output register addresses for units
 *   - p1_write_back, ls1_write_back, br1_write_back: Write flags for units
 ***********************************************************************************************************/

module Odd_Pipe (
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

  input clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  input [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  input [2:0] instr_format;
  // Execution unit of instruction 
  input [1:0] unit;
  // Destination register address
  input [0:6] dest_reg_addr;
  // Values of source registers
  input [0:127] src_reg_a, src_reg_b, store_reg;
  // Immediate value, truncated based on instruction format
  input [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  input enable_reg_write;
  // Program counter from IF stage
  input [7:0] program_counter_input;
  // 1 if initial_ instruction in pair; used for determining order of branch
  input initial_;

  // Write Back Stage
  // Output value of Stage 7
  output logic [0:127] wb_data;
  // Destination register for write back data
  output logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic wb_enable_reg_write;
  // New program counter for branch
  output logic [7:0] program_counter_wb;
  // Was branch taken?
  output logic branch_is_taken;
  // If branch is taken and branch instruction is initial_ in pair, kill twin instruction
  output logic disable_branch;

  // Internal Signals
  // Staging register for forwarded values
  output logic [6:0][0:127] forwarded_data_wb;
  // Destination register for wb_data
  output logic [6:0][0:6] forwarded_address_wb;
  // Will wb_data write to RegTable
  output logic [6:0] forwarded_write_flag_wb;
  // Multiplexed opcode for p1
  logic [0:10] p1_op_code;
  // Multiplexed instr_format for p1
  logic [2:0] p1_instruction_format;
  // Multiplexed enable_reg_write for p1
  logic p1_enable_register_write;
  // Output value of p1 Stage 4
  logic [0:127] p1_output_stage4;
  // Destination register for wb_data from p1
  logic [0:6] p1_output_register;
  // Will wb_data from p1 write to RegTable
  logic p1_write_back;
  // Multiplexed opcode for ls1
  logic [0:10] ls1_op_code;
  // Multiplexed instr_format for ls1
  logic [2:0] ls1_instruction_format;
  // Multiplexed enable_reg_write for ls1
  logic ls1_enable_register_write;
  // Output value of ls Stage 6
  logic [0:127] ls1_output_stage6;
  // Destination register for wb_data from ls1
  logic [0:6] ls1_output_register;
  // Will wb_data from ls1 write to RegTable
  logic ls1_write_back;
  // Multiplexed opcode for br1
  logic [0:10] br1_op_code;
  // Multiplexed instr_format for br1
  logic [2:0] br1_instruction_format;
  // Multiplexed enable_reg_write for br1
  logic br1_enable_register_write;
  // Output value of br1 Stage 1
  logic [0:127] br1_output_stage1;
  // Destination register for wb_data from br1
  logic [0:6] br1_output_register;
  // Will wb_data from br1 write to RegTable
  logic br1_write_back;

  // Destination register for wb_data, delayed for ls1
  output logic [5:0][0:6] delayed_ls1_register_address;
  // Will wb_data write to RegTable, delayed for ls1
  output logic [5:0] delayed_ls1_register_write;
  // Destination register for wb_data, delayed for p1
  output logic [3:0][0:6] delayed_p1_register_address;
  // Will wb_data write to RegTable, delayed for p1
  output logic [3:0] delayed_p1_register_write;

  Permute p1 (
      .clock(clock),
      .reset(reset),
      .op_code(p1_op_code),
      .instr_format(p1_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .imm_value(imm_value),
      .enable_reg_write(p1_enable_register_write),
      .wb_data(p1_output_stage4),
      .wb_reg_addr(p1_output_register),
      .wb_enable_reg_write(p1_write_back),
      .branch_is_taken(branch_is_taken),
      .delayed_rt_addr(delayed_p1_register_address),
      .delayed_enable_reg_write(delayed_p1_register_write)
  );
  Local_Store ls1 (
      .clock(clock),
      .reset(reset),
      .op_code(ls1_op_code),
      .instr_format(ls1_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .store_reg(store_reg),
      .imm_value(imm_value),
      .enable_reg_write(ls1_enable_register_write),
      .wb_data(ls1_output_stage6),
      .wb_reg_addr(ls1_output_register),
      .wb_enable_reg_write(ls1_write_back),
      .branch_is_taken(branch_is_taken),
      .delayed_rt_addr(delayed_ls1_register_address),
      .delayed_enable_reg_write(delayed_ls1_register_write)
  );
  Branch br1 (
      .clock(clock),
      .reset(reset),
      .op_code(br1_op_code),
      .instr_format(br1_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .store_reg(store_reg),
      .imm_value(imm_value),
      .enable_reg_write(br1_enable_register_write),
      .program_counter_input(program_counter_input),
      .wb_data(br1_output_stage1),
      .wb_reg_addr(br1_output_register),
      .wb_enable_reg_write(br1_write_back),
      .program_counter_wb(program_counter_wb),
      .branch_is_taken(branch_is_taken),
      .initial_(initial_),
      .disable_branch(disable_branch)
  );

  always_comb begin
    p1_op_code = 0;
    p1_instruction_format = 0;
    p1_enable_register_write = 0;
    ls1_op_code = 0;
    ls1_instruction_format = 0;
    ls1_enable_register_write = 0;
    br1_op_code = 0;
    br1_instruction_format = 0;
    br1_enable_register_write = 0;

    // Multiplexer to determine which execution unit will process the instruction, based on the 'unit' input
    case (unit)
      // Case when the instruction is going to the Permute Unit (p1)
      2'b00: begin
        p1_op_code = op_code;
        p1_instruction_format = instr_format;
        p1_enable_register_write = enable_reg_write;
      end
      // Case when the instruction is going to the Local Store Unit 1 (ls1)
      2'b01: begin
        ls1_op_code = op_code;
        ls1_instruction_format = instr_format;
        ls1_enable_register_write = enable_reg_write;
      end
      // Case when the instruction is going to the Branch Unit 1 (br1)
      2'b10: begin
        br1_op_code = op_code;
        br1_instruction_format = instr_format;
        br1_enable_register_write = enable_reg_write;
      end
      // Default case: when the instruction is going to the Permute Unit (p1)
      default begin
        p1_op_code = op_code;
        p1_instruction_format = instr_format;
        p1_enable_register_write = enable_reg_write;
      end
    endcase
  end

  always_ff @(posedge clock) begin
    if (reset == 1) begin
      // Reset values
      wb_data <= 0;
      wb_reg_addr <= 0;
      wb_enable_reg_write <= 0;
      foreach (forwarded_data_wb[i]) forwarded_data_wb[i] <= 0;
      foreach (forwarded_address_wb[i]) forwarded_address_wb[i] <= 0;
      foreach (forwarded_write_flag_wb[i]) forwarded_write_flag_wb[i] <= 0;
    end else begin
      // Update values based on forwarding paths
      wb_data <= forwarded_data_wb[6];
      wb_reg_addr <= forwarded_address_wb[6];
      wb_enable_reg_write <= forwarded_write_flag_wb[6];

      // Forwarding paths
      for (int i = 6; i > 0; i = i - 1) begin
        forwarded_data_wb[i] <= forwarded_data_wb[i-1];
        forwarded_address_wb[i] <= forwarded_address_wb[i-1];
        forwarded_write_flag_wb[i] <= forwarded_write_flag_wb[i-1];
      end
      // Specific forwarding path replacements
      casez ({
        ls1_write_back, p1_write_back, br1_write_back
      })
        3'b100: begin
          forwarded_data_wb[5] <= ls1_output_stage6;
          forwarded_address_wb[5] <= ls1_output_register;
          forwarded_write_flag_wb[5] <= ls1_write_back;
        end
        3'b010: begin
          forwarded_data_wb[3] <= p1_output_stage4;
          forwarded_address_wb[3] <= p1_output_register;
          forwarded_write_flag_wb[3] <= p1_write_back;
        end
        3'b001: begin
          forwarded_data_wb[0] <= br1_output_stage1;
          forwarded_address_wb[0] <= br1_output_register;
          forwarded_write_flag_wb[0] <= br1_write_back;
        end
        default: begin
          forwarded_data_wb[0] <= 0;
          forwarded_address_wb[0] <= 0;
          forwarded_write_flag_wb[0] <= 0;
        end
      endcase
    end
  end
endmodule
