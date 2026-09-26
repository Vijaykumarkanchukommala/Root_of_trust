// ----------------------------------------------------------------
//  policy_engine
// ----------------------------------------------------------------
module policy_engine (
  input  logic i_auth_pass, i_retry_exceeded,
  output logic o_policy_allow, o_policy_deny, o_policy_lockdown
);
  always_comb begin
    o_policy_allow    = 0; 
    o_policy_deny     = 0; 
    o_policy_lockdown = 0;
    if      (i_retry_exceeded) 
            o_policy_lockdown = 1;
    else if (i_auth_pass)      
            o_policy_allow    = 1;
    else                     
            o_policy_deny     = 1;
  end
endmodule

