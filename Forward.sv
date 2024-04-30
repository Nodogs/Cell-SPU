/***********************************************************************************************************
 * Module: Forward	  
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 * 		This module handles forwarding logic for register values in a processor.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - instruction_even: Instruction from even pipeline stage
 *   - instruction_odd: Instruction from odd pipeline stage
 *   - ra_even_input: Value of register A for even pipeline stage
 *   - rb_even_input: Value of register B for even pipeline stage
 *   - rc_even_input: Value of register C for even pipeline stage
 *   - ra_odd_input: Value of register A for odd pipeline stage
 *   - rb_odd_input: Value of register B for odd pipeline stage
 *   - rt_st_odd_input: Value of temporary register ST for odd pipeline stage
 *   - fw_even_wb_input: Pipe shift register of values ready to be forwarded for even stage
 *   - fw_odd_wb_input: Pipe shift register of values ready to be forwarded for odd stage
 *   - fw_addr_even_wb_input: Destinations of values to be forwarded for even stage
 *   - fw_addr_odd_wb_input: Destinations of values to be forwarded for odd stage
 *   - fw_write_even_wb_input: Flag indicating whether forwarded values will be written for even stage
 *   - fw_write_odd_wb_input: Flag indicating whether forwarded values will be written for odd stage	  
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - ra_even_fwd_output: Forwarded value of register A for even pipeline stage
 *   - rb_even_fwd_output: Forwarded value of register B for even pipeline stage
 *   - rc_even_fwd_output: Forwarded value of register C for even pipeline stage
 *   - ra_odd_fwd_output: Forwarded value of register A for odd pipeline stage
 *   - rb_odd_fwd_output: Forwarded value of register B for odd pipeline stage
 *   - rt_st_odd_fwd_output: Forwarded value of temporary registerrt_st for odd pipeline stage
 ***********************************************************************************************************/

