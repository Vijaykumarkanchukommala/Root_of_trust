// ================================================================
//  testbench.sv  -  Hardware Root-of-Trust Testbench
// ----------------------------------------------------------------
//
//  Functional coverage is implemented using explicit counters
//  instead of SystemVerilog covergroups.
//
//  DUT functionality and test sequence are unchanged.
// ================================================================


// ================================================================
// firmware_ascii_loader
// ================================================================
// Converts a string to 32-bit word stream with correct padding.
// Throttles to only send when auth_engine is in COLLECT state.
// ================================================================

module firmware_ascii_loader (
    input  logic        i_clk,
    output logic [31:0] i_fw_data,
    output logic        i_fw_valid,
    output logic        i_fw_last,
    output logic [1:0]  i_fw_strobe
);

    initial begin
        i_fw_data   = 32'h0;
        i_fw_valid  = 1'b0;
        i_fw_last   = 1'b0;
        i_fw_strobe = 2'b00;
    end


    task send_firmware(input string fw_string);

        int len;
        int words;
        logic [31:0] word_data;
        int wait_cnt;

        len   = fw_string.len();
        words = (len + 3) / 4;

        for (int i = 0; i < words; i++) begin

            // ----------------------------------------------------
            // Pack up to 4 ASCII bytes.
            // Big-endian.
            // Zero-pad partial final word.
            // ----------------------------------------------------

            word_data = 32'h0;

            for (int j = 0; j < 4; j++) begin

                if ((i*4+j) < len)
                    word_data[(3-j)*8 +: 8] = fw_string[i*4+j];
                else
                    word_data[(3-j)*8 +: 8] = 8'h00;

            end


            // ----------------------------------------------------
            // Wait for auth_engine to enter COLLECT state.
            //
            // state == 3'd1
            //
            // Timeout after 2000 cycles.
            // ----------------------------------------------------

            wait_cnt = 0;

            @(posedge i_clk);

            while (tb_sv.dut.u_auth_engine.state !== 3'd1) begin

                @(posedge i_clk);

                wait_cnt = wait_cnt + 1;

                if (wait_cnt > 2000) begin

                    $display(
                        "  ERROR: loader timed out waiting for COLLECT state"
                    );

                    //disable send_firmware;
                    return;

                end

            end


            // ----------------------------------------------------
            // Send firmware word
            // ----------------------------------------------------

            i_fw_valid  <= 1'b1;
            i_fw_data   <= word_data;

            i_fw_last   <= (i == words-1);

            i_fw_strobe <= (i == words-1)
                       ? (len % 4)
                       : 2'b00;

        end


        // --------------------------------------------------------
        // Finish firmware transmission
        // --------------------------------------------------------

        @(posedge i_clk);

        i_fw_valid  <= 1'b0;
        i_fw_last   <= 1'b0;
        i_fw_data   <= 32'h0;
        i_fw_strobe <= 2'b00;

    endtask

endmodule
