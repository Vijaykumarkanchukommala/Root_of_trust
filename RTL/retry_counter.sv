// ----------------------------------------------------------------
//  retry_counter
// ----------------------------------------------------------------
module retry_counter #(parameter int MAX_RETRY = 3)(
  input  logic i_clk, i_rst_n, i_auth_fail, i_lockdown_clear,
  output logic o_retry_exceeded
);
  logic [3:0] count;
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin count <= '0; o_retry_exceeded <= 0; end
    else begin
      if (i_lockdown_clear) begin count <= '0; o_retry_exceeded <= 0; end
      else begin
        if (i_auth_fail && count < MAX_RETRY) count <= count + 1;
        if (count >= MAX_RETRY || (i_auth_fail && count == (MAX_RETRY-1)))
          o_retry_exceeded <= 1;
      end
    end
  end
endmodule
