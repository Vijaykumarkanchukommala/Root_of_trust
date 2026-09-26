//  Hardware Root-of-Trust (RoT) - design.sv
//  SHA-256 firmware authentication engine
//  Supports arbitrary firmware length (multi 512-bit blocks)
//  sha256_core
//  Single-block SHA-256 compressor.
//  Supports multi-block chaining via reset_hash internal flag.
//    last_block=0 -> update H0..H7 state, assert done, stay ready
//    last_block=1 -> update H0..H7, output digest, reset for next msg
// ----------------------------------------------------------------

module sha256_core(
  input  wire         i_clk,
  input  wire         i_rst,
  input  wire         start,
  input  wire [511:0] block,
  input  wire         last_block,
  output reg  [255:0] digest,
  output reg          done,
  output wire         ready
);
  localparam IDLE=0, LOAD=1, EXPAND=2, ROUND=3, FINAL=4;
  reg [2:0] state;
  reg [31:0] W[0:63];

  function [31:0] get_k(input [5:0] idx);
    case(idx)
      0: get_k=32'h428a2f98; 1: get_k=32'h71374491; 2: get_k=32'hb5c0fbcf; 3: get_k=32'he9b5dba5;
      4: get_k=32'h3956c25b; 5: get_k=32'h59f111f1; 6: get_k=32'h923f82a4; 7: get_k=32'hab1c5ed5;
      8: get_k=32'hd807aa98; 9: get_k=32'h12835b01; 10: get_k=32'h243185be; 11: get_k=32'h550c7dc3;
      12: get_k=32'h72be5d74; 13: get_k=32'h80deb1fe; 14: get_k=32'h9bdc06a7; 15: get_k=32'hc19bf174;
      16: get_k=32'he49b69c1; 17: get_k=32'hefbe4786; 18: get_k=32'h0fc19dc6; 19: get_k=32'h240ca1cc;
      20: get_k=32'h2de92c6f; 21: get_k=32'h4a7484aa; 22: get_k=32'h5cb0a9dc; 23: get_k=32'h76f988da;
      24: get_k=32'h983e5152; 25: get_k=32'ha831c66d; 26: get_k=32'hb00327c8; 27: get_k=32'hbf597fc7;
      28: get_k=32'hc6e00bf3; 29: get_k=32'hd5a79147; 30: get_k=32'h06ca6351; 31: get_k=32'h14292967;
      32: get_k=32'h27b70a85; 33: get_k=32'h2e1b2138; 34: get_k=32'h4d2c6dfc; 35: get_k=32'h53380d13;
      36: get_k=32'h650a7354; 37: get_k=32'h766a0abb; 38: get_k=32'h81c2c92e; 39: get_k=32'h92722c85;
      40: get_k=32'ha2bfe8a1; 41: get_k=32'ha81a664b; 42: get_k=32'hc24b8b70; 43: get_k=32'hc76c51a3;
      44: get_k=32'hd192e819; 45: get_k=32'hd6990624; 46: get_k=32'hf40e3585; 47: get_k=32'h106aa070;
      48: get_k=32'h19a4c116; 49: get_k=32'h1e376c08; 50: get_k=32'h2748774c; 51: get_k=32'h34b0bcb5;
      52: get_k=32'h391c0cb3; 53: get_k=32'h4ed8aa4a; 54: get_k=32'h5b9cca4f; 55: get_k=32'h682e6ff3;
      56: get_k=32'h748f82ee; 57: get_k=32'h78a5636f; 58: get_k=32'h84c87814; 59: get_k=32'h8cc70208;
      60: get_k=32'h90befffa; 61: get_k=32'ha4506ceb; 62: get_k=32'hbef9a3f7; 63: get_k=32'hc67178f2;
      default: get_k=32'h0;
    endcase
  endfunction

  reg [31:0] a,b,c,d,e,f,g,h;
  reg [31:0] h0,h1,h2,h3,h4,h5,h6,h7;
  reg [6:0]  round, widx;
  reg        last_block_reg, reset_hash;

  assign ready = (state == IDLE);

  function [31:0] rotr(input [31:0] x, input [4:0] n);
    rotr = (x >> n) | (x << (32-n));
  endfunction
  function [31:0] ch(input [31:0] x, input [31:0] y, input [31:0] z);
    ch = (x & y) ^ (~x & z);
  endfunction
  function [31:0] maj(input [31:0] x, input [31:0] y, input [31:0] z);
    maj = (x & y) ^ (x & z) ^ (y & z);
  endfunction
  function [31:0] ep0(input [31:0] x); ep0 = rotr(x,2)^rotr(x,13)^rotr(x,22); endfunction
  function [31:0] ep1(input [31:0] x); ep1 = rotr(x,6)^rotr(x,11)^rotr(x,25); endfunction
  function [31:0] sig0(input [31:0] x); sig0 = rotr(x,7)^rotr(x,18)^(x>>3);   endfunction
  function [31:0] sig1(input [31:0] x); sig1 = rotr(x,17)^rotr(x,19)^(x>>10); endfunction

  wire [31:0] T1 = h + ep1(e) + ch(e,f,g) + get_k(round[5:0]) + W[round[5:0]];
  wire [31:0] T2 = ep0(a) + maj(a,b,c);

  always @(posedge i_clk) begin
    if (i_rst) begin
      state <= IDLE; done <= 0; round <= 0; reset_hash <= 1; digest <= 0;
      last_block_reg <= 0; widx <= 0;
      h0<=0; h1<=0; h2<=0; h3<=0; h4<=0; h5<=0; h6<=0; h7<=0;
      a<=0; b<=0; c<=0; d<=0; e<=0; f<=0; g<=0; h<=0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            last_block_reg <= last_block;
            if (reset_hash) begin
              h0 <= 32'h6a09e667; h1 <= 32'hbb67ae85;
              h2 <= 32'h3c6ef372; h3 <= 32'ha54ff53a;
              h4 <= 32'h510e527f; h5 <= 32'h9b05688c;
              h6 <= 32'h1f83d9ab; h7 <= 32'h5be0cd19;
              reset_hash <= 0;
            end
            state <= LOAD;
          end
        end

        LOAD: begin
          W[0] <=block[511:480]; W[1] <=block[479:448]; W[2] <=block[447:416]; W[3] <=block[415:384];
          W[4] <=block[383:352]; W[5] <=block[351:320]; W[6] <=block[319:288]; W[7] <=block[287:256];
          W[8] <=block[255:224]; W[9] <=block[223:192]; W[10]<=block[191:160]; W[11]<=block[159:128];
          W[12]<=block[127:96];  W[13]<=block[95:64];   W[14]<=block[63:32];   W[15]<=block[31:0];
          widx <= 16; state <= EXPAND;
        end

        EXPAND: begin
          W[widx[5:0]] <= sig1(W[(widx-2)&63]) + W[(widx-7)&63]
                        + sig0(W[(widx-15)&63]) + W[(widx-16)&63];
          if (widx == 63) begin
            a<=h0; b<=h1; c<=h2; d<=h3; e<=h4; f<=h5; g<=h6; h<=h7;
            round <= 0; state <= ROUND;
          end else widx <= widx + 1;
        end

        ROUND: begin
          h<=g; g<=f; f<=e; e<=d+T1; d<=c; c<=b; b<=a; a<=T1+T2;
          if (round == 63) state <= FINAL; else round <= round + 1;
        end

        FINAL: begin
          h0 <= h0+a; h1 <= h1+b; h2 <= h2+c; h3 <= h3+d;
          h4 <= h4+e; h5 <= h5+f; h6 <= h6+g; h7 <= h7+h;
          if (last_block_reg) begin
            digest    <= {h0+a,h1+b,h2+c,h3+d,h4+e,h5+f,h6+g,h7+h};
            reset_hash <= 1;
          end
          done  <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
