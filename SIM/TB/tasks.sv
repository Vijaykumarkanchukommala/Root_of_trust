    // ============================================================
    // Coverage report
    // ============================================================

    task automatic print_coverage;

        int total_bins;
        int hit_bins;

        total_bins = 0;
        hit_bins   = 0;


        $display("");
        $display("================================================");
        $display("       ROOT OF TRUST FUNCTIONAL COVERAGE");
        $display("================================================");


        // --------------------------------------------------------
        // boot_pass
        // --------------------------------------------------------

        $display("");
        $display("boot_pass:");

        $display("  trusted  : %0d", cov_boot_trusted);
        $display("  rejected : %0d", cov_boot_rejected);

        total_bins = total_bins + 2;

        if (cov_boot_trusted > 0)
            hit_bins = hit_bins + 1;

        if (cov_boot_rejected > 0)
            hit_bins = hit_bins + 1;



        // --------------------------------------------------------
        // lockdown
        // --------------------------------------------------------

        $display("");
        $display("lockdown_active:");

        $display("  no_lockdown : %0d", cov_no_lockdown);
        $display("  lockdown    : %0d", cov_lockdown);

        total_bins = total_bins + 2;

        if (cov_no_lockdown > 0)
            hit_bins = hit_bins + 1;

        if (cov_lockdown > 0)
            hit_bins = hit_bins + 1;



        // --------------------------------------------------------
        // CPU
        // --------------------------------------------------------

        $display("");
        $display("cpu_reset_n:");

        $display("  running : %0d", cov_cpu_running);
        $display("  blocked : %0d", cov_cpu_blocked);

        total_bins = total_bins + 2;

        if (cov_cpu_running > 0)
            hit_bins = hit_bins + 1;

        if (cov_cpu_blocked > 0)
            hit_bins = hit_bins + 1;



        // --------------------------------------------------------
        // secure_mode
        // --------------------------------------------------------

        $display("");
        $display("secure_mode:");

        $display("  secure     : %0d", cov_secure);
        $display("  not_secure : %0d", cov_not_secure);

        total_bins = total_bins + 2;

        if (cov_secure > 0)
            hit_bins = hit_bins + 1;

        if (cov_not_secure > 0)
            hit_bins = hit_bins + 1;



        // --------------------------------------------------------
        // boot_pass x cpu_reset_n
        // --------------------------------------------------------

        $display("");
        $display("boot_pass x cpu_reset_n:");

        $display("  PASS + RUNNING   : %0d",
                 cov_pass_running);

        $display("  PASS + BLOCKED   : %0d",
                 cov_pass_blocked);

        $display("  REJECT + RUNNING : %0d",
                 cov_reject_running);

        $display("  REJECT + BLOCKED : %0d",
                 cov_reject_blocked);

        total_bins = total_bins + 4;

        if (cov_pass_running > 0)
            hit_bins = hit_bins + 1;

        if (cov_pass_blocked > 0)
            hit_bins = hit_bins + 1;

        if (cov_reject_running > 0)
            hit_bins = hit_bins + 1;

        if (cov_reject_blocked > 0)
            hit_bins = hit_bins + 1;



        // --------------------------------------------------------
        // lockdown x cpu_reset_n
        // --------------------------------------------------------

        $display("");
        $display("lockdown_active x cpu_reset_n:");

        $display("  LOCKDOWN + RUNNING     : %0d",
                 cov_lock_running);

        $display("  LOCKDOWN + BLOCKED     : %0d",
                 cov_lock_blocked);

        $display("  NO_LOCKDOWN + RUNNING  : %0d",
                 cov_no_lock_running);

        $display("  NO_LOCKDOWN + BLOCKED  : %0d",
                 cov_no_lock_blocked);

        total_bins = total_bins + 4;

        if (cov_lock_running > 0)
            hit_bins = hit_bins + 1;

        if (cov_lock_blocked > 0)
            hit_bins = hit_bins + 1;

        if (cov_no_lock_running > 0)
            hit_bins = hit_bins + 1;

        if (cov_no_lock_blocked > 0)
            hit_bins = hit_bins + 1;



        // --------------------------------------------------------
        // Overall coverage
        // --------------------------------------------------------

        $display("");
        $display("-----------------------------------------------");
        $display("Coverage bins hit : %0d / %0d",
                 hit_bins,
                 total_bins);

        if (total_bins != 0) begin
            $display("Functional Coverage : %.1f%%",
                     (100.0 * hit_bins) / total_bins);
        end
        else begin
            $display("Functional Coverage : 0.0%%");
        end

        $display("================================================");
        $display("");

    endtask



    // ============================================================
    // Digest monitor
    // ============================================================
    // Prints once when final SHA block completes.
    // ============================================================

    always @(posedge i_clk) begin

        if (dut.u_auth_engine.state == 3'd4 &&
            dut.u_auth_engine.sha_done &&
            dut.u_auth_engine.sha_last_block) begin

            $display(
                "  SHA-256 computed : %h",
                dut.u_auth_engine.sha_digest
            );

            $display(
                "  Golden hash      : %h",
                dut.u_auth_engine.i_trusted_key
            );

            if (dut.u_auth_engine.sha_digest ==
                dut.u_auth_engine.i_trusted_key) begin

                $display("  Digest match     : YES");

            end
            else begin

                $display("  Digest match     : NO");

            end

        end

    end



    // ============================================================
    // do_boot task
    // ============================================================
    //
    // 1. Hard-resets the DUT.
    // 2. Asserts i_boot_req.
    // 3. Waits 2 cycles.
    // 4. Sends firmware.
    // 5. Waits for boot_done.
    // 6. Latches result.
    // 7. Drops i_boot_req.
    // 8. Waits for system to return to idle.
    // ============================================================

    task do_boot(
        input string fw_str,
        input string label
    );

        // --------------------------------------------------------
        // Hard reset
        // --------------------------------------------------------

        i_boot_req = 0;
        i_rst_n    = 0;

        #20;

        i_rst_n = 1;

        repeat(4) @(posedge i_clk);


        $display("\n--- %s ---", label);


        // --------------------------------------------------------
        // Start boot
        // --------------------------------------------------------

        @(posedge i_clk);

        i_boot_req = 1;

        repeat(2) @(posedge i_clk);


        // --------------------------------------------------------
        // Send firmware
        // --------------------------------------------------------

        loader.send_firmware(fw_str);


        // --------------------------------------------------------
        // Wait for boot decision
        // --------------------------------------------------------

        wait(o_boot_done);

        @(posedge i_clk);


        // --------------------------------------------------------
        // Latch result NOW while FSM is still
        // asserting boot_pass / boot_done
        // --------------------------------------------------------

        result_pass = o_boot_pass;
        result_cpu  = o_cpu_reset_n;


        $display(
            "  boot_pass=%0b  cpu_reset_n=%0b  secure_mode=%0b",
            o_boot_pass,
            o_cpu_reset_n,
            o_secure_mode
        );


        if (o_boot_pass)
            $display("  Result: TRUSTED - device ON");
        else
            $display("  Result: REJECTED - device OFF");


        // --------------------------------------------------------
        // Deassert i_boot_req
        // --------------------------------------------------------

        i_boot_req = 0;

        wait(!o_boot_done);

        #50;

    endtask
