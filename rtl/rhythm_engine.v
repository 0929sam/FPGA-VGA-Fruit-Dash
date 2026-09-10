module rhythm_engine(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_pulse,
    
    input  wire        key0, 
    input  wire        key1,
    input  wire        key2,
    input  wire        key3,

    output reg  [9:0]  note_y0,
    output reg  [9:0]  note_y1,
    output reg  [9:0]  note_y2,
    output reg  [9:0]  note_y3,
    
    // 🌟 新增：輸出方塊是否存活給 UI (活著才畫出來)
    output reg         note_active0,
    output reg         note_active1,
    output reg         note_active2,
    output reg         note_active3,
    
    output reg  [3:0]  hit_effect,
    output reg  [15:0] score,
    output reg  [15:0] combo
);

    parameter SPEED         = 10'd6;
    parameter SCREEN_BOTTOM = 10'd480;
    parameter HIT_ZONE_TOP  = 10'd300;
    parameter HIT_ZONE_BOT  = 10'd400;

    // --- (按鍵防彈跳邏輯不變) ---
    reg key0_d1, key1_d1, key2_d1, key3_d1;
    reg key0_d2, key1_d2, key2_d2, key3_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key0_d1 <= 1'b1; key1_d1 <= 1'b1; key2_d1 <= 1'b1; key3_d1 <= 1'b1; 
            key0_d2 <= 1'b1; key1_d2 <= 1'b1; key2_d2 <= 1'b1; key3_d2 <= 1'b1;
        end else begin
            key0_d1 <= key0; key1_d1 <= key1; key2_d1 <= key2; key3_d1 <= key3;
            key0_d2 <= key0_d1; key1_d2 <= key1_d1; key2_d2 <= key2_d1; key3_d2 <= key3_d1;
        end
    end
    wire key0_press = (key0_d2 == 1'b1) && (key0_d1 == 1'b0);
    wire key1_press = (key1_d2 == 1'b1) && (key1_d1 == 1'b0);
    wire key2_press = (key2_d2 == 1'b1) && (key2_d1 == 1'b0);
    wire key3_press = (key3_d2 == 1'b1) && (key3_d1 == 1'b0);

    // ==========================================
    // 引擎本體 (加入 Active 狀態管理)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            note_y0 <= 10'd0; note_y1 <= 10'd120; note_y2 <= 10'd240; note_y3 <= 10'd360;
            // 系統重置時，強制讓 4 個方塊存活
            note_active0 <= 1'b1; note_active1 <= 1'b1; note_active2 <= 1'b1; note_active3 <= 1'b1;
            
            score <= 16'd0;
            combo <= 16'd0;
            hit_effect <= 4'b0000;
        end else begin
            hit_effect <= 4'b0000;

            // --- 軌道 0 ---
            // 只有當方塊是「活著(active)」的時候才能被打中
            if (note_active0 && key0_press && (note_y0 >= HIT_ZONE_TOP) && (note_y0 <= HIT_ZONE_BOT)) begin
                note_active0 <= 1'b0; // 打中就死亡！不再畫出來
                hit_effect[0] <= 1'b1;
                // Combo + 1 
                if (combo[3:0] == 9) begin combo[3:0] <= 0; combo[7:4] <= combo[7:4] + 1;
                end else combo[3:0] <= combo[3:0] + 1;
                // Score + 1 
                if (score[7:4] == 9) begin score[7:4] <= 0; score[11:8] <= score[11:8] + 1;
                end else score[7:4] <= score[7:4] + 1;
            end else if (frame_pulse) begin
                if (note_y0 >= SCREEN_BOTTOM) begin 
                    note_y0 <= 10'd0; 
                    // 【真正的漏接判定】: 如果掉到底部時，方塊還是「活著」的，才算漏接！
                    if (note_active0) combo <= 16'd0; 
                    
                    // 為了測試方便 (假 SRAM)，掉到底部後我們讓它「重生」
                    note_active0 <= 1'b1; 
                end
                else note_y0 <= note_y0 + SPEED;
            end

            // --- 軌道 1 ---
            if (note_active1 && key1_press && (note_y1 >= HIT_ZONE_TOP) && (note_y1 <= HIT_ZONE_BOT)) begin
                note_active1 <= 1'b0; hit_effect[1] <= 1'b1;
                if (combo[3:0] == 9) begin combo[3:0] <= 0; combo[7:4] <= combo[7:4] + 1;
                end else combo[3:0] <= combo[3:0] + 1;
                if (score[7:4] == 9) begin score[7:4] <= 0; score[11:8] <= score[11:8] + 1;
                end else score[7:4] <= score[7:4] + 1;
            end else if (frame_pulse) begin
                if (note_y1 >= SCREEN_BOTTOM) begin 
                    note_y1 <= 10'd0; 
                    if (note_active1) combo <= 16'd0; 
                    note_active1 <= 1'b1; // 重生
                end
                else note_y1 <= note_y1 + SPEED;
            end

            // --- 軌道 2 ---
            if (note_active2 && key2_press && (note_y2 >= HIT_ZONE_TOP) && (note_y2 <= HIT_ZONE_BOT)) begin
                note_active2 <= 1'b0; hit_effect[2] <= 1'b1;
                if (combo[3:0] == 9) begin combo[3:0] <= 0; combo[7:4] <= combo[7:4] + 1;
                end else combo[3:0] <= combo[3:0] + 1;
                if (score[7:4] == 9) begin score[7:4] <= 0; score[11:8] <= score[11:8] + 1;
                end else score[7:4] <= score[7:4] + 1;
            end else if (frame_pulse) begin
                if (note_y2 >= SCREEN_BOTTOM) begin 
                    note_y2 <= 10'd0; 
                    if (note_active2) combo <= 16'd0; 
                    note_active2 <= 1'b1; // 重生
                end
                else note_y2 <= note_y2 + SPEED;
            end

            // --- 軌道 3 ---
            if (note_active3 && key3_press && (note_y3 >= HIT_ZONE_TOP) && (note_y3 <= HIT_ZONE_BOT)) begin
                note_active3 <= 1'b0; hit_effect[3] <= 1'b1;
                if (combo[3:0] == 9) begin combo[3:0] <= 0; combo[7:4] <= combo[7:4] + 1;
                end else combo[3:0] <= combo[3:0] + 1;
                if (score[7:4] == 9) begin score[7:4] <= 0; score[11:8] <= score[11:8] + 1;
                end else score[7:4] <= score[7:4] + 1;
            end else if (frame_pulse) begin
                if (note_y3 >= SCREEN_BOTTOM) begin 
                    note_y3 <= 10'd0; 
                    if (note_active3) combo <= 16'd0; 
                    note_active3 <= 1'b1; // 重生
                end
                else note_y3 <= note_y3 + SPEED;
            end
        end
    end
endmodule