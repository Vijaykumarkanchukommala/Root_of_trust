// ----------------------------------------------------------------
//  secure_key_storage
//  Change ONLY this parameter to update the trusted firmware hash.
//  Run: python3 -c "import hashlib; print(hashlib.sha256(b'YOUR_FW').hexdigest())"
// ----------------------------------------------------------------
module secure_key_storage (
    input  logic         i_clk,
    input  logic         i_rst_n,
    output logic [255:0] o_trusted_key
);

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n)
        o_trusted_key <= 256'h0;
    else
        o_trusted_key <= 256'hcc369d06174db4fa54f4f20ae1523a10f8aa409a4b51193135fc798ce426e40e;
end

endmodule
