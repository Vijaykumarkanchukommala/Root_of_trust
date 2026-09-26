module debug_ctrl (
    input  logic i_clk,
    input  logic i_rst_n,

    // Security status inputs
    input  logic i_auth_pass,
    input  logic i_auth_fail,
    input  logic i_lockdown_active,

    // Debug control outputs
    output logic o_jtag_disable,
    output logic o_debug_enable
);

always_comb begin

    // Default values
    o_jtag_disable = 1'b0;
    o_debug_enable = 1'b0;

    // Enable debug only after successful authentication
    if (i_auth_pass && !i_lockdown_active) begin
        o_debug_enable = 1'b1;
        o_jtag_disable = 1'b0;
    end

    // Disable debug access during authentication failure
    else if (i_auth_fail || i_lockdown_active) begin
        o_debug_enable = 1'b0;
        o_jtag_disable = 1'b1;
    end
end

endmodule
