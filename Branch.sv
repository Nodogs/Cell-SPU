/***********************************************************************************************************
 * Module: Branch
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module handles branch instructions in a processor, determining the next program counter and 
 *     managing the forwarding of register values.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on instr_format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
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

module Branch (
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

  input clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  input [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  input [2:0] instr_format;
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
  // Output value of Stage 3
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

  //Internal Signals
  // Staging register for calculated values
  logic [0:127] rt_delay;
  // Destination register for write back data
  logic [0:6] rt_addr_delay;
  // Flag indicating if the write back data will be written to the Register Table
  logic reg_write_delay;
  // Staging register for Program Counter
  logic [7:0] pc_delay;
  // Flag indicating if the branch was taken
  logic branch_delay;

  always_ff @(posedge clock) begin
    if (reset == 1) begin
      wb_data <= 0;
      wb_reg_addr <= 0;
      wb_enable_reg_write <= 0;
      program_counter_wb <= 0;
      branch_is_taken <= 0;
    end else begin
      wb_data <= rt_delay;
      wb_reg_addr <= rt_addr_delay;
      wb_enable_reg_write <= reg_write_delay;
      program_counter_wb <= pc_delay;
      branch_is_taken <= branch_delay;
    end
  end

  always_comb begin
    // Case when the instruction format is 0 and opcode is 0: No Operation (Load)
    if (instr_format == 0 && op_code == 0) begin
      rt_delay = 0;
      rt_addr_delay = 0;
      reg_write_delay = 0;
      pc_delay = 0;
      branch_delay = 0;
    end else begin
      rt_addr_delay   = dest_reg_addr;
      reg_write_delay = enable_reg_write;
      if (branch_is_taken) begin
        rt_delay = 0;
        rt_addr_delay = 0;
        reg_write_delay = 0;
        pc_delay = 0;
        branch_delay = 0;
      end else if (instr_format == 0) begin
        case (op_code)
          //bi: Branch Indirect
          11'b00110101000: begin
            pc_delay = src_reg_a;
            reg_write_delay = 1'b0;
            branch_delay = 1'b1;
          end	 
			// biz: Branch Indirect If Zero
			11'b00100101000: begin	
				integer target_address;
			    branch_delay = 1;
			    if (store_reg[0:3] != 0) begin
			        target_address = store_reg & (program_counter_input + 4);
			    end else if ((src_reg_a[4] == 1 && src_reg_a[5] == 0) || (src_reg_a[4] == 0 && src_reg_a[5] == 1)) begin
			        target_address = (src_reg_a[0:3] << 2) & 32'hFFFFFFFC;
			    end
			    pc_delay = target_address;
			end
			// bihz: Branch Indirect If Zero Halfword
			11'b00100101010: begin 
				integer target_address;
			    branch_delay = 1;
			    if (store_reg[2:3] != 2'b00) begin
			        target_address = store_reg & (program_counter_input + 4);
			    end else if ((src_reg_a[4] == 1'b1 && src_reg_a[5] == 1'b0) || (src_reg_a[4] == 1'b0 && src_reg_a[5] == 1'b1)) begin
			        target_address = (src_reg_a[0:3] << 2) & 32'hFFFFFFFC;
			    end
			    pc_delay = target_address;
			end

          default begin
            rt_delay = 0;
            rt_addr_delay = 0;
            reg_write_delay = 0;
            pc_delay = 0;
            branch_delay = 0;
          end
        endcase
      end else if (instr_format == 5) begin
        case (op_code[2:10]) 
			// brsl: Branch Relative and Set Link
			9'b001100110: begin	
				integer target_address;
			    rt_delay[0:31] = program_counter_input + 1;
			    rt_delay[32:127] = 0;
			    target_address = $signed(imm_value[2:17]);
			    pc_delay = program_counter_input + target_address;
			    branch_delay = 1;
			end
			// br: Branch Relative
			9'b001100100: begin
				integer target_address;
			    target_address = $signed(imm_value[2:17]);
			    pc_delay = program_counter_input + target_address;
			    branch_delay = 1;
			end
			// bra: Branch Absolute
			9'b001100000: begin	
				integer target_address;
			    target_address = imm_value[2:17];
			    pc_delay = target_address;
			    branch_delay = 1;
			end
			// brasl: Branch Absolute and Set Link
			9'b001100010: begin	
				integer new_pc_value;
			    // Calculate the new Program Counter (PC) value by adding 4 to the current PC and masking the lower 2 bits. Store the result in the lower 32 bits of rt_delay.
			    rt_delay[0:31] = (program_counter_input + 4) & 32'hFFFF_FFFC;
			    // Set the upper 96 bits of rt_delay to 0
			    rt_delay[32:127] = 0;
			    // Calculate the new Program Counter (PC) value by masking the lower 2 bits of the immediate value. Store the result in pc_delay.
			    new_pc_value = {16'b0, imm_value[2:17]} & 32'hFFFF_FFFC;
			    pc_delay = new_pc_value;
			    branch_delay = 1;
			end
		  	// Handling the "Branch If Not Zero Halfword" operation (brnz)
			9'b001000110: begin
				integer offset;
			    offset = (initial_) ? 2 : 1;
			    pc_delay = program_counter_input - offset + $signed(imm_value[2:17]);
			    branch_delay = (store_reg[0:15] != 16'h0000) ? 1'b1 : 1'b0;
			end
		  	// binz: Branch Indirect If Not Zero
			11'b00100101001: begin 
				integer target_address;
			    branch_delay = 1;
			    if (store_reg[0:3] != 0) begin
			        target_address = (src_reg_a[0:3] << 2) & 32'hFFFFFFFC;
			    end else begin
			        target_address = store_reg & (program_counter_input + 4);
			    end
			    pc_delay = target_address;
			end
		  	// binz: Branch Indirect If Not Zero Halfword
			11'b00100101011: begin
				integer target_address;
			    branch_delay = 1;
			    if (store_reg[2:3] != 2'b00) begin
			        target_address = store_reg & (program_counter_input + 4);
			        pc_delay = target_address;
			    end else if ((src_reg_a[4] == 1'b1 && src_reg_a[5] == 1'b0) || (src_reg_a[4] == 1'b0 && src_reg_a[5] == 1'b1)) begin
			        target_address = (src_reg_a[0:3] << 2) & 32'hFFFFFFFC;
			        pc_delay = target_address;
			    end
			end
		  	// brhz: Branch If Zero Halfword
			9'b001000100: begin	
				integer offset;
			    offset = (store_reg[32:33] == 2'b00) ? $signed(imm_value[2:17]) : 4;
			    branch_delay = 1;
			    pc_delay = (program_counter_input + offset) & 32'hFFFFFFFC;
			end
		  	// brnz: Branch If Not Zero Word	 
			9'b001000010: begin	 
				integer offset;
			    offset = (initial_) ? 2 : 1;
			    pc_delay = program_counter_input - offset + $signed(imm_value[2:17]);
			    branch_delay = (store_reg != 0) ? 1'b1 : 1'b0;
			end
			// brz: Branch If Zero Word
			9'b001000000: begin		
				integer offset;
			    offset = (initial_) ? 2 : 1;
			    pc_delay = program_counter_input - offset + $signed(imm_value[2:17]);
			    branch_delay = (store_reg == 0) ? 1'b1 : 1'b0;
			end
          default begin
            rt_delay = 0;
            rt_addr_delay = 0;
            reg_write_delay = 0;
            pc_delay = 0;
            branch_delay = 0;
          end
        endcase
      end else begin
        rt_delay = 0;
        rt_addr_delay = 0;
        reg_write_delay = 0;
        pc_delay = 0;
        branch_delay = 0;
      end
    end
    if (branch_delay == 1 && initial_ == 1) disable_branch = 1;
    else disable_branch = 0;
  end
endmodule
