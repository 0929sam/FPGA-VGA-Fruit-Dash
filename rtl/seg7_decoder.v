// 單個七段顯示器解碼器
module seg7_decoder(
    input  wire [3:0] bin,
    output reg  [6:0] seg // Active Low (0 亮, 1 滅)
);
    always @(*) begin
        case (bin)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'ha: seg = 7'b0001000;
            4'hb: seg = 7'b0000011;
            4'hc: seg = 7'b1000110;
            4'hd: seg = 7'b0100001;
            4'he: seg = 7'b0000110;
            4'hf: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule

// 處理 4 顆七段顯示器的整合模組
module score_to_hex(
    input  wire [15:0] score,
    output wire [6:0]  hex0,
    output wire [6:0]  hex1,
    output wire [6:0]  hex2,
    output wire [6:0]  hex3
);
    // 因為 score 是 16 進位的數字 (例如得 10 分，其實是加上 16'h000A)
    // 為了在 HEX 上顯示漂亮的十進位分數，我們應該做 BCD 轉換。
    // 但為了簡單起見，我們先直接把 score 的 16 進位值丟給 HEX。
    // 如果你發現吃了一個方塊加的是 "A" 而不是 "10"，那是因為這模組目前顯示 16 進位。
    
    seg7_decoder u_hex0 (.bin(score[3:0]),   .seg(hex0));
    seg7_decoder u_hex1 (.bin(score[7:4]),   .seg(hex1));
    seg7_decoder u_hex2 (.bin(score[11:8]),  .seg(hex2));
    seg7_decoder u_hex3 (.bin(score[15:12]), .seg(hex3));

endmodule