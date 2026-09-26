`timescale 1ns/1ps

// ================================================================
// tb_sv - top-level testbench
// ================================================================

module tb_sv;

    // ------------------------------------------------------------
    // DUT / testbench signals
    // ------------------------------------------------------------

    logic        i_clk;
    logic        i_rst_n;
    logic        i_boot_req;

    logic [31:0] i_fw_data;
    logic        i_fw_valid;
    logic        i_fw_last;
    logic [1:0]  i_fw_strobe;

    logic        o_cpu_reset_n;
    logic        o_boot_done;
    logic        o_boot_pass;
    logic        o_secure_mode;


    // ------------------------------------------------------------
    // Latched result
    // Captured before i_boot_req drops.
    // ------------------------------------------------------------

    logic result_pass;
    logic result_cpu;


    // ============================================================
    // DUT
    // ============================================================

    rot_top dut (
        .i_clk         (i_clk),
        .i_rst_n       (i_rst_n),
        .i_boot_req    (i_boot_req),

        .i_fw_data     (i_fw_data),
        .i_fw_valid    (i_fw_valid),
        .i_fw_last     (i_fw_last),
        .i_fw_strobe   (i_fw_strobe),

        .o_cpu_reset_n (o_cpu_reset_n),
        .o_boot_done   (o_boot_done),
        .o_boot_pass   (o_boot_pass),
        .o_secure_mode (o_secure_mode)
    );


    // ============================================================
    // Firmware loader
    // ============================================================

    firmware_ascii_loader loader (
        .i_clk       (i_clk),
        .i_fw_data   (i_fw_data),
        .i_fw_valid  (i_fw_valid),
        .i_fw_last   (i_fw_last),
        .i_fw_strobe (i_fw_strobe)
    );


    // ============================================================
    // Clock
    // ============================================================

    initial i_clk = 1'b0;

    always #5 i_clk = ~i_clk;


    `include "TB/Coverage.sv"
    `include "TB/tasks.sv"


    // ============================================================
    // MAIN TEST SEQUENCE
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // VCD
        // --------------------------------------------------------

        $dumpfile("rot_sim.vcd");
        $dumpvars(0, tb_sv);


        // --------------------------------------------------------
        // Initial reset
        // --------------------------------------------------------

        i_rst_n    = 0;
        i_boot_req = 0;

        #20;

        i_rst_n = 1;

        repeat(4) @(posedge i_clk);


        // --------------------------------------------------------
        // Header
        // --------------------------------------------------------

        $display("\n========================================");
        $display("  Hardware Root-of-Trust Testbench");
        $display("  Golden = SHA-256(large firmware string)");
        $display("========================================");



        // ========================================================
        // TEST 0
        // Trusted firmware
        // ========================================================

        do_boot(

            "Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process. Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process. Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process. Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process.",

            "TEST 0: large trusted firmware (expect TRUSTED)"
        );


        if (result_pass && result_cpu)
            $display("  TEST 0 PASS");
        else
            $display(
                "  TEST 0 FAIL (result_pass=%0b result_cpu=%0b)",
                result_pass,
                result_cpu
            );



        // ========================================================
        // TEST 1
        // Wrong firmware
        // ========================================================

        do_boot(
            "HELLOWORLD",
            "TEST 1: HELLOWORLD (expect REJECTED)"
        );


        if (!result_pass && !result_cpu)
            $display("  TEST 1 PASS");
        else
            $display("  TEST 1 FAIL");



        // ========================================================
        // TEST 2
        // Wrong firmware
        // ========================================================

        do_boot(
            "SECUREBOOT_HACKD",
            "TEST 2: SECUREBOOT_HACKD (expect REJECTED)"
        );


        if (!result_pass && !result_cpu)
            $display("  TEST 2 PASS");
        else
            $display("  TEST 2 FAIL");



        // ========================================================
        // TEST 3
        // Three wrong firmware attempts -> lockdown
        // ========================================================

        $display("\n--- TEST 3: 3x wrong firmware -> LOCKDOWN ---");


        // --------------------------------------------------------
        // Reset once to start clean
        // --------------------------------------------------------

        i_rst_n = 0;

        #20;

        i_rst_n = 1;

        repeat(4) @(posedge i_clk);


        // --------------------------------------------------------
        // Attempt 1
        // --------------------------------------------------------

        @(posedge i_clk);

        i_boot_req = 1;

        repeat(2) @(posedge i_clk);

        loader.send_firmware("BAD_FIRMWARE_001");

        wait(o_boot_done);

        @(posedge i_clk);

        i_boot_req = 0;

        wait(!o_boot_done);

        #50;

        $display("  Attempt 1 done - retry count rising");


        // --------------------------------------------------------
        // Attempt 2
        // --------------------------------------------------------

        @(posedge i_clk);

        i_boot_req = 1;

        repeat(2) @(posedge i_clk);

        loader.send_firmware("BAD_FIRMWARE_002");

        wait(o_boot_done);

        @(posedge i_clk);

        i_boot_req = 0;

        wait(!o_boot_done);

        #50;

        $display("  Attempt 2 done - retry count rising");


        // --------------------------------------------------------
        // Attempt 3 -> lockdown
        // --------------------------------------------------------

        @(posedge i_clk);

        i_boot_req = 1;

        repeat(2) @(posedge i_clk);

        loader.send_firmware("BAD_FIRMWARE_003");

        wait(dut.w_lockdown_active);

        #100;


        if (dut.w_lockdown_active && !o_cpu_reset_n)

            $display(
                "  TEST 3 PASS - lockdown_active=1  o_cpu_reset_n=0"
            );

        else

            $display("  TEST 3 FAIL");


        i_boot_req = 0;

        #50;



        // ========================================================
        // TEST 4
        // Trusted firmware AFTER lockdown with reset
        // ========================================================

        do_boot(

            "Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process. Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process. Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process. Modern electronic systems require a secure mechanism to ensure that only authentic and unmodified firmware is executed during device startup. However, firmware stored in memory can be vulnerable to tampering, unauthorized modification, or malicious code insertion. Therefore, a reliable method is needed to verify the integrity and authenticity of firmware before the device begins execution. This project addresses the problem by implementing a hardware-based verification mechanism that validates firmware using cryptographic algorithms, ensuring that only trusted firmware is allowed to run and preventing potential security breaches during the boot process.",

            "TEST 4: trusted firmware after lockdown reset (expect TRUSTED)"
        );


        if (result_pass && result_cpu)
            $display("  TEST 4 PASS");
        else
            $display("  TEST 4 FAIL");



        // ========================================================
        // Final report
        // ========================================================

        $display("\n========================================");
        $display("  ALL ROT TESTS COMPLETE");
        $display("========================================\n");


        print_coverage();


        $finish;

    end

endmodule
