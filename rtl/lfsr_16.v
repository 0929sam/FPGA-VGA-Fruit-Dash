module lfsr_16 (
    input clk,
    input rst_n,
    output reg [15:0] rnd
);
    // 16-bit LFSR (XOR feedback on taps 16, 14, 13, 11)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rnd <= 16'hACE1; // 不能是 0，隨便給一個初始種子
        else
            rnd <= {rnd[14:0], rnd[15] ^ rnd[13] ^ rnd[12] ^ rnd[10]};
    end
endmodule