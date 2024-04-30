/***********************************************************************************************************
 * Module: Decode
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module decodes instructions in a processor, extracting opcode, register addresses, immediate values,
 *     and other relevant information.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - instruction: Array of 32-bit instructions
 *   - program_counter: Current program counter
 *   - stall_program_counter: Stalled program counter
 *   - stall: Signal indicating whether the pipeline is stalled
 *   - branch_is_taken_reg: Signal indicating whether a branch is taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - stall_program_counter: Stalled program counter
 *   - stall: Signal indicating whether the pipeline is stalled
 *   - branch_is_taken_reg: Signal indicating whether a branch is taken
 *   - instruction_next: Next instruction to be executed in the pipeline
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - instruction_even, instruction_odd: Instructions from the decoder
 *   - op_code_even, op_code_odd: Opcode of instructions
 *   - register_write_even, register_write_odd: Signal indicating whether instructions will write to registers
 *   - immediate_even, immediate_odd: Immediate values
 *   - rt_address_even, rt_address_odd: Destination register addresses
 *   - unit_is_even, unit_is_odd: Destination execution units
 *   - format_is_even, format_is_odd: Instruction formats
 *   - initial_odd_out: Signal indicating whether the odd instruction is the first instruction in a pair
 *   - stall_var: Internal signal indicating pipeline stall
 *   - stall_program_counter_var: Internal signal indicating stalled program counter
 ***********************************************************************************************************/

