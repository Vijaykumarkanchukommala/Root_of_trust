// ----------------------------------------------------------------
//  boot_ctrl_fsm
// ----------------------------------------------------------------
module boot_ctrl_fsm (
  input  logic i_clk, i_rst_n, i_boot_req, i_auth_done, i_auth_pass, i_retry_exceeded, lockdown_active,
  output logic o_start_auth, o_boot_done, o_boot_pass, o_auth_fail_pulse,
  output logic [2:0] current_state
);
  typedef enum logic [2:0] {
    RESET=0, IDLE=1, AUTH_START=2, AUTH_WAIT=3,
    CHECK_RESULT=4, BOOT_ALLOW=5, BOOT_DENY=6, LOCKDOWN=7
  } state_t;
  state_t state, next_state;
  assign current_state = state;

  always_ff @(posedge i_clk or negedge i_rst_n)
    if (!i_rst_n) state <= RESET; else state <= next_state;

  always_comb begin
    next_state = state; o_start_auth = 0; o_boot_done = 0;
    o_boot_pass  = 0;     o_auth_fail_pulse = 0;
    if (lockdown_active && state != LOCKDOWN) next_state = LOCKDOWN;
    else case (state)
      RESET:        next_state = IDLE;
      IDLE:         if (i_boot_req) next_state = AUTH_START;
      AUTH_START:   begin o_start_auth = 1; next_state = AUTH_WAIT; end
      AUTH_WAIT:    if (i_auth_done) next_state = CHECK_RESULT;
      CHECK_RESULT: begin
        if (i_retry_exceeded)   next_state = LOCKDOWN;
        else if (i_auth_pass)   next_state = BOOT_ALLOW;
        else begin o_auth_fail_pulse = 1; next_state = BOOT_DENY; end
      end
      BOOT_ALLOW: begin o_boot_done=1; o_boot_pass=1; if(!i_boot_req) next_state=IDLE; end
      BOOT_DENY:  begin o_boot_done=1; o_boot_pass=0; if(!i_boot_req) next_state=IDLE; end
      LOCKDOWN:   next_state = LOCKDOWN;
      default:    next_state = RESET;
    endcase
  end
endmodule

