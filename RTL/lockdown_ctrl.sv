// ----------------------------------------------------------------
//  lockdown_ctrl - sticky once set, only hardware reset clears it
// ----------------------------------------------------------------
module lockdown_ctrl (
  input  logic i_clk, i_rst_n, i_policy_lockdown,
  output logic o_lockdown_active
);
  always_ff @(posedge i_clk or negedge i_rst_n)
    if (!i_rst_n) 
       o_lockdown_active <= 0;
    else if (i_policy_lockdown) 
       o_lockdown_active <= 1;
endmodule