module Forward (
    clock,
    reset,
    instruction_even,
    instruction_odd,
    ra_even_input,
    rb_even_input,
    rc_even_input,
    ra_odd_input,
    rb_odd_input,
    rt_st_odd_input,
    ra_even_fwd_output,
    rb_even_fwd_output,
    rc_even_fwd_output,
    ra_odd_fwd_output,
    rb_odd_fwd_output,
    rt_st_odd_fwd_output,
    fw_even_wb_input,
    fw_addr_even_wb_input,
    fw_write_even_wb_input,
    fw_odd_wb_input,
    fw_addr_odd_wb_input,
    fw_write_odd_wb_input
);

  input clock, reset;
  // Input instructions for both even and odd cycles, received from the decoder.
  input [0:31] instruction_even, instruction_odd;
  // Input values for 'ra', 'rb', 'rc' for both even and odd instructions, and 'rt_st' for odd instruction, retrieved from the Register Table.
  input [0:127] ra_even_input, rb_even_input, rc_even_input, ra_odd_input, rb_odd_input, rt_st_odd_input;
  // Pipeline data in shift registers, ready for forwarding
  input [6:0][0:127] fw_even_wb_input, fw_odd_wb_input;
  // Destination registers for data forwarding
  input [6:0][0:6] fw_addr_even_wb_input, fw_addr_odd_wb_input;
  // Flags indicating if forwarded values will be written to registers
  input [6:0] fw_write_even_wb_input, fw_write_odd_wb_input;
  // Updated input data after forwarding
  output logic [0:127] ra_even_fwd_output, rb_even_fwd_output, rc_even_fwd_output, ra_odd_fwd_output, rb_odd_fwd_output, rt_st_odd_fwd_output;

  always_comb begin
    /* Evaluating 'ra' operand for the even instruction. If the source register of the even instruction 
		matches the destination register of any instruction in the even or odd pipeline stages and that 
		instruction is writing to the register, forward the data from the corresponding pipeline stage. */
    for (int i = 0; i < 7; ++i) begin
      if (instruction_even[18:24] == fw_addr_even_wb_input[i] && fw_write_even_wb_input[i] == 1)
        ra_even_fwd_output = fw_even_wb_input[i];
      else if (instruction_even[18:24] == fw_addr_odd_wb_input[i] && fw_write_odd_wb_input[i] == 1)
        ra_even_fwd_output = fw_odd_wb_input[i];
    end
    // If ra_even_fwd_output is unassigned, default to the value of ra_even_input.
    if (ra_even_fwd_output === 'bx) ra_even_fwd_output = ra_even_input;
    /* Evaluating 'rb' operand for the even instruction. If the source register of the even instruction 
		matches the destination register of any instruction in the even or odd pipeline stages and that 
		instruction is writing to the register, forward the data from the corresponding pipeline stage. */
    for (int i = 0; i < 7; ++i) begin
      if (instruction_even[11:17] == fw_addr_even_wb_input[i] && fw_write_even_wb_input[i] == 1)
        rb_even_fwd_output = fw_even_wb_input[i];
      else if (instruction_even[11:17] == fw_addr_odd_wb_input[i] && fw_write_odd_wb_input[i] == 1)
        rb_even_fwd_output = fw_odd_wb_input[i];
    end
    // If rb_even_fwd_output is unassigned, default to the value of rb_even_input.
    if (rb_even_fwd_output === 'bx) rb_even_fwd_output = rb_even_input;
    /* Evaluating 'rc' operand for the even instruction. If the source register of the even instruction 
		matches the destination register of any instruction in the even or odd pipeline stages and that 
		instruction is writing to the register, forward the data from the corresponding pipeline stage. */
    for (int i = 0; i < 7; ++i) begin
      if (instruction_even[25:31] == fw_addr_even_wb_input[i] && fw_write_even_wb_input[i] == 1)
        rc_even_fwd_output = fw_even_wb_input[i];
      else if (instruction_even[25:31] == fw_addr_odd_wb_input[i] && fw_write_odd_wb_input[i] == 1)
        rc_even_fwd_output = fw_odd_wb_input[i];
    end
    // If rc_even_fwd_output is unassigned, assign it the value of rc_even_input.
    if (rc_even_fwd_output === 'bx)  // Check if rc_even_fwd_output is not assigned
      rc_even_fwd_output = rc_even_input;
    /* Evaluating 'rc' operand for the even instruction. If the source register of the even instruction 
		matches the destination register of any instruction in the even or odd pipeline stages and that 
		instruction is writing to the register, forward the data from the corresponding pipeline stage. */
    for (int i = 0; i < 7; ++i) begin
      if (instruction_even[25:31] == fw_addr_even_wb_input[i] && fw_write_even_wb_input[i] == 1)
        rc_even_fwd_output = fw_even_wb_input[i];
      else if (instruction_even[25:31] == fw_addr_odd_wb_input[i] && fw_write_odd_wb_input[i] == 1)
        rc_even_fwd_output = fw_odd_wb_input[i];
    end
    // If rc_even_fwd_output is unassigned, default to the value of rc_even_input.
    if (rc_even_fwd_output === 'bx) rc_even_fwd_output = rc_even_input;
    /* Evaluating 'rb' operand for the odd instruction. If the source register of the odd instruction 
		matches the destination register of any instruction in the even or odd pipeline stages and that 
		instruction is writing to the register, forward the data from the corresponding pipeline stage. */
    for (int i = 0; i < 7; ++i) begin
      if (instruction_odd[11:17] == fw_addr_even_wb_input[i] && fw_write_even_wb_input[i] == 1)
        rb_odd_fwd_output = fw_even_wb_input[i];
      else if (instruction_odd[11:17] == fw_addr_odd_wb_input[i] && fw_write_odd_wb_input[i] == 1)
        rb_odd_fwd_output = fw_odd_wb_input[i];
    end
    // If rb_odd_fwd_output is unassigned, default to the value of rb_odd_input.
    if (rb_odd_fwd_output === 'bx) rb_odd_fwd_output = rb_odd_input;
    /* Loop through each pipeline stage. If the destination register of the odd instruction matches the 
		source register of any instruction in the even or odd pipeline stages and that instruction is 
		writing to the register, forward the data from the corresponding pipeline stage. */
    for (int i = 0; i < 7; ++i) begin
      if (instruction_odd[25:31] == fw_addr_even_wb_input[i] && fw_write_even_wb_input[i] == 1)
        rt_st_odd_fwd_output = fw_even_wb_input[i];
      else if (instruction_odd[25:31] == fw_addr_odd_wb_input[i] && fw_write_odd_wb_input[i] == 1)
        rt_st_odd_fwd_output = fw_odd_wb_input[i];
    end
    // If rt_st_odd_fwd_output is unassigned, assign it the value of rt_st_odd_input.
    if (rt_st_odd_fwd_output === 'bx) rt_st_odd_fwd_output = rt_st_odd_input;
  end
endmodule
