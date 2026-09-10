// --- BCD 轉七段顯示解碼器 (內部使用 Active High：1為亮) ---
module bcd_to_7seg(
    input  [3:0] bcd,
    output reg [6:0] seg 
);
    // 陣列對應: {a, b, c, d, e, f, g}
    always @(*) begin
        case(bcd)
            4'd0: seg = 7'b1111110;
            4'd1: seg = 7'b0110000;
            4'd2: seg = 7'b1101101;
            4'd3: seg = 7'b1111001;
            4'd4: seg = 7'b0110011;
            4'd5: seg = 7'b1011011;
            4'd6: seg = 7'b1011111;
            4'd7: seg = 7'b1110000;
            4'd8: seg = 7'b1111111;
            4'd9: seg = 7'b1111011;
            default: seg = 7'b0000000;
        endcase
    end
endmodule

// --- VGA 螢幕上的七段顯示渲染器 (16x32 像素) ---
module vga_osd_digit (
    input [9:0] h_cnt, v_cnt,
    input [9:0] x, y,
    input [6:0] seg, // 來自解碼器的訊號
    output draw
);
    // 根據 seg[6:0] 的 1/0 狀態，決定要不要畫出對應的長方形
    wire a = seg[6] & (h_cnt >= x+4  && h_cnt <= x+11 && v_cnt >= y    && v_cnt <= y+3);
    wire b = seg[5] & (h_cnt >= x+12 && h_cnt <= x+15 && v_cnt >= y+4  && v_cnt <= y+13);
    wire c = seg[4] & (h_cnt >= x+12 && h_cnt <= x+15 && v_cnt >= y+18 && v_cnt <= y+27);
    wire d = seg[3] & (h_cnt >= x+4  && h_cnt <= x+11 && v_cnt >= y+28 && v_cnt <= y+31);
    wire e = seg[2] & (h_cnt >= x    && h_cnt <= x+3  && v_cnt >= y+18 && v_cnt <= y+27);
    wire f = seg[1] & (h_cnt >= x    && h_cnt <= x+3  && v_cnt >= y+4  && v_cnt <= y+13);
    wire g = seg[0] & (h_cnt >= x+4  && h_cnt <= x+11 && v_cnt >= y+14 && v_cnt <= y+17);

    assign draw = a | b | c | d | e | f | g;
endmodule