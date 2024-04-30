/***********************************************************************************************************
 * Module: Even Pipe
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module represents the even pipeline stage in a processor, handling instructions and forwarding 
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
 *   - temporary_register_c: Value of temporary register C
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating whether register write is enabled
 *   - branch_is_taken: Flag indicating whether branch is taken	
  *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating whether register write is enabled for write-back stage
 *   - forwarded_data_wb: Forwarded data for write-back stage
 *   - forwarded_address_wb: Forwarded address for write-back stage
 *   - forwarded_write_flag_wb: Forwarded write flag for write-back stage
 *   - delayed_rt_addr_fp1: Delayed register addresses for fp1 unit
 *   - delayed_enable_reg_write_fp1: Delayed enable register write for fp1 unit
 *   - delayed_int_fp1: Internal delay for fp1 unit
 *   - delayed_rt_addr_fx2: Delayed register addresses for fx2 unit
 *   - delayed_enable_reg_write_fx2: Delayed enable register write for fx2 unit
 *   - delayed_rt_addr_b1: Delayed register addresses for b1 unit
 *   - delayed_enable_reg_write_b1: Delayed enable register write for b1 unit
 *   - delayed_rt_addr_fx1: Delayed register addresses for fx1 unit
 *   - delayed_enable_reg_write_fx1: Delayed enable register write for fx1 unit
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - fp1_op_code, fx2_op_code, b1_op_code, fx1_op_code: Operation codes for units
 *   - fp1_instruction_format, fx2_instruction_format, b1_instruction_format, fx1_instruction_format: Instruction formats for units
 *   - fp1_enable_register_write, fx2_enable_register_write, b1_enable_register_write, fx1_enable_register_write: 
 *     Enable register write flags for units
 *   - fp1_output_stage6, fx2_output_stage4, b1_output_stage4, fx1_output_stage2: Output data for units
 *   - fp1_output_register, fx2_output_register, b1_output_register, fx1_output_register: Output register addresses for units
 *   - fp1_write_output, fx2_write_output, b1_write_output, fx1_write_output: Write flags for units
 *   - fp1_output_stage7: Internal data for fp1 unit
 *   - fp1_output_register_stage7: Internal register address for fp1 unit
 *   - fp1_write_output_stage7: Internal write flag for fp1 unit
 ***********************************************************************************************************/

module Even_Pipe (
    clock,
    reset,
    op_code,
    instr_format,
    unit,
    dest_reg_addr,
    src_reg_a,
    src_reg_b,
    temporary_register_c,
    imm_value,
    enable_reg_write,
    wb_data,
    wb_reg_addr,
    wb_enable_reg_write,
    branch_is_taken,
    forwarded_data_wb,
    forwarded_address_wb,
    forwarded_write_flag_wb,
    delayed_rt_addr_fp1,
    delayed_enable_reg_write_fp1,
    delayed_int_fp1,
    delayed_rt_addr_fx2,
    delayed_enable_reg_write_fx2,
    delayed_rt_addr_b1,
    delayed_enable_reg_write_b1,
    delayed_rt_addr_fx1,
    delayed_enable_reg_write_fx1
);

  input clock, reset;

  //Register File/Forwarding Stage
  // Decoded opcode, truncated based on the instruction format
  input [0:10] op_code;
  // Format of the instruction, used in conjunction with op_code and imm_value
  input [2:0] instr_format;
  // Execution unit of the instruction
  input [1:0] unit;
  // Address of the destination register
  input [0:6] dest_reg_addr;
  // Values of source registers A, B, and temporary register C
  input [0:127] src_reg_a, src_reg_b, temporary_register_c;
  // Immediate value, truncated based on the instruction format
  input [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  input enable_reg_write;
  // Flag indicating if a branch was taken
  input branch_is_taken;

  // Write Back Stage
  // Output value of Stage 7
  output logic [0:127] wb_data;
  // Address of the destination register for wb_data
  output logic [0:6] wb_reg_addr;
  // Flag indicating if wb_data will be written to the Register Table
  output logic wb_enable_reg_write;

  // Internal Signals
  // Staging register for forwarded values
  output logic [6:0][0:127] forwarded_data_wb;
  // Address of the destination register for forwarded data
  output logic [6:0][0:6] forwarded_address_wb;
  // Flag indicating if forwarded data will be written to the Register Table
  output logic [6:0] forwarded_write_flag_wb;

  // Multiplexed opcode for the FP1 execution unit
  logic [0:10] fp1_op_code;
  // Multiplexed instruction format for the FP1 execution unit
  logic [2:0] fp1_instruction_format;
  // Flag indicating if the FP1 execution unit will write to the Register Table
  logic fp1_enable_register_write;
  // Output value of Stage 6 in the FP1 execution unit
  logic [0:127] fp1_output_stage6;
  // Destination register for the output data of the FP1 execution unit
  logic [0:6] fp1_output_register;
  // Flag indicating if the output data of the FP1 execution unit will be written to the Register Table
  logic fp1_write_output;
  // Output value of Stage 7 in the FP1 execution unit
  logic [0:127] fp1_output_stage7;
  // Destination register for the output data of Stage 7 in the FP1 execution unit
  logic [0:6] fp1_output_register_stage7;
  // Flag indicating if the output data of Stage 7 in the FP1 execution unit will be written to the Register Table
  logic fp1_write_output_stage7;
  // Multiplexed opcode for the FX2 execution unit
  logic [0:10] fx2_op_code;
  // Multiplexed instruction format for the FX2 execution unit
  logic [2:0] fx2_instruction_format;
  // Flag indicating if the FX2 execution unit will write to the Register Table
  logic fx2_enable_register_write;
  // Output value of Stage 4 in the FX2 execution unit
  logic [0:127] fx2_output_stage4;
  // Destination register for the output data of the FX2 execution unit
  logic [0:6] fx2_output_register;
  // Flag indicating if the output data of the FX2 execution unit will be written to the Register Table
  logic fx2_write_output;
  // Multiplexed opcode for the B1 execution unit
  logic [0:10] b1_op_code;
  // Multiplexed instruction format for the B1 execution unit
  logic [2:0] b1_instruction_format;
  // Flag indicating if the B1 execution unit will write to the Register Table
  logic b1_enable_register_write;
  // Output value of Stage 4 in the B1 execution unit
  logic [0:127] b1_output_stage4;
  // Destination register for the output data of the B1 execution unit
  logic [0:6] b1_output_register;
  // Flag indicating if the output data of the B1 execution unit will be written to the Register Table
  logic b1_write_output;
  // Multiplexed opcode for the FX1 execution unit
  logic [0:10] fx1_op_code;
  // Multiplexed instruction format for the FX1 execution unit
  logic [2:0] fx1_instruction_format;
  // Flag indicating if the FX1 execution unit will write to the Register Table
  logic fx1_enable_register_write;
  // Output value of Stage 2 in the FX1 execution unit
  logic [0:127] fx1_output_stage2;
  // Destination register for the output data of the FX1 execution unit
  logic [0:6] fx1_output_register;
  // Flag indicating if the output data of the FX1 execution unit will be written to the Register Table
  logic fx1_write_output;

  // Internal Signals for Handling Read-After-Write (RAW) Errors
  // Delayed destination register address for the FP1 execution unit
  output logic [6:0][0:6] delayed_rt_addr_fp1;
  // Delayed flag indicating if the FP1 execution unit will write to the Register Table
  output logic [6:0] delayed_enable_reg_write_fp1;
  // Delayed flag indicating if the FP1 execution unit will write an integer result
  output logic [6:0] delayed_int_fp1;
  // Delayed destination register address for the FX2 execution unit
  output logic [3:0][0:6] delayed_rt_addr_fx2;
  // Delayed flag indicating if the FX2 execution unit will write to the Register Table
  output logic [3:0] delayed_enable_reg_write_fx2;
  // Delayed destination register address for the B1 execution unit
  output logic [3:0][0:6] delayed_rt_addr_b1;
  // Delayed flag indicating if the B1 execution unit will write to the Register Table
  output logic [3:0] delayed_enable_reg_write_b1;
  // Delayed destination register address for the FX1 execution unit
  output logic [1:0][0:6] delayed_rt_addr_fx1;
  // Delayed flag indicating if the FX1 execution unit will write to the Register Table
  output logic [1:0] delayed_enable_reg_write_fx1;

  Single_Precision fp1 (
      .clock(clock),
      .reset(reset),
      .op_code(fp1_op_code),
      .instr_format(fp1_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .temporary_register_c(temporary_register_c),
      .imm_value(imm_value),
      .enable_reg_write(fp1_enable_register_write),
      .wb_data(fp1_output_stage6),
      .wb_reg_addr(fp1_output_register),
      .wb_enable_reg_write(fp1_write_output),
      .int_data(fp1_output_stage7),
      .int_reg_addr(fp1_output_register_stage7),
      .int_enable_reg_write(fp1_write_output_stage7),
      .branch_is_taken(branch_is_taken),
      .delayed_rt_addr(delayed_rt_addr_fp1),
      .delayed_enable_reg_write(delayed_enable_reg_write_fp1),
      .int_operation_flag(delayed_int_fp1)
  );
  Simple_Fixed_2 fx2 (
      .clock(clock),
      .reset(reset),
      .op_code(fx2_op_code),
      .instr_format(fx2_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .imm_value(imm_value),
      .enable_reg_write(fx2_enable_register_write),
      .wb_data(fx2_output_stage4),
      .wb_reg_addr(fx2_output_register),
      .wb_enable_reg_write(fx2_write_output),
      .branch_is_taken(branch_is_taken),
      .delayed_rt_addr(delayed_rt_addr_fx2),
      .delayed_enable_reg_write(delayed_enable_reg_write_fx2)
  );
  Byte b1 (
      .clock(clock),
      .reset(reset),
      .op_code(b1_op_code),
      .instr_format(b1_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .imm_value(imm_value),
      .enable_reg_write(b1_enable_register_write),
      .wb_data(b1_output_stage4),
      .wb_reg_addr(b1_output_register),
      .wb_enable_reg_write(b1_write_output),
      .branch_is_taken(branch_is_taken),
      .delayed_rt_addr(delayed_rt_addr_b1),
      .delayed_enable_reg_write(delayed_enable_reg_write_b1)
  );
  Simple_Fixed_1 fx1 (
      .clock(clock),
      .reset(reset),
      .op_code(fx1_op_code),
      .instr_format(fx1_instruction_format),
      .dest_reg_addr(dest_reg_addr),
      .src_reg_a(src_reg_a),
      .src_reg_b(src_reg_b),
      .store_reg(temporary_register_c),
      .imm_value(imm_value),
      .enable_reg_write(fx1_enable_register_write),
      .wb_data(fx1_output_stage2),
      .wb_reg_addr(fx1_output_register),
      .wb_enable_reg_write(fx1_write_output),
      .branch_is_taken(branch_is_taken),
      .delayed_rt_addr(delayed_rt_addr_fx1),
      .delayed_enable_reg_write(delayed_enable_reg_write_fx1)
  );

  always_comb begin
    fp1_op_code = 0;
    fp1_instruction_format = 0;
    fp1_enable_register_write = 0;
    fx2_op_code = 0;
    fx2_instruction_format = 0;
    fx2_enable_register_write = 0;
    b1_op_code = 0;
    b1_instruction_format = 0;
    b1_enable_register_write = 0;
    fx1_op_code = 0;
    fx1_instruction_format = 0;
    fx1_enable_register_write = 0;

    // Multiplexer to determine which execution unit will process the instruction, based on the 'unit' input
    case (unit)
      // Case when the instruction is going to the Single Precision Unit 1 (FP1)
      2'b00: begin
        fp1_op_code = op_code;
        fp1_instruction_format = instr_format;
        fp1_enable_register_write = enable_reg_write;
      end
      // Case when the instruction is going to the Simple Fixed Point Unit 2 (FX2)
      2'b01: begin
        fx2_op_code = op_code;
        fx2_instruction_format = instr_format;
        fx2_enable_register_write = enable_reg_write;
      end
      // Case when the instruction is going to the Byte Unit 1 (B1)
      2'b10: begin
        b1_op_code = op_code;
        b1_instruction_format = instr_format;
        b1_enable_register_write = enable_reg_write;
      end
      // Case when the instruction is going to the Simple Fixed Point Unit 1 (FX1)
      2'b11: begin
        fx1_op_code = op_code;
        fx1_instruction_format = instr_format;
        fx1_enable_register_write = enable_reg_write;
      end
    endcase
  end

  always_ff @(posedge clock) begin
    // Initialize forwarding paths to 0
    for (int i = 0; i < 7; i++) begin
      forwarded_data_wb[i] <= 0;
      forwarded_address_wb[i] <= 0;
      forwarded_write_flag_wb[i] <= 0;
    end
    if (reset == 1) begin
      // Reset values
      wb_data <= 0;
      wb_reg_addr <= 0;
      wb_enable_reg_write <= 0;
    end else begin
      // Update values based on forwarding paths
      wb_data <= forwarded_data_wb[6];
      wb_reg_addr <= forwarded_address_wb[6];
      wb_enable_reg_write <= forwarded_write_flag_wb[6];

      // Forwarding paths
      if (fp1_write_output_stage7 == 1) begin
        forwarded_data_wb[6] <= fp1_output_stage7;
        forwarded_address_wb[6] <= fp1_output_register_stage7;
        forwarded_write_flag_wb[6] <= fp1_write_output_stage7;
      end else if (fp1_write_output == 1) begin
        forwarded_data_wb[5] <= fp1_output_stage6;
        forwarded_address_wb[5] <= fp1_output_register;
        forwarded_write_flag_wb[5] <= fp1_write_output;
      end else if (fx2_write_output == 1) begin
        forwarded_data_wb[3] <= fx2_output_stage4;
        forwarded_address_wb[3] <= fx2_output_register;
        forwarded_write_flag_wb[3] <= fx2_write_output;
      end else if (b1_write_output == 1) begin
        forwarded_data_wb[3] <= b1_output_stage4;
        forwarded_address_wb[3] <= b1_output_register;
        forwarded_write_flag_wb[3] <= b1_write_output;
      end else if (fx1_write_output == 1) begin
        forwarded_data_wb[1] <= fx1_output_stage2;
        forwarded_address_wb[1] <= fx1_output_register;
        forwarded_write_flag_wb[1] <= fx1_write_output;
      end
      // Propagate values through forwarding paths
      for (int i = 6; i > 0; i = i - 1) begin
        forwarded_data_wb[i-1] <= forwarded_data_wb[i];
        forwarded_address_wb[i-1] <= forwarded_address_wb[i];
        forwarded_write_flag_wb[i-1] <= forwarded_write_flag_wb[i];
      end
    end
  end
endmodule