module Decode (
    clock,
    reset,
    instruction,
    program_counter,
    stall_program_counter,
    stall,
    branch_is_taken_reg
);

  input logic clock, reset;

  input logic [0:31] instruction[0:1];
  logic [0:31] instruction_next[0:1], instruction_dec[0:1], instruction_next_reg[0:1];
  // Instructions received from the decoder
  logic [0:31] instruction_even, instruction_odd, instruction_odd_issue, instruction_even_issue;

  //Signals for handling branches
  // New program counter value for branch operations
  logic [7:0] program_counter_wb;
  output logic [7:0] stall_program_counter;
  output logic stall;
  // Indicates if a branch was taken in the instruction
  output logic branch_is_taken_reg;
  // Flag to indicate if a branch was taken in the instruction
  logic branch_is_taken;
  // Indicates if the odd instruction is the first opcode in the pair
  logic initial_odd, initial_odd_out;
  logic stall_var;
  logic [7:0] stall_program_counter_var;

  // 8-bit program counter for tracking the current state
  input logic [7:0] program_counter;

  //Nets from decode logic
  // Format of the instruction for even and odd cases
  logic [2:0] format_is_even, format_is_odd;
  // Opcode of the instruction for even and odd cases (used with instruction_format)
  logic [0:10] op_code_even, op_code_odd;
  // Destination execution unit of instruction
  logic [1:0] unit_is_even, unit_is_odd;
  // Destination register addresses for even and odd instructions
  logic [0:6] rt_address_even, rt_address_odd;
  // Full possible immediate value for even and odd instructions (used with instruction_format)
  logic [0:17] immediate_even, immediate_odd;
  // Indicates if the even or odd instruction will write to the target register
  logic register_write_even, register_write_odd;
  // Due to how the 'finished' signal is detected, a workaround is needed to prevent flagging after reset
  logic first_cycle;
  // New program counter for handling stalls
  logic [7:0] program_counter_dec, program_counter_pipe;

  localparam [0:31] NOP = 32'b01000000001000000000000000000000;
  localparam [0:31] LNOP = 32'b00000000001000000000000000000000;

  //Internal Signals for Handling RAW Errors
  // Destination register for writeback stage for even and odd instructions
  logic [0:6] delay_rt_address_even, delay_rt_address_odd;
  // Flags to delay register write for even and odd instructions
  logic delay_register_write_even, delay_register_write_odd;
  // Flags to indicate if the first or second signal should be stalled due to a Read-After-Write (RAW) Errors
  logic raw_first_stall, raw_second_stall;
  // Flags to indicate if the first or second signal should be stalled due to a Read-After-Write (RAW) or structural Errors
  logic first_stall, second_stall;
  // Destination register for writeback stage in the floating point unit 1
  logic [6:0][0:6] delay_rt_address_fp1;
  // Flags to delay register write in the floating point unit 1
  logic [6:0] delay_register_write_fp1;
  // Flags to indicate if the floating point unit 1 will write an integer result
  logic [6:0] delay_integer_fp1;
  // Destination register for writeback stage in the fixed point unit 2
  logic [3:0][0:6] delay_rt_address_fx2;
  // Flags to delay register write in the fixed point unit 2
  logic [3:0] delay_register_write_fx2;
  // Destination register for writeback stage in the byte unit 1
  logic [3:0][0:6] delay_rt_address_b1;
  // Flags to delay register write in the byte unit 1
  logic [3:0] delay_register_write_b1;
  // Destination register for writeback stage in the fixed point unit 1
  logic [1:0][0:6] delay_rt_address_fx1;
  // Flags to delay register write in the fixed point unit 1
  logic [1:0] delay_register_write_fx1;
  // Destination register for writeback stage in the permute unit 1
  logic [3:0][0:6] delay_rt_address_p1;
  // Flags to delay register write in the permute unit 1
  logic [3:0] delay_register_write_p1;
  // Destination register for writeback stage in the load/store unit 1
  logic [5:0][0:6] delay_rt_address_ls1;
  // Flags to delay register write in the load/store unit 1
  logic [5:0] delay_register_write_ls1;

  typedef struct {
    logic [0:31] instruction;
    logic [0:10] op_code;
    logic reg_write;
    // Flags to indicate if the even and odd instructions are valid
    logic is_even_valid, is_odd_valid;
    logic [0:17] immediate;
    logic [0:6] target_address;
    logic [1:0] execution_unit;
    logic [2:0] instruction_format;
    logic [0:6] source_a_address, source_b_address, source_c_address;
    // Flags to indicate if the source registers A, B, and C are read in this instruction
    logic source_a_valid, source_b_valid, source_c_valid;
  } op_code;

  op_code first_opcode, second_opcode;

  Pipes pipe (
      .clock(clock),
      .reset(reset),
      .program_counter(program_counter_pipe),
      .instruction_even(instruction_even),
      .instruction_odd(instruction_odd),
      .program_counter_wb(program_counter_wb),
      .branch_is_taken(branch_is_taken),
      .op_code_even(op_code_even),
      .op_code_odd(op_code_odd),
      .unit_is_even(unit_is_even),
      .unit_is_odd(unit_is_odd),
      .rt_address_even(rt_address_even),
      .rt_address_odd(rt_address_odd),
      .format_is_even(format_is_even),
      .format_is_odd(format_is_odd),
      .immediate_even(immediate_even),
      .immediate_odd(immediate_odd),
      .register_write_even(register_write_even),
      .register_write_odd(register_write_odd),
      .initial_odd(initial_odd_out),
      .delay_rt_address_even(delay_rt_address_even),
      .delay_register_write_even(delay_register_write_even),
      .delay_rt_address_odd(delay_rt_address_odd),
      .delay_register_write_odd(delay_register_write_odd),
      .delay_rt_address_fp1(delay_rt_address_fp1),
      .delay_register_write_fp1(delay_register_write_fp1),
      .delay_integer_fp1(delay_integer_fp1),
      .delay_rt_address_fx2(delay_rt_address_fx2),
      .delay_register_write_fx2(delay_register_write_fx2),
      .delay_rt_address_b1(delay_rt_address_b1),
      .delay_register_write_b1(delay_register_write_b1),
      .delay_rt_address_fx1(delay_rt_address_fx1),
      .delay_register_write_fx1(delay_register_write_fx1),
      .delay_rt_address_p1(delay_rt_address_p1),
      .delay_register_write_p1(delay_register_write_p1),
      .delay_rt_address_ls1(delay_rt_address_ls1),
      .delay_register_write_ls1(delay_register_write_ls1)
  );

  always_ff @(posedge clock) begin : decode_op
    if (first_opcode.is_even_valid) begin
      instruction_even <= first_opcode.instruction;
      op_code_even <= first_opcode.op_code;
      register_write_even <= first_opcode.reg_write;
      immediate_even <= first_opcode.immediate;
      rt_address_even <= first_opcode.target_address;
      unit_is_even <= first_opcode.execution_unit;
      format_is_even <= first_opcode.instruction_format;
      initial_odd_out <= 0;
    end else if (second_opcode.is_even_valid) begin
      instruction_even <= second_opcode.instruction;
      op_code_even <= second_opcode.op_code;
      register_write_even <= second_opcode.reg_write;
      immediate_even <= second_opcode.immediate;
      rt_address_even <= second_opcode.target_address;
      unit_is_even <= second_opcode.execution_unit;
      format_is_even <= second_opcode.instruction_format;
    end else begin
      instruction_even <= 0;
      op_code_even <= 0;
      register_write_even <= 0;
      immediate_even <= 0;
      rt_address_even <= 0;
      unit_is_even <= 0;
      format_is_even <= 0;
    end
    if (first_opcode.is_odd_valid) begin
      instruction_odd <= first_opcode.instruction;
      op_code_odd <= first_opcode.op_code;
      register_write_odd <= first_opcode.reg_write;
      immediate_odd <= first_opcode.immediate;
      rt_address_odd <= first_opcode.target_address;
      unit_is_odd <= first_opcode.execution_unit;
      format_is_odd <= first_opcode.instruction_format;
      initial_odd_out <= 1;
    end else if (second_opcode.is_odd_valid) begin
      instruction_odd <= second_opcode.instruction;
      op_code_odd <= second_opcode.op_code;
      register_write_odd <= second_opcode.reg_write;
      immediate_odd <= second_opcode.immediate;
      rt_address_odd <= second_opcode.target_address;
      unit_is_odd <= second_opcode.execution_unit;
      format_is_odd <= second_opcode.instruction_format;
      initial_odd_out <= 0;
    end else begin
      instruction_odd <= 0;
      op_code_odd <= 0;
      register_write_odd <= 0;
      immediate_odd <= 0;
      rt_address_odd <= 0;
      unit_is_odd <= 0;
      format_is_odd <= 0;
    end
    instruction_next_reg <= instruction_next;
    stall <= stall_var;
    stall_program_counter <= stall_program_counter_var;
    branch_is_taken_reg <= branch_is_taken;
    program_counter_pipe <= program_counter_dec;
    // Flag is always high after reset and low otherwise
    first_cycle <= reset;
  end

  //Decode logic
  always_comb begin
    first_stall  = 0;
    second_stall = 0;
    if (reset == 1) begin
      stall_var = 0;
      stall_program_counter_var = 0;
      initial_odd = 0;
      first_opcode = inspect_one(0);
      second_opcode = inspect_one(0);
      instruction_next[0] = 0;
      instruction_next[1] = 0;
    end else begin
      if (branch_is_taken == 1) begin
        stall_program_counter_var = program_counter_wb + 2;
        stall_var = 1;
        instruction_next[0] = 0;
        instruction_next[1] = 0;
        first_opcode = inspect_one(0);
        second_opcode = inspect_one(0);
      end else begin
        if (stall == 1) begin
          instruction_dec[0] = instruction_next_reg[0];
          instruction_dec[1] = instruction_next_reg[1];
          stall_var = 0;
          program_counter_dec = stall_program_counter;
        end else begin
          instruction_dec[0]  = instruction[0];
          instruction_dec[1]  = instruction[1];
          program_counter_dec = program_counter;
        end
        if ((instruction_dec[0] != 0)) begin
          // Checking if the first opcode instruction is present in the decoded instruction
          first_opcode = inspect_one(instruction_dec[0]);
          if (first_opcode.source_a_valid) begin
            for (int i = 0; i <= 4; i++) begin
              if ((first_opcode.source_a_address == delay_rt_address_fp1[i]) && (delay_register_write_fp1[i] && delay_integer_fp1[i])) begin
                first_stall = 1;
              end
              if ((i < 4) &&
								(((first_opcode.source_a_address == delay_rt_address_ls1[i]) && delay_register_write_ls1[i]) ||
								((first_opcode.source_a_address == delay_rt_address_fp1[i]) && delay_register_write_fp1[i]))) begin
                first_stall = 1;
              end
              if ((i < 2) &&
								(((first_opcode.source_a_address == delay_rt_address_fx2[i]) && delay_register_write_fx2[i]) ||
								((first_opcode.source_a_address == delay_rt_address_b1[i]) && delay_register_write_b1[i]) ||
								((first_opcode.source_a_address == delay_rt_address_p1[i]) && delay_register_write_p1[i]))) begin
                first_stall = 1;
              end
            end
            if ((first_opcode.source_a_address == delay_rt_address_even) && delay_register_write_even) begin
              first_stall = 1;
            end
            if ((first_opcode.source_a_address == delay_rt_address_odd) && delay_register_write_odd) begin
              first_stall = 1;
            end
          end
          if (first_opcode.source_b_valid) begin
            for (int i = 0; i <= 4; i++) begin
              if ((first_opcode.source_b_address == delay_rt_address_fp1[i]) && (delay_register_write_fp1[i] && delay_integer_fp1[i])) begin
                first_stall = 1;
              end
              if ((i < 4) &&
								(((first_opcode.source_b_address == delay_rt_address_ls1[i]) && delay_register_write_ls1[i]) ||
								((first_opcode.source_b_address == delay_rt_address_fp1[i]) && delay_register_write_fp1[i]))) begin
                first_stall = 1;
              end
              if ((i < 2) &&
								(((first_opcode.source_b_address == delay_rt_address_fx2[i]) && delay_register_write_fx2[i]) ||
								((first_opcode.source_b_address == delay_rt_address_b1[i]) && delay_register_write_b1[i]) ||
								((first_opcode.source_b_address == delay_rt_address_p1[i]) && delay_register_write_p1[i]))) begin
                first_stall = 1;
              end
            end
            if ((first_opcode.source_b_address == delay_rt_address_even) && delay_register_write_even) begin
              first_stall = 1;
            end
            if ((first_opcode.source_b_address == delay_rt_address_odd) && delay_register_write_odd) begin
              first_stall = 1;
            end
          end
          if (first_opcode.source_c_valid) begin
            for (int i = 0; i <= 4; i++) begin
              if ((first_opcode.source_c_address == delay_rt_address_fp1[i]) && (delay_register_write_fp1[i] && delay_integer_fp1[i])) begin
                first_stall = 1;
              end

              if ((i < 4) &&
								(((first_opcode.source_c_address == delay_rt_address_ls1[i]) && delay_register_write_ls1[i]) ||
								((first_opcode.source_c_address == delay_rt_address_fp1[i]) && delay_register_write_fp1[i]))) begin
                first_stall = 1;
              end
              if ((i < 2) &&
								(((first_opcode.source_c_address == delay_rt_address_fx2[i]) && delay_register_write_fx2[i]) ||
								((first_opcode.source_c_address == delay_rt_address_b1[i]) && delay_register_write_b1[i]) ||
								((first_opcode.source_c_address == delay_rt_address_p1[i]) && delay_register_write_p1[i]))) begin
                first_stall = 1;
              end
            end
            if ((first_opcode.source_c_address == delay_rt_address_even) && delay_register_write_even) begin
              first_stall = 1;
            end
            if ((first_opcode.source_c_address == delay_rt_address_odd) && delay_register_write_odd) begin
              first_stall = 1;
            end
          end
        end else begin
          first_opcode = inspect_one(0);
        end
        if ((instruction_dec[1] != 0)) begin
          second_opcode = inspect_one(instruction_dec[1]);
          // Checking for structural Errors. If both the first and second opcode are valid in the same pipeline (even or odd), a structural Error occurs.
          if ((second_opcode.is_even_valid && first_opcode.is_even_valid) || (second_opcode.is_odd_valid && first_opcode.is_odd_valid)) begin
            second_stall = 1;
          end
					// Checking for Write-After-Write (WAW) data Error. If both the first and second opcode are writing to the same register, a WAW Error occurs.
          else if (first_opcode.reg_write && second_opcode.reg_write && (first_opcode.target_address == second_opcode.target_address)) begin
            second_stall = 1;
          end else begin
            if (second_opcode.source_a_valid) begin
              for (int i = 0; i <= 4; i++) begin
                if ((second_opcode.source_a_address == delay_rt_address_fp1[i]) && (delay_register_write_fp1[i] && delay_integer_fp1[i])) begin
                  second_stall = 1;
                end
                if ((i < 4) &&
									(((second_opcode.source_a_address == delay_rt_address_ls1[i]) && delay_register_write_ls1[i]) ||
									((second_opcode.source_a_address == delay_rt_address_fp1[i]) && delay_register_write_fp1[i]))) begin
                  second_stall = 1;
                end
                if ((i < 2) &&
									(((second_opcode.source_a_address == delay_rt_address_fx2[i]) && delay_register_write_fx2[i]) ||
									((second_opcode.source_a_address == delay_rt_address_b1[i]) && delay_register_write_b1[i]) ||
									((second_opcode.source_a_address == delay_rt_address_p1[i]) && delay_register_write_p1[i]))) begin
                  second_stall = 1;
                end
              end
              if ((second_opcode.source_a_address == delay_rt_address_even) && delay_register_write_even) begin
                second_stall = 1;
              end
              if ((second_opcode.source_a_address == delay_rt_address_odd) && delay_register_write_odd) begin
                second_stall = 1;
              end
              if ((second_opcode.source_a_address == first_opcode.target_address) && first_opcode.reg_write) begin
                second_stall = 1;
              end
            end
            if (second_opcode.source_b_valid) begin
              for (int i = 0; i <= 4; i++) begin
                if ((second_opcode.source_b_address == delay_rt_address_fp1[i]) && (delay_register_write_fp1[i] && delay_integer_fp1[i])) begin
                  second_stall = 1;
                end
                if ((i < 4) &&
									(((second_opcode.source_b_address == delay_rt_address_ls1[i]) && delay_register_write_ls1[i]) ||
									((second_opcode.source_b_address == delay_rt_address_fp1[i]) && delay_register_write_fp1[i]))) begin
                  second_stall = 1;
                end
                if ((i < 2) &&
									(((second_opcode.source_b_address == delay_rt_address_fx2[i]) && delay_register_write_fx2[i]) ||
									((second_opcode.source_b_address == delay_rt_address_b1[i]) && delay_register_write_b1[i]) ||
									((second_opcode.source_b_address == delay_rt_address_p1[i]) && delay_register_write_p1[i]))) begin
                  second_stall = 1;
                end
              end
              if ((second_opcode.source_b_address == delay_rt_address_even) && delay_register_write_even) begin
                second_stall = 1;
              end
              if ((second_opcode.source_b_address == delay_rt_address_odd) && delay_register_write_odd) begin
                second_stall = 1;
              end
              if ((second_opcode.source_b_address == first_opcode.target_address) && first_opcode.reg_write) begin
                second_stall = 1;
              end
            end
            if (second_opcode.source_c_valid) begin
              for (int i = 0; i <= 4; i++) begin
                if ((second_opcode.source_c_address == delay_rt_address_fp1[i]) && (delay_register_write_fp1[i] && delay_integer_fp1[i])) begin
                  second_stall = 1;
                end
                if ((i < 4) &&
									(((second_opcode.source_c_address == delay_rt_address_ls1[i]) && delay_register_write_ls1[i]) ||
									((second_opcode.source_c_address == delay_rt_address_fp1[i]) && delay_register_write_fp1[i]))) begin
                  second_stall = 1;
                end
                if ((i < 2) &&
									(((second_opcode.source_c_address == delay_rt_address_fx2[i]) && delay_register_write_fx2[i]) ||
									((second_opcode.source_c_address == delay_rt_address_b1[i]) && delay_register_write_b1[i]) ||
									((second_opcode.source_c_address == delay_rt_address_p1[i]) && delay_register_write_p1[i]))) begin
                  second_stall = 1;
                end
              end
              if ((second_opcode.source_c_address == delay_rt_address_even) && delay_register_write_even) begin
                second_stall = 1;
              end
              if ((second_opcode.source_c_address == delay_rt_address_odd) && delay_register_write_odd) begin
                second_stall = 1;
              end
              if ((second_opcode.source_c_address == first_opcode.target_address) && first_opcode.reg_write) begin
                second_stall = 1;
              end
            end
          end
        end else begin
          second_opcode = inspect_one(0);
        end
        if (first_stall) begin
          stall_program_counter_var = program_counter_dec;
          stall_var = 1;
          instruction_next[0] = instruction_dec[0];
          instruction_next[1] = instruction_dec[1];
          first_opcode = inspect_one(0);
          second_opcode = inspect_one(0);
        end else if (second_stall) begin
          stall_program_counter_var = program_counter_dec;
          stall_var = 1;
          instruction_next[0] = 0;
          instruction_next[1] = instruction_dec[1];
          second_opcode = inspect_one(0);
        end else begin
          stall_var = 0;
        end
      end
    end
  end

  function op_code inspect_one(input logic [0:31] instruction);
    if (reset == 1) begin
      inspect_one.op_code = 0;
      inspect_one.is_even_valid = 1;
      inspect_one.is_odd_valid = 1;
    end
    //Even decoding
    inspect_one.reg_write = 1;
    inspect_one.target_address = instruction[25:31];
    inspect_one.source_a_address = instruction[18:24];
    inspect_one.source_b_address = instruction[11:17];
    inspect_one.source_c_address = instruction[25:31];
    inspect_one.instruction = instruction;
    inspect_one.is_even_valid = 1;
    //alternate nop
    if (instruction == 0) begin
      inspect_one.instruction_format = 0;
      inspect_one.source_a_valid = 0;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 0;
      inspect_one.execution_unit = 0;
      inspect_one.target_address = 0;
      inspect_one.immediate = 0;
      inspect_one.reg_write = 0;
      inspect_one.is_even_valid = 0;
      // End of RRR-type instructions handling
    end  // Handling the "Floating Multiply and Add" operation (fma)
    else if (instruction[0:3] == 4'b1110) begin
      inspect_one.instruction_format = 1;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 1;
      inspect_one.source_c_valid = 1;
      inspect_one.op_code = 4'b1110;
      inspect_one.execution_unit = 0;
      inspect_one.target_address = instruction[4:10];
    end  // Handling the "Floating Negative Multiply and Subtract" operation (fnms)
    else if (instruction[0:3] == 4'b1101) begin
      inspect_one.instruction_format = 1;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 1;
      inspect_one.source_c_valid = 1;
      inspect_one.op_code = 4'b1101;
      inspect_one.execution_unit = 0;
      inspect_one.target_address = instruction[4:10];
    end  // Handling the "Floating Multiply and Subtract" operation (fms)
    else if (instruction[0:3] == 4'b1111) begin
      inspect_one.instruction_format = 1;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 1;
      inspect_one.source_c_valid = 1;
      inspect_one.op_code = 4'b1111;
      inspect_one.execution_unit = 0;
      inspect_one.target_address = instruction[4:10];
      // End of RI18-type instructions handling
    end  // Handling the "Immediate Load Address" operation (ila)						
    else if (instruction[0:6] == 7'b0100001) begin
      inspect_one.instruction_format = 6;
      inspect_one.source_a_valid = 0;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 7'b0100001;
      inspect_one.execution_unit = 3;
      inspect_one.immediate = $signed(instruction[7:24]);
      // End of RI8-type instructions handling
    end  //		// Handling the "Add Extended" operation (addx)
    else if (instruction[0:10] == 11'b01101000000) begin
      inspect_one.instruction_format = 0;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 1;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 11'b01101000000;
      inspect_one.execution_unit = 0;
      inspect_one.immediate = 0;
    end  //		// Handling the "Carry Generate" operation (cg)
    else if (instruction[0:11] == 11'b00011000010) begin
      inspect_one.instruction_format = 0;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 1;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 11'b00011000010;
      inspect_one.execution_unit = 0;
      inspect_one.immediate = 0;
    end  //		// Handling the "Borrow Generate" operation (bg)
    else if (instruction[0:11] == 11'b00001000010) begin
      inspect_one.instruction_format = 0;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 1;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 11'b00001000010;
      inspect_one.execution_unit = 0;
      inspect_one.immediate = 0;
    end  //		// Handling the "Subtract from Extended" operation (sfx)
    else if (instruction[0:11] == 11'b01101000001) begin
      inspect_one.instruction_format = 3;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 11'b01101000001;
      inspect_one.execution_unit = 0;
      inspect_one.immediate = $signed(instruction[10:17]);
      // End of RI16-type instructions handling
    end  // Handling the "Immediate Load Halfword" operation (ilh)
    else if (instruction[0:8] == 9'b010000011) begin
      inspect_one.instruction_format = 5;
      inspect_one.source_a_valid = 0;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 9'b010000011;
      inspect_one.execution_unit = 3;
      inspect_one.immediate = $signed(instruction[9:24]);
    end  // Handling the "Immediate Load Word" operation (il)
    else if (instruction[0:8] == 9'b010000001) begin
      inspect_one.instruction_format = 5;
      inspect_one.source_a_valid = 0;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 9'b010000001;
      inspect_one.execution_unit = 3;
      inspect_one.immediate = $signed(instruction[9:24]);
    end  // Handling the "Immediate Load Halfword Upper" operation (ilhu)
    else if (instruction[0:8] == 9'b010000010) begin
      inspect_one.instruction_format = 5;
      inspect_one.source_a_valid = 0;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 9'b010000010;
      inspect_one.execution_unit = 3;
      inspect_one.immediate = $signed(instruction[9:24]);
    end  // Handling the "Immediate OR Halfword Lower" operation (iohl)
    else if (instruction[0:8] == 9'b011000001) begin
      inspect_one.instruction_format = 5;
      inspect_one.source_a_valid = 0;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.op_code = 9'b011000001;
      inspect_one.execution_unit = 3;
      inspect_one.immediate = $signed(instruction[9:24]);
    end else begin
      // Setting the instruction format for RI10-type instructions
      inspect_one.instruction_format = 4;
      inspect_one.source_a_valid = 1;
      inspect_one.source_b_valid = 0;
      inspect_one.source_c_valid = 0;
      inspect_one.immediate = $signed(instruction[8:17]);
      case (instruction[0:7])
        // Handling the "Multiply Immediate" operation (mpyi)
        8'b01110100: begin
          inspect_one.op_code = 8'b01110100;
          inspect_one.execution_unit = 0;
        end
        // Handling the "Multiply Unsigned Immediate" operation (mpyui)
        8'b01110101: begin
          inspect_one.op_code = 8'b01110101;
          inspect_one.execution_unit = 0;
        end
        // Handling the "Add Halfword Immediate" operation (ahi)
        8'b00011101: begin
          inspect_one.op_code = 8'b00011101;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Add Word Immediate" operation (ai)
        8'b00011100: begin
          inspect_one.op_code = 8'b00011100;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Subtract from Halfword Immediate" operation (sfhi)
        8'b00001101: begin
          inspect_one.op_code = 8'b00001101;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Subtract from Word Immediate" operation (sfi)
        8'b00001100: begin
          inspect_one.op_code = 8'b00001100;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Equal Halfword Immediate" operation (ceqhi)
        8'b01111101: begin
          inspect_one.op_code = 8'b01111101;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Equal Word Immediate" operation (ceqi)
        8'b01111100: begin
          inspect_one.op_code = 8'b01111100;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Greater Than Halfword Immediate" operation (cgthi)
        8'b01001101: begin
          inspect_one.op_code = 8'b01001101;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Greater Than Word Immediate" operation (cgti)
        8'b01001100: begin
          inspect_one.op_code = 8'b01001100;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Logical Greater Than Byte Immediate" operation (clgtbi)
        8'b01011110: begin
          inspect_one.op_code = 8'b01011110;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Logical Greater Than Halfword Immediate" operation (clgthi)
        8'b01011101: begin
          inspect_one.op_code = 8'b01011101;
          inspect_one.execution_unit = 3;
        end
        // Handling the "Compare Logical Greater Than Word Immediate" operation (clgti)
        8'b01011100: begin
          inspect_one.op_code = 8'b01011100;
          inspect_one.execution_unit = 3;
        end
        default: inspect_one.instruction_format = 7;
      endcase
      if (inspect_one.instruction_format == 7) begin
        // Setting the instruction format for RR-type instructions
        inspect_one.instruction_format = 0;
        inspect_one.source_a_valid = 1;
        inspect_one.source_b_valid = 1;
        inspect_one.source_c_valid = 0;
        case (instruction[0:10])
          // Handling the "Multiply" operation (mpy)
          11'b01111000100: begin
            inspect_one.op_code = 11'b01111000100;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Multiply and Add" operation (mpya)
          4'b1100: begin
            inspect_one.op_code = 4'b1100;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Multiply and Shift Right" operation (mpys)
          11'b01111000111: begin
            inspect_one.op_code = 11'b01111000111;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Multiply High High" operation (mpyhh)
          11'b01111000110: begin
            inspect_one.op_code = 11'b01111000110;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Multiply Unsigned" operation (mpyu)
          11'b01111001100: begin
            inspect_one.op_code = 11'b01111001100;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Multiply High" operation (mpyh)
          11'b01111000101: begin
            inspect_one.op_code = 11'b01111000101;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Floating Add" operation (fa)
          11'b01011000100: begin
            inspect_one.op_code = 11'b01011000100;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Floating Subtract" operation (fs)
          11'b01011000101: begin
            inspect_one.op_code = 11'b01011000101;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Floating Multiply" operation (fm)
          11'b01011000110: begin
            inspect_one.op_code = 11'b01011000110;
            inspect_one.execution_unit = 0;
          end
          // Handling the "Shift Left Halfword" operation (shlh)
          11'b00001011111: begin
            inspect_one.op_code = 11'b00001011111;
            inspect_one.execution_unit = 1;
          end
          // Handling the "Shift Left Word" operation (shl)
          11'b00001011011: begin
            inspect_one.op_code = 11'b00001011011;
            inspect_one.execution_unit = 1;
          end
          // Handling the "Rotate Halfword" operation (roth)
          11'b00001011100: begin
            inspect_one.op_code = 11'b00001011100;
            inspect_one.execution_unit = 1;
          end
          // Handling the "Rotate Word" operation (rot)
          11'b00001011000: begin
            inspect_one.op_code = 11'b00001011000;
            inspect_one.execution_unit = 1;
          end
          // Handling the "Count Ones in Bytes" operation (cntb)
          11'b01010110100: begin
            inspect_one.op_code = 11'b01010110100;
            inspect_one.execution_unit = 2;
            inspect_one.source_b_valid = 0;
          end
          // Handling the "Average Bytes" operation (avgb)
          11'b00011010011: begin
            inspect_one.op_code = 11'b00011010011;
            inspect_one.execution_unit = 2;
          end
          // Handling the "Absolute Differences of Bytes" operation (absdb)
          11'b00001010011: begin
            inspect_one.op_code = 11'b00001010011;
            inspect_one.execution_unit = 2;
          end
          // Handling the "Sum Bytes into Halfwords" operation (sumb)
          11'b01001010011: begin
            inspect_one.op_code = 11'b01001010011;
            inspect_one.execution_unit = 2;
          end
          // Handling the "Add Halfword" operation (ah)
          11'b00011001000: begin
            inspect_one.op_code = 11'b00011001000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Add Word" operation (a)
          11'b00011000000: begin
            inspect_one.op_code = 11'b00011000000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Subtract from Halfword" operation (sfh)
          11'b00001001000: begin
            inspect_one.op_code = 11'b00001001000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Subtract from Word" operation (sf)
          11'b00001000000: begin
            inspect_one.op_code = 11'b00001000000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "AND" operation (and)
          11'b00011000001: begin
            inspect_one.op_code = 11'b00011000001;
            inspect_one.execution_unit = 3;
          end
          // Handling the "OR" operation (or)
          11'b00001000001: begin
            inspect_one.op_code = 11'b00001000001;
            inspect_one.execution_unit = 3;
          end
          // Handling the "XOR" operation (xor)
          11'b01001000001: begin
            inspect_one.op_code = 11'b01001000001;
            inspect_one.execution_unit = 3;
          end
          // Handling the "NAND" operation (nand)
          11'b00011001001: begin
            inspect_one.op_code = 11'b00011001001;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Equal Halfword" operation (ceqh)
          11'b01111001000: begin
            inspect_one.op_code = 11'b01111001000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Equal Word" operation (ceq)
          11'b01111000000: begin
            inspect_one.op_code = 11'b01111000000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Greater Than Halfword" operation (cgth)
          11'b01001001000: begin
            inspect_one.op_code = 11'b01001001000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Greater Than Word" operation (cgt)
          11'b01001000000: begin
            inspect_one.op_code = 11'b01001000000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Logical Greater Than Byte" operation (clgtb)
          11'b01011010000: begin
            inspect_one.op_code = 11'b01011010000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Logical Greater Than Halfword" operation (clgth)
          11'b01011001000: begin
            inspect_one.op_code = 11'b01011001000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "Compare Logical Greater Than Word" operation (clgt)
          11'b01011000000: begin
            inspect_one.op_code = 11'b01011000000;
            inspect_one.execution_unit = 3;
          end
          // Handling the "No Operation" (Execute) operation (nop)
          11'b01000000001: begin
            inspect_one.op_code = 11'b01000000001;
            inspect_one.execution_unit = 0;
            inspect_one.reg_write = 0;
          end
          // Handling the "No Operation" (Load) operation (lnop)
          11'b00000000001: begin
            inspect_one.op_code = 11'b00000000001;
            inspect_one.execution_unit = 0;
            inspect_one.reg_write = 0;
          end
          default: inspect_one.instruction_format = 7;
        endcase
        if (inspect_one.instruction_format == 7) begin
          // Setting the instruction format for RI7-type instructions
          inspect_one.instruction_format = 2;
          inspect_one.source_a_valid = 1;
          inspect_one.source_b_valid = 0;
          inspect_one.source_c_valid = 0;
          inspect_one.immediate = $signed(instruction[11:17]);
          case (instruction[0:10])
            // Handling the "Shift Left Word Immediate" operation (shli)
            11'b00001111011: begin
              inspect_one.op_code = 11'b00001111011;
              inspect_one.execution_unit = 1;
            end
            // Handling the "Shift Left Halfword Immediate" operation (shlhi)
            11'b00001111111: begin
              inspect_one.op_code = 11'b00001111111;
              inspect_one.execution_unit = 1;
            end
            // Handling the "Rotate Halfword Immediate" operation (rothi)
            11'b00001111100: begin
              inspect_one.op_code = 11'b00001111100;
              inspect_one.execution_unit = 1;
            end
            // Handling the "Rotate Word Immediate" operation (roti)
            11'b00001111000: begin
              inspect_one.op_code = 11'b00001111000;
              inspect_one.execution_unit = 1;
            end
            default begin
              inspect_one.instruction_format = 0;
              inspect_one.source_a_valid = 0;
              inspect_one.source_b_valid = 0;
              inspect_one.source_c_valid = 0;
              inspect_one.op_code = 0;
              inspect_one.execution_unit = 0;
              inspect_one.target_address = 0;
              inspect_one.immediate = 0;
              inspect_one.is_even_valid = 0;
            end
          endcase
        end
      end
    end
    // Handling odd decoding
    if (inspect_one.is_even_valid == 0) begin
      inspect_one.target_address = instruction[25:31];
      inspect_one.source_a_address = instruction[18:24];
      inspect_one.source_b_address = instruction[11:17];
      inspect_one.source_c_address = instruction[25:31];
      inspect_one.reg_write = 1;
      inspect_one.is_odd_valid = 1;
      if (instruction == 0) begin
        inspect_one.instruction_format = 0;
        inspect_one.source_a_valid = 0;
        inspect_one.source_b_valid = 0;
        inspect_one.source_c_valid = 0;
        inspect_one.op_code = 0;
        inspect_one.execution_unit = 0;
        inspect_one.target_address = 0;
        inspect_one.immediate = 0;
        inspect_one.reg_write = 0;
        inspect_one.is_odd_valid = 0;
        // Handling the end of RI10-type instructions
      end  // Handling the "Load Quadword (d-form)" operation (lqd)
      else if (instruction[0:7] == 8'b00110100) begin
        inspect_one.instruction_format = 4;
        inspect_one.source_a_valid = 1;
        inspect_one.source_b_valid = 0;
        inspect_one.source_c_valid = 0;
        inspect_one.op_code = 8'b00110100;
        inspect_one.execution_unit = 1;
        inspect_one.immediate = $signed(instruction[8:17]);
      end  // Handling the "Store Quadword (d-form)" operation (stqd)
      else if (instruction[0:7] == 8'b00100100) begin
        inspect_one.instruction_format = 4;
        inspect_one.source_a_valid = 1;
        inspect_one.source_b_valid = 0;
        inspect_one.source_c_valid = 1;
        inspect_one.op_code = 8'b00100100;
        inspect_one.execution_unit = 1;
        inspect_one.immediate = $signed(instruction[8:17]);
        inspect_one.reg_write = 0;
      end else begin
        // Setting the instruction format for RI16-type instructions
        inspect_one.instruction_format = 5;
        inspect_one.source_a_valid = 0;
        inspect_one.source_b_valid = 0;
        inspect_one.source_c_valid = 0;
        inspect_one.immediate = $signed(instruction[9:24]);
        case (instruction[0:8])
          // Handling the "Load Quadword (a-form)" operation (lqa)
          9'b001100001: begin
            inspect_one.op_code = 9'b001100001;
            inspect_one.execution_unit = 1;
          end
          // Handling the "Store Quadword (a-form)" operation (stqa)
          9'b001000001: begin
            inspect_one.op_code = 9'b001000001;
            inspect_one.execution_unit = 1;
            inspect_one.reg_write = 0;
            inspect_one.source_c_valid = 1;
          end
          // Handling the "Load Quadword Instruction Relative (a-form)" operation (lqr)
          9'b001100111: begin
            inspect_one.op_code = 9'b001100111;
            inspect_one.execution_unit = 1;
            inspect_one.reg_write = 0;
            inspect_one.source_c_valid = 1;
          end
          // Handling the "Store Quadword Instruction Relative (a-form)" operation (stqr)
          9'b001000111: begin
            inspect_one.op_code = 9'b001000111;
            inspect_one.execution_unit = 1;
            inspect_one.reg_write = 0;
            inspect_one.source_c_valid = 1;
          end
          // Handling the "Branch Relative" operation (br)
          9'b001100100: begin
            inspect_one.op_code = 9'b001100100;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
          end
          // Handling the "Branch Absolute" operation (bra)
          9'b001100000: begin
            inspect_one.op_code = 9'b001100000;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
          end
          // Handling the "Branch Indirect If Not Zero" operation (binz)
          11'b00100101001: begin
            inspect_one.op_code = 11'b00100101001;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
          end
          // Handling the "Branch Indirect If Not Zero Halfword" operation (binzh)
          11'b00100101011: begin
            inspect_one.op_code = 11'b00100101011;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
          end
          // Handling the "Branch If Zero Halfword" operation (brhz)
          9'b001000100: begin
            inspect_one.op_code = 9'b001000100;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
          end
          // Handling the "Branch Absolute and Set Link" operation (brasl)
          9'b001100010: begin
            inspect_one.op_code = 9'b001100010;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
          end
          // Handling the "Branch Relative and Set Link" operation (brsl)
          9'b001100110: begin
            inspect_one.op_code = 9'b001100110;
            inspect_one.execution_unit = 2;
          end
          // Handling the "Branch If Not Zero Word" operation (brnz)
          9'b001000010: begin
            inspect_one.op_code = 9'b001000010;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
            inspect_one.source_c_valid = 1;
          end
          // Handling the "Branch If Not Zero Halfword" operation (brnzh)
          9'b001000110: begin
            inspect_one.op_code = 9'b001000110;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
            inspect_one.source_c_valid = 1;
          end
          // Handling the "Branch If Zero Word" operation (brz)
          9'b001000000: begin
            inspect_one.op_code = 9'b001000000;
            inspect_one.execution_unit = 2;
            inspect_one.reg_write = 0;
            inspect_one.source_c_valid = 1;
          end
          default: inspect_one.instruction_format = 7;
        endcase
        if (inspect_one.instruction_format == 7) begin
          // Setting the instruction format for RR-type instructions
          inspect_one.instruction_format = 0;
          inspect_one.source_a_valid = 1;
          inspect_one.source_b_valid = 1;
          inspect_one.source_c_valid = 0;
          case (instruction[0:10])
            // Handling the "Shift Left Quadword by Bits" operation (shlqbi)
            11'b00111011011: begin
              inspect_one.op_code = 11'b00111011011;
              inspect_one.execution_unit = 0;
            end
            // Handling the "Shift Left Quadword by Bytes" operation (shlqby)
            11'b00111011111: begin
              inspect_one.op_code = 11'b00111011111;
              inspect_one.execution_unit = 0;
            end
            // Handling the "Rotate Quadword by Bytes" operation (rotqby)
            11'b00111011100: begin
              inspect_one.op_code = 11'b00111011100;
              inspect_one.execution_unit = 0;
            end
            // Handling the "Load Quadword (x-form)" operation (lqx)
            11'b00111000100: begin
              inspect_one.op_code = 11'b00111000100;
              inspect_one.execution_unit = 1;
            end
            // Handling the "Store Quadword (x-form)" operation (stqx)
            11'b00101000100: begin
              inspect_one.op_code = 11'b00101000100;
              inspect_one.execution_unit = 1;
              inspect_one.reg_write = 0;
              inspect_one.source_c_valid = 1;
            end
            // Handling the "Branch Indirect" operation (bi)
            11'b00110101000: begin
              inspect_one.op_code = 11'b00110101000;
              inspect_one.execution_unit = 2;
              inspect_one.reg_write = 0;
              inspect_one.source_b_valid = 0;
            end
            // Handling the "Branch Indirect If Zero" operation (biz)
            11'b00100101000: begin
              inspect_one.op_code = 11'b00100101000;
              inspect_one.execution_unit = 2;
              inspect_one.reg_write = 0;
              inspect_one.source_b_valid = 0;
            end
            // Handling the "Branch Indirect If Zero Halfword" operation (bihz)
            11'b00100101010: begin
              inspect_one.op_code = 11'b00100101010;
              inspect_one.execution_unit = 2;
              inspect_one.reg_write = 0;
              inspect_one.source_b_valid = 0;
            end
            default: inspect_one.instruction_format = 7;
          endcase
          if (inspect_one.instruction_format == 7) begin
            // Setting the instruction format for RI7-type instructions
            inspect_one.instruction_format = 2;
            inspect_one.source_a_valid = 1;
            inspect_one.source_b_valid = 0;
            inspect_one.source_c_valid = 0;
            inspect_one.immediate = $signed(instruction[11:17]);
            case (instruction[0:10])
              // Handling the "Shift Left Quadword by Bits" operation (shlqbi)
              11'b00111011011: begin
                inspect_one.op_code = 11'b00111011011;
                inspect_one.execution_unit = 0;
              end
              // Handling the "Shift Left Quadword by Bits Immediate" operation (shlqbii)
              11'b00111111011: begin
                inspect_one.op_code = 11'b00111111011;
                inspect_one.execution_unit = 0;
              end
              // Handling the "Shift Left Quadword by Bytes from Bit Shift Count" operation (shlqbybi)
              11'b00111001111: begin
                inspect_one.op_code = 11'b00111001111;
                inspect_one.execution_unit = 0;
              end
              // Handling the "Rotate Quadword by Bytes from Bit Shift Count" operation (rotqbybi)
              11'b00111001100: begin
                inspect_one.op_code = 11'b00111001100;
                inspect_one.execution_unit = 0;
              end
              // Handling the "Shift Left Quadword by Bytes Immediate" operation (shlqbyi)
              11'b00111111111: begin
                inspect_one.op_code = 11'b00111111111;
                inspect_one.execution_unit = 0;
              end
              // Handling the "Rotate Quadword by Bytes Immediate" operation (rotqbyi)
              11'b00111111100: begin
                inspect_one.op_code = 11'b00111111100;
                inspect_one.execution_unit = 0;
              end
              default begin
                inspect_one.instruction_format = 0;
                inspect_one.source_a_valid = 0;
                inspect_one.source_b_valid = 0;
                inspect_one.source_c_valid = 0;
                inspect_one.op_code = 0;
                inspect_one.execution_unit = 0;
                inspect_one.target_address = 0;
                inspect_one.immediate = 0;
                inspect_one.is_odd_valid = 0;
              end
            endcase
          end
        end
      end
    end else inspect_one.is_odd_valid = 0;
  endfunction
endmodule
