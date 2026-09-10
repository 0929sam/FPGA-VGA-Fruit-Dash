module item_manager (
    input clk,
    input rst_n,
    input frame_pulse,
    input hit_trigger,     
    input [6:0] level,     // 【修改】因為每 50 分升級，Level 會變大，改用 7-bit
    
    output reg active,     
    output reg [2:0] lane, 
    output reg [1:0] type, 
    output reg [9:0] y_pos 
);

    wire [15:0] rnd;
    lfsr_16 u_lfsr (.clk(clk), .rst_n(rst_n), .rnd(rnd));

    // 隨機軌道
    wire [2:0] next_lane = (rnd[2:0] > 3'd4) ? (rnd[2:0] - 3'd3) : rnd[2:0]; 
    
    // 【動態機率調配】
    wire [3:0] chance = rnd[7:4];
    // 炸彈機率隨 Level 增加 (閥值越低，炸彈越多)，但最低限制在 8 (最多 50% 是炸彈)
    wire [3:0] bomb_threshold = (level >= 7'd10) ? 4'd8 : (4'd13 - (level[3:0] >> 1));

    wire [1:0] next_type = (chance == 4'd15) ? 2'd3 :                // 時鐘
                           (chance >= bomb_threshold) ? 2'd2 :       // 炸彈
                           (chance >= 4'd8) ? 2'd1 : 2'd0;           // 香蕉與蘋果

    // 【動態速度調配】
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