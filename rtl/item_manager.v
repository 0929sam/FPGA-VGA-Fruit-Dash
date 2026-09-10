// =============================================================
// item_manager：掉落物的軌道/種類隨機產生，並依等級動態調整難度
//   - type 編碼：0=蘋果 1=香蕉 2=炸彈 3=時鐘
//   - next_lane / next_type：用 lfsr_16 產生的亂數位元決定下一顆道具的軌道與種類
//   - drop_speed：等級每 +1（每 50 分），掉落速度 +1，上限 9
//   - bomb_threshold：等級越高，判定為炸彈的機率門檻越低，炸彈越常出現（上限 50%）
// =============================================================
module item_manager (
    input clk,
    input rst_n,
    input frame_pulse,
    input hit_trigger,
    input [6:0] level,     // 每 50 分升級一次，數值可能變大，故用 7-bit 而非 4-bit

    output reg active,
    output reg [2:0] lane,
    output reg [1:0] type,
    output reg [9:0] y_pos
);

    wire [15:0] rnd;
    lfsr_16 u_lfsr (.clk(clk), .rst_n(rst_n), .rnd(rnd));

    // 隨機軌道：把 rnd 低 3 bit（0~7）折疊壓縮進 5 條軌道（0~4）
    wire [2:0] next_lane = (rnd[2:0] > 3'd4) ? (rnd[2:0] - 3'd3) : rnd[2:0];

    // --- 動態機率調配 ---
    wire [3:0] chance = rnd[7:4];
    // 炸彈機率隨 Level 增加 (閥值越低，炸彈越多)，但最低限制在 8 (最多 50% 是炸彈)
    wire [3:0] bomb_threshold = (level >= 7'd10) ? 4'd8 : (4'd13 - (level[3:0] >> 1));

    wire [1:0] next_type = (chance == 4'd15) ? 2'd3 :                // 時鐘
                           (chance >= bomb_threshold) ? 2'd2 :       // 炸彈
                           (chance >= 4'd8) ? 2'd1 : 2'd0;           // 香蕉與蘋果

    // --- 動態速度調配 ---
    // 基礎速度 3，Level 每多 1 (每50分)，速度加 1。最高限速為 9
    wire [9:0] calc_speed = 10'd3 + {3'd0, level};
    wire [9:0] drop_speed = (calc_speed > 10'd9) ? 10'd9 : calc_speed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            lane   <= 3'd2; 
            type   <= 2'd0;
            y_pos  <= 10'd0;
        end else if (frame_pulse) begin
            // 三種情況都要重新生成一顆新道具：還沒啟用、剛被接到、或掉出畫面底部
            if (!active || hit_trigger || y_pos >= 10'd432) begin
                active <= 1'b1;
                y_pos  <= 10'd0;
                lane   <= next_lane;
                type   <= next_type;
            end else begin
                y_pos  <= y_pos + drop_speed;
            end
        end
    end
endmodule