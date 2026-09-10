module vga_draw_digit(
    input  wire [9:0] h_cnt, v_cnt,
    input  wire [9:0] x, y,        // 數字的左上角座標
    input  wire [3:0] digit,       // 要顯示的數字 (0~9)
    output wire       is_on        // 輸出：目前掃描點是否在數字的筆畫上
);

    // 筆畫尺寸設定 (寬 20, 高 40, 粗細 4)
    wire s0 = (h_cnt >= x)      && (h_cnt <= x+20) && (v_cnt >= y)      && (v_cnt <= y+4);  // 上橫
    wire s1 = (h_cnt >= x+16)   && (h_cnt <= x+20) && (v_cnt >= y)      && (v_cnt <= y+20); // 右上直
    wire s2 = (h_cnt >= x+16)   && (h_cnt <= x+20) && (v_cnt >= y+20)   && (v_cnt <= y+40); // 右下直
    wire s3 = (h_cnt >= x)      && (h_cnt <= x+20) && (v_cnt >= y+36)   && (v_cnt <= y+40); // 下橫
    wire s4 = (h_cnt >= x)      && (h_cnt <= x+4)  && (v_cnt >= y+20)   && (v_cnt <= y+40); // 左下直
    wire s5 = (h_cnt >= x)      && (h_cnt <= x+4)  && (v_cnt >= y)      && (v_cnt <= y+20); // 左上直
    wire s6 = (h_cnt >= x)      && (h_cnt <= x+20) && (v_cnt >= y+18)   && (v_cnt <= y+22); // 中橫

    reg [6:0] seg_en; // [6:0] 對應 {s6,s5,s4,s3,s2,s1,s0}
    always @(*) begin
        case(digit)
            4'd0: seg_en = 7'b0111111;
            4'd1: seg_en = 7'b0000110;
            4'd2: seg_en = 7'b1011011;
            4'd3: seg_en = 7'b1001111;
            4'd4: seg_en = 7'b1100110;
            4'd5: seg_en = 7'b1101101;
            4'd6: seg_en = 7'b1111101;
            4'd7: seg_en = 7'b0000111;
            4'd8: seg_en = 7'b1111111;
            4'd9: seg_en = 7'b1101111;
            default: seg_en = 7'b0000000;
        endcase
    end

    assign is_on = (seg_en[0] & s0) | (seg_en[1] & s1) | (seg_en[2] & s2) |
                   (seg_en[3] & s3) | (seg_en[4] & s4) | (seg_en[5] & s5) | (seg_en[6] & s6);
endmodule