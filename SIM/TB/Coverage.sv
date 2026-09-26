    // ============================================================
    // VERILATOR-COMPATIBLE FUNCTIONAL COVERAGE
    // ============================================================
    //
    // Replaces:
    //
    //   covergroup
    //   coverpoint
    //   bins
    //   cross
    //   get_coverage()
    //
    // Every counter represents a coverage bin.
    //
    // This does NOT change DUT functionality.
    // ============================================================


    // ------------------------------------------------------------
    // cp_boot_pass
    //
    // bins trusted  = {1}
    // bins rejected = {0}
    // ------------------------------------------------------------

    int unsigned cov_boot_trusted;
    int unsigned cov_boot_rejected;


    // ------------------------------------------------------------
    // cp_lockdown
    //
    // bins no_lockdown = {0}
    // bins lockdown    = {1}
    // ------------------------------------------------------------

    int unsigned cov_no_lockdown;
    int unsigned cov_lockdown;


    // ------------------------------------------------------------
    // cp_cpu_reset
    //
    // bins cpu_running = {1}
    // bins cpu_blocked = {0}
    // ------------------------------------------------------------

    int unsigned cov_cpu_running;
    int unsigned cov_cpu_blocked;


    // ------------------------------------------------------------
    // cp_secure_mode
    //
    // bins secure     = {1}
    // bins not_secure = {0}
    // ------------------------------------------------------------

    int unsigned cov_secure;
    int unsigned cov_not_secure;


    // ------------------------------------------------------------
    // cx_pass_cpu
    //
    // boot_pass x cpu_reset_n
    //
    // Four possible combinations:
    //
    //   PASS   + RUNNING
    //   PASS   + BLOCKED
    //   REJECT + RUNNING
    //   REJECT + BLOCKED
    // ------------------------------------------------------------

    int unsigned cov_pass_running;
    int unsigned cov_pass_blocked;
    int unsigned cov_reject_running;
    int unsigned cov_reject_blocked;


    // ------------------------------------------------------------
    // cx_lock_cpu
    //
    // lockdown_active x cpu_reset_n
    //
    // Four possible combinations:
    //
    //   LOCKDOWN    + RUNNING
    //   LOCKDOWN    + BLOCKED
    //   NO_LOCKDOWN + RUNNING
    //   NO_LOCKDOWN + BLOCKED
    // ------------------------------------------------------------

    int unsigned cov_lock_running;
    int unsigned cov_lock_blocked;
    int unsigned cov_no_lock_running;
    int unsigned cov_no_lock_blocked;



    // ============================================================
    // Coverage sampling
    // ============================================================

    always @(posedge i_clk) begin

        // --------------------------------------------------------
        // boot_pass coverage
        // --------------------------------------------------------

        if (o_boot_pass)
            cov_boot_trusted++;
        else
            cov_boot_rejected++;


        // --------------------------------------------------------
        // lockdown coverage
        // --------------------------------------------------------

        if (dut.w_lockdown_active)
            cov_lockdown++;
        else
            cov_no_lockdown++;


        // --------------------------------------------------------
        // CPU reset coverage
        // --------------------------------------------------------

        if (o_cpu_reset_n)
            cov_cpu_running++;
        else
            cov_cpu_blocked++;


        // --------------------------------------------------------
        // secure_mode coverage
        // --------------------------------------------------------

        if (o_secure_mode)
            cov_secure++;
        else
            cov_not_secure++;


        // --------------------------------------------------------
        // boot_pass x cpu_reset_n
        // --------------------------------------------------------

        if (o_boot_pass && o_cpu_reset_n)
            cov_pass_running++;

        else if (o_boot_pass && !o_cpu_reset_n)
            cov_pass_blocked++;

        else if (!o_boot_pass && o_cpu_reset_n)
            cov_reject_running++;

        else
            cov_reject_blocked++;


        // --------------------------------------------------------
        // lockdown_active x cpu_reset_n
        // --------------------------------------------------------

        if (dut.w_lockdown_active && o_cpu_reset_n)
            cov_lock_running++;

        else if (dut.w_lockdown_active && !o_cpu_reset_n)
            cov_lock_blocked++;

        else if (!dut.w_lockdown_active && o_cpu_reset_n)
            cov_no_lock_running++;

        else
            cov_no_lock_blocked++;

    end

