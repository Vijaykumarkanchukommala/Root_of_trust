// ----------------------------------------------------------------
//  cpu_reset_ctrl
// ----------------------------------------------------------------
module cpu_reset_ctrl (
  input  logic i_clk, i_rst_n, i_lockdown_active, i_policy_allow,
  output logic o_cpu_reset_n
);
  always_ff @(posedge i_clk or negedge i_rst_n)
    if      (!i_rst_n)             o_cpu_reset_n <= 0;
    else if (i_lockdown_active)    o_cpu_reset_n <= 0;
    else if (i_policy_allow)       o_cpu_reset_n <= 1;
    else                           o_cpu_reset_n <= 0;
endmodule


