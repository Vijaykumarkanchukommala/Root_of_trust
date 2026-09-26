//  auth_engine
//  Streams i_fw_data words into SHA-256 with correct PKCS padding.
//  State encoding (matches testbench monitor):
//    IDLE=0  COLLECT=1  PAD_WAIT=2  SEND_LENGTH_BLOCK=3
//    SHA_COMPUTE=4  DONE=5
// ----------------------------------------------------------------
module auth_engine (
  input  logic         i_clk,
  input  logic         i_rst_n,
  input  logic         i_start_auth,
  input  logic [31:0]  i_fw_data,
  input  logic         i_fw_valid,
  input  logic         i_fw_last,
  input  logic [1:0]   i_fw_strobe,
  input  logic [255:0] i_trusted_key,
  output logic         o_auth_done,
  output logic         o_auth_pass
);
  logic sha_start, sha_last_block;
  logic [511:0] sha_block;
  logic [255:0] sha_digest;
  logic sha_done, sha_ready;

  sha256_core u_sha256 (
    .i_clk(i_clk), .i_rst(~i_rst_n),
    .start(sha_start), .block(sha_block), .last_block(sha_last_block),
    .digest(sha_digest), .done(sha_done), .ready(sha_ready)
  );

  // State encoding kept compatible with testbench monitor (state==4'd4 = SHA_COMPUTE)
  typedef enum logic [2:0] {
    IDLE             = 3'd0,
    COLLECT          = 3'd1,
    PAD_WAIT         = 3'd2,
    SEND_LENGTH_BLOCK= 3'd3,
    SHA_COMPUTE      = 3'd4,
    DONE             = 3'd5
  } state_t;
  state_t state;

  logic [511:0] buffer;
  logic [63:0]  total_bits;
  logic [4:0]   word_count;
  logic         last_seen;      // i_fw_last received
  logic         length_pending; // length did not fit in current block
  logic         pad_done;       // 0x80 already written into last data word

  // How many bits does the last word contribute?
  // strobe=0 means all 4 bytes valid (32 bits)
  function automatic [5:0] last_word_bits(input logic [1:0] s);
    case (s)
      2'b01: last_word_bits = 6'd8;
      2'b10: last_word_bits = 6'd16;
      2'b11: last_word_bits = 6'd24;
      default: last_word_bits = 6'd32;
    endcase
  endfunction

  // OR-mask to embed 0x80 immediately after the last valid byte
  function automatic [31:0] pad_byte_mask(input logic [1:0] s);
    case (s)
      2'b01: pad_byte_mask = 32'h00800000;
      2'b10: pad_byte_mask = 32'h00008000;
      2'b11: pad_byte_mask = 32'h00000080;
      default: pad_byte_mask = 32'h00000000;
    endcase
  endfunction

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      state          <= IDLE;
      buffer         <= '0;
      total_bits     <= '0;
      word_count     <= '0;
      last_seen      <= 0;
      length_pending <= 0;
      pad_done       <= 0;
      o_auth_done    <= 0;
      o_auth_pass    <= 0;
      sha_start      <= 0;
      sha_block      <= '0;
      sha_last_block <= 0;
    end else begin
      sha_start <= 1'b0; // default: deassert every cycle

      case (state)

        // ---- IDLE -------------------------------------------------------
        // Wait for start_auth from boot_ctrl_fsm.
        // Reset all state so this engine is clean for every new boot attempt.
        // -----------------------------------------------------------------
        IDLE: begin
          o_auth_done    <= 0;
          o_auth_pass    <= 0;
          buffer         <= '0;
          total_bits     <= '0;
          word_count     <= '0;
          last_seen      <= 0;
          length_pending <= 0;
          pad_done       <= 0;
          if (i_start_auth) state <= COLLECT;
        end

        // ---- COLLECT ----------------------------------------------------
        // Receive one i_fw_data word per i_fw_valid cycle.
        //
        // Three paths:
        //  A) i_fw_last, partial word (strobe!=0):
        //       embed 0x80 in same word, set pad_done=1
        //  B) i_fw_last, full word (strobe==0):
        //       store word normally, pad_done stays 0 (0x80 written next cycle)
        //  C) word_count==15 (block full, not i_fw_last):
        //       flush block -> PAD_WAIT (sha_last_block=0) -> SHA_COMPUTE -> COLLECT
        //
        // After i_fw_last, two more cycles complete the padding:
        //  - If pad_done=0: write 0x80000000 word (or length if room)
        //  - Then write length at buffer[63:0] -> PAD_WAIT
        // -----------------------------------------------------------------
        COLLECT: begin
          if (i_fw_valid && !last_seen) begin

            if (i_fw_last && i_fw_strobe != 2'b00) begin
              // Path A: partial last word with embedded 0x80
              buffer[511 - word_count*32 -: 32] <= i_fw_data | pad_byte_mask(i_fw_strobe);
              total_bits <= total_bits + last_word_bits(i_fw_strobe);
              last_seen  <= 1'b1;
              pad_done   <= 1'b1;
              word_count <= word_count + 1'b1;

            end else begin
              // Path B or C: full word
              buffer[511 - word_count*32 -: 32] <= i_fw_data;
              total_bits <= total_bits + 64'd32;

              if (i_fw_last) begin
                // Path B: last full word - need 0x80 in a subsequent word
                last_seen  <= 1'b1;
                word_count <= word_count + 1'b1;
              end else if (word_count == 5'd15) begin
                // Path C: block boundary, not last - flush this block
                state      <= PAD_WAIT;
                word_count <= '0;
              end else begin
                word_count <= word_count + 1'b1;
              end
            end

          end else if (last_seen && !pad_done) begin
            // Write 0x80 word immediately after last data word
            buffer[511 - word_count*32 -: 32] <= 32'h8000_0000;
            if (word_count <= 5'd13) begin
              // Room for 0x80 AND length in this block
              buffer[63:0]   <= total_bits;
              length_pending <= 1'b0;
            end else begin
              // 0x80 at position 14 or 15 - no room for length
              length_pending <= 1'b1;
            end
            state <= PAD_WAIT;

          end else if (last_seen && pad_done) begin
            // 0x80 already embedded in last data word
            if (word_count <= 5'd14) begin
              // Room for length
              buffer[63:0]   <= total_bits;
              length_pending <= 1'b0;
            end else begin
              // word_count==15: no room for length (0x80 is at word 14)
              length_pending <= 1'b1;
            end
            state <= PAD_WAIT;
          end
        end

        // ---- PAD_WAIT ---------------------------------------------------
        // Wait for SHA core to be ready, then submit the current block.
        // If last_seen=0: this is a mid-stream data block (not last).
        // If last_seen=1: this is the padded block.
        // -----------------------------------------------------------------
        PAD_WAIT: begin
          if (sha_ready) begin
            sha_start <= 1'b1;
            sha_block <= buffer;
            if (last_seen) begin
              if (length_pending) begin
                sha_last_block <= 1'b0;
                state          <= SEND_LENGTH_BLOCK;
              end else begin
                sha_last_block <= 1'b1;
                state          <= SHA_COMPUTE;
              end
            end else begin
              sha_last_block <= 1'b0;
              state          <= SHA_COMPUTE;
            end
          end
        end

        // ---- SEND_LENGTH_BLOCK ------------------------------------------
        // Length did not fit in the padded block.
        // Send an extra block: {zeros[447:0], total_bits[63:0]}
        // -----------------------------------------------------------------
        SEND_LENGTH_BLOCK: begin
          if (sha_ready) begin
            sha_start      <= 1'b1;
            sha_block      <= '0;
            sha_block[63:0]<= total_bits;
            sha_last_block <= 1'b1;
            state          <= SHA_COMPUTE;
          end
        end

        // ---- SHA_COMPUTE ------------------------------------------------
        // Wait for SHA core done signal.
        //   sha_last_block=1 -> final digest ready -> go to DONE
        //   sha_last_block=0 -> mid-stream block done -> clear buffer, resume COLLECT
        // -----------------------------------------------------------------
        SHA_COMPUTE: begin
          if (sha_done) begin
            if (sha_last_block) begin
              o_auth_done <= 1'b1;
              o_auth_pass <= (sha_digest == i_trusted_key);
              state       <= DONE;
            end else begin
              buffer      <= '0;
              state       <= COLLECT;
            end
          end
        end

        // ---- DONE -------------------------------------------------------
        DONE: begin
          if (!i_start_auth) state <= IDLE;
        end

      endcase
    end
  end
endmodule
