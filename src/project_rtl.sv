module PriorityEncoder
#(
    parameter BITS=32,
    parameter N=1
)
(
    input logic[BITS-1:0] IN_data,
    output logic[$clog2(BITS)-1:0] OUT_idx[N-1:0],
    output logic OUT_idxValid[N-1:0]
);

localparam BITS_POW2 = 1 << $clog2(BITS);
wire[BITS_POW2-1:0] freePadded = {{(BITS_POW2-BITS){1'b0}}, IN_data};

// Search Tree for getting index of first N bits set to 1.
// This essentially is the classic count-leading-zeros type
// search tree, but instead of tracking one index, we track
// N indices.
localparam NUM_STAGES = $clog2(BITS_POW2); // excl base case
generate
for (genvar g = 0; g < NUM_STAGES+1; g=g+1) begin : gen
    logic[N-1:0][g:0] s[(BITS_POW2>>g)-1:0];

    // Base
    if (g == 0) begin
        always_comb begin
            for (integer i = 0; i < BITS_POW2; i=i+1) begin
                for (integer j = 0; j < N; j=j+1)
                    s[i][j] = 1; // LSBit represents undefined
                s[i][0] = !freePadded[i];
            end
        end
    end
    // Step
    else begin
        for (genvar i = 0; i < (BITS_POW2>>g); i=i+1) begin
            wire[N-1:0][g-1:0] a = gen[g-1].s[2*i+0];
            wire[N-1:0][g-1:0] b = gen[g-1].s[2*i+1];

            for (genvar j = 0; j < N; j=j+1) begin : gen2

                // manually build mux to avoid non-const index arithmetic
                wire[g-1:0] mux[j+1:0];
                for (genvar k = 0; k <= j; k=k+1)
                    assign mux[k] = b[j - k];
                assign mux[j+1] = a[j];

                // verilator lint_off WIDTHEXPAND
                wire[j == 0 ? 0 : ($clog2(j+2)-1):0] redSum;
                if (j == 0) assign redSum = !a[j][0];
                else        assign redSum = !a[j][0] + gen2[j-1].redSum;
                // verilator lint_on WIDTHEXPAND

                assign s[i][j] = {a[j][0], mux[redSum]};
            end
        end
    end
end
endgenerate

wire[N-1:0][$clog2(BITS):0] packedIdcs = gen[NUM_STAGES].s[0];
always_comb begin
    for (integer i = 0; i < N; i=i+1) begin
        OUT_idx[i] = packedIdcs[i][$clog2(BITS):1];
        OUT_idxValid[i] = !packedIdcs[i][0];
    end
end

endmodule


module tt_um_dyno(
input wire [7:0] ui_in,
output wire [7:0] uo_out,
input wire [7:0] uio_in,
output wire [7:0] uio_out,
output wire [7:0] uio_oe,
input wire ena,
input wire clk,
input wire rst_n
);

// Priority Encoder to get index of first three set bits in input byte.
// Inputs and outputs either registered or combinatorial.
wire input_registered = uio_in[7];
wire output_registered = uio_in[6];

logic[7:0] ui_in_r;
always_ff@(posedge clk)
    ui_in_r <= ui_in;

wire[7:0] in = input_registered ? ui_in_r : ui_in;

logic[3*4-1:0] out_flat_c, out_flat_r;
PriorityEncoder#(8, 3) penc(.IN_data(in), .OUT_idx('{out_flat_c[8+:3], out_flat_c[4+:3], out_flat_c[0+:3]}), .OUT_idxValid('{out_flat_c[11], out_flat_c[7], out_flat_c[3]}));

always_ff@(posedge clk)
    out_flat_r <= out_flat_c;


assign {uio_out[3:0], uo_out} = output_registered ? out_flat_r : out_flat_c;
assign uio_oe = 8'b00111111;


// Counter on unused two pins
logic[1:0] cnt;
always_ff@(posedge clk)
  cnt <= cnt + 1;
assign uio_out[5:4] = cnt;
assign uio_out[7:6] = '0; // unused

wire _unused = &{ena, 1'b0};

endmodule