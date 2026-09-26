// ----------------------------------------------------------------
//  rot_top - top-level integration
// ----------------------------------------------------------------
module rot_top (
  input  logic         i_clk,
  input  logic         i_rst_n,
  input  logic         i_boot_req,
  input  logic [31:0]  i_fw_data,
  input  logic         i_fw_valid,
  input  logic         i_fw_last,
  input  logic [1:0]   i_fw_strobe,

  // Core outputs
  output logic         o_cpu_reset_n,
  output logic         o_boot_done,
  output logic         o_boot_pass,
  output logic         o_secure_mode,

  // Future-scope: anti-rollback
  input  logic [7:0]  i_fw_version_in,      // version field from firmware header
  output logic        o_rollback_alert,      // high if version < stored minimum

  // Future-scope: OTA authentication
  input  logic        i_ota_update_req,      // request to authenticate OTA image
  output logic        o_ota_auth_grant,      // OTA authentication approved

  // Future-scope: TEE handoff
  output logic        o_tee_handoff,         // pulse after trusted boot completes

  // Future-scope: debug control (exposed for chip-level integration)
  output logic        o_jtag_disable,
  output logic        o_debug_enable,
    // Future-scope: AI-assisted policy engine
  input  logic        i_ai_policy_hint,
  output logic        o_ai_override_active,

  // Future-scope: hardware intrusion detection
  input  logic        i_tamper_detect_in,
  output logic        o_tamper_alert,

  // Future-scope: multi-core boot sequencing
  input  logic [3:0]  i_core_ready,
  output logic [3:0]  o_core_boot_grant
);

  // ---- Internal signals -----------------------------------------------
  logic w_auth_done, w_auth_pass, w_start_auth;
  logic w_retry_exceeded, w_policy_allow, w_policy_deny, w_policy_lockdown;
  logic w_lockdown_active, w_auth_fail_pulse;
  logic [255:0] w_trusted_key;

  // ---- Derived combinational ------------------------------------------
  assign o_secure_mode = !w_lockdown_active && o_boot_pass;

  // ---- Anti-rollback register -----------------------------------------
  // Stores the minimum acceptable firmware version seen after a good boot.
  // Future: compare against eFuse-burned minimum version.
  logic [7:0] r_fw_version_min;
  logic       r_rollback_detected;


  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_fw_version_min   <= 8'h00;
      r_rollback_detected <= 1'b0;
    end else if (o_boot_pass && w_auth_pass) begin
      // Ratchet: only update stored minimum if new version is higher
      if (i_fw_version_in > r_fw_version_min)
        r_fw_version_min <= i_fw_version_in;
      r_rollback_detected <= (i_fw_version_in < r_fw_version_min);
    end else begin
      r_rollback_detected <= 1'b0;
    end
  end

  assign o_rollback_alert = r_rollback_detected;

  // ---- OTA auth stub --------------------------------------------------
  // Future: route ota_update_req through a second auth_engine instance.
  // For now: OTA grant requires a successful boot AND no rollback.
  assign o_ota_auth_grant = o_boot_pass && !o_rollback_alert && !w_lockdown_active;

  // ---- TEE handoff register -------------------------------------------
  // Single-cycle pulse after trusted boot, cleared on next reset.
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n)
      o_tee_handoff <= 1'b0;
    else
      o_tee_handoff <= o_boot_pass && !w_lockdown_active;
  end
// ---- AI policy stub -------------------------------------------------
  // Future: external AI engine sends policy_hint; override fires if hint
  // disagrees with local policy AND auth is valid.
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
         o_ai_override_active <= 1'b0;
    else
         o_ai_override_active <= i_ai_policy_hint && w_auth_pass && !w_lockdown_active;
  end

  // ---- Hardware intrusion detection -----------------------------------
  // Future: connect to physical tamper mesh / voltage sensors.
  // Tamper event forces lockdown via policy_lockdown path.
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
        o_tamper_alert <= 1'b0;
    else        
        o_tamper_alert <= i_tamper_detect_in;
  end

  // ---- Multi-core boot grant ------------------------------------------
  // Future: stagger core releases post-RoT authentication.
  // Core N boots only after RoT passes and core is ready.
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) 
            o_core_boot_grant <= 4'b0000;
    else        
            o_core_boot_grant <= {4{o_boot_pass && !w_lockdown_active}} & i_core_ready;
  end
  // ---- Submodule instantiations --------------------------------------
  boot_ctrl_fsm u_boot_ctrl_fsm (
    .i_clk            (i_clk            ), 
    .i_rst_n          (i_rst_n          ), 
    .i_boot_req       (i_boot_req       ),
    .i_auth_done      (w_auth_done      ), 
    .i_auth_pass      (w_auth_pass      ),
    .i_retry_exceeded (w_retry_exceeded ), 
    .lockdown_active  (w_lockdown_active),
    .o_start_auth     (w_start_auth     ), 
    .o_boot_done      (o_boot_done      ), 
    .o_boot_pass      (o_boot_pass      ),
    .o_auth_fail_pulse(w_auth_fail_pulse), 
    .current_state    (                 )
  );


  auth_engine u_auth_engine (
    .i_clk            (i_clk            ), 
    .i_rst_n          (i_rst_n          ), 
    .i_start_auth     (w_start_auth     ),
    .i_fw_data        (i_fw_data        ), 
    .i_fw_valid       (i_fw_valid       ), 
    .i_fw_last        (i_fw_last        ),
    .i_fw_strobe      (i_fw_strobe      ), 
    .i_trusted_key    (w_trusted_key    ),
    .o_auth_done      (w_auth_done      ), 
    .o_auth_pass      (w_auth_pass      )
  );

  secure_key_storage u_secure_key_storage (
    .i_clk            (i_clk            ), 
    .i_rst_n          (i_rst_n          ), 
    .o_trusted_key    (w_trusted_key    ) 
  );

  policy_engine u_policy_engine (
    .i_auth_pass      (w_auth_pass      ), 
    .i_retry_exceeded (w_retry_exceeded ),
    .o_policy_allow   (w_policy_allow   ), 
    .o_policy_deny    (w_policy_deny    ),
    .o_policy_lockdown(w_policy_lockdown)
  );

  retry_counter #(.MAX_RETRY(3)) u_retry_counter (
    .i_clk            (i_clk            ), 
    .i_rst_n          (i_rst_n          ),
    .i_auth_fail      (w_auth_fail_pulse), 
    .i_lockdown_clear (1'b0             ),  // Intentional: only hw reset clears lockdown
    .o_retry_exceeded (w_retry_exceeded )
  );

  lockdown_ctrl u_lockdown_ctrl (
    .i_clk            (i_clk            ), 
    .i_rst_n          (i_rst_n          ),
    .i_policy_lockdown(w_policy_lockdown), 
    .o_lockdown_active(w_lockdown_active)
  );

  cpu_reset_ctrl u_cpu_reset_ctrl (
    .i_clk            (i_clk            ), 
    .i_rst_n          (i_rst_n          ),
    .i_lockdown_active(w_lockdown_active), 
    .i_policy_allow   (w_policy_allow   ),
    .o_cpu_reset_n    (o_cpu_reset_n    )
  );

  debug_ctrl u_debug_ctrl (
    .i_clk            (i_clk            ),
    .i_rst_n          (i_rst_n          ),
    .i_auth_pass      (w_auth_pass      ),
    .i_auth_fail      (w_auth_fail_pulse),
    .i_lockdown_active(w_lockdown_active),
    .o_jtag_disable   (o_jtag_disable   ),
    .o_debug_enable   (o_debug_enable   )
  );
endmodule
