module TOP(		
    input            CLOCK_50,
    input            SW0, SW1, SW2,
    input            reset_n, // SW9
    input            KEY0, KEY1, KEY2, KEY3,
	 
	 output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
	 output wire [6:0] HEX4,
	 output wire [6:0] HEX5,
    
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output           VGA_CLK,
    output           VGA_BLANK_N,
    output           VGA_HS,
    output           VGA_VS,
    output           VGA_SYNC_N						
);
	
    // --- 1. 時脈產生器 (50MHz -> 25.175MHz) ---
    // (確認你的新專案有把 clk_gen 這個 IP 搬過來)
    clk_gen u0 (
        .refclk  (CLOCK_50), 
        .rst     (~reset_n), 
        .outclk_0(VGA_CLK),  
        .locked  ()  			
    );
	
    reg [9:0] h_cnt; // 水平計數器 0 ~ 799
    reg [9:0] v_cnt; // 垂直計數器 0 ~ 524
	
    // --- 2. VGA 時序計數邏輯 (絕對不變的核心) ---
    always @(posedge VGA_CLK or negedge reset_n) begin
        if(!reset_n)
            h_cnt <= 10'd0;
        else if(h_cnt == 10'd799)
            h_cnt <= 10'd0;
        else 
            h_cnt <= h_cnt + 10'd1;	
    end
	
    always @(posedge VGA_CLK or negedge reset_n) begin
        if(!reset_n)
            v_cnt <= 10'd0; 
        else if(h_cnt == 10'd799) begin
            if(v_cnt == 10'd524)
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 10'd1;
        end
    end
	
    // --- 3. 同步與消隱訊號分配 ---
    assign VGA_HS = (h_cnt >= 656 && h_cnt <= 751) ? 1'b0 : 1'b1;
    assign VGA_VS = (v_cnt >= 490 && v_cnt <= 491) ? 1'b0 : 1'b1;
	
    wire video_on = (h_cnt < 640 && v_cnt < 480);
    assign VGA_BLANK_N = video_on;
    assign VGA_SYNC_N  = 1'b0;

    // --- 每秒 60 次的畫面重新整理脈衝 (通常做動態控制會用到) ---
    wire frame_pulse = (h_cnt == 10'd799 && v_cnt == 10'd524);

	 // =========================================================
    //  按鍵防彈跳 (Debounce)
    // =========================================================
    wire db_key0, db_key1, db_key2, db_key3;

    key_debounce u_db0 (.clk(VGA_CLK), .rst_n(reset_n), .key_in(KEY0), .key_out(db_key3));
    key_debounce u_db1 (.clk(VGA_CLK), .rst_n(reset_n), .key_in(KEY1), .key_out(db_key2));
    key_debounce u_db2 (.clk(VGA_CLK), .rst_n(reset_n), .key_in(KEY2), .key_out(db_key1));
    key_debounce u_db3 (.clk(VGA_CLK), .rst_n(reset_n), .key_in(KEY3), .key_out(db_key0));
	 
	 // =========================================================
    // 分數顯示 (七段顯示器)
    // =========================================================
    score_to_hex u_score_disp (
        .score (score),
        .hex0  (HEX0),
        .hex1  (HEX1),
        .hex2  (HEX2),
        .hex3  (HEX3)
    );
	 
	 // =========================================================
    //  Lab 7 的新功能將在這裡開發！
    // =========================================================

    // 1. 宣告用來連接引擎與 UI 的動態 Y 座標線
    wire [9:0] dynamic_y0;
    wire [9:0] dynamic_y1;
    wire [9:0] dynamic_y2;
    wire [9:0] dynamic_y3;

    	 // (TOP.v 裡新增這兩個 wire)
    wire [3:0]  hit_effect;
    wire [15:0] score;

    // 2. 呼叫遊戲引擎 (負責計算座標與判定)
    rhythm_engine u_engine (
        .clk         (VGA_CLK),
        .rst_n       (reset_n),
        .frame_pulse (frame_pulse), 
		  
		  .note_active0(active0), .note_active1(active1), 
        .note_active2(active2), .note_active3(active3),
        
        // 把 DE10 板子上的四個 KEY 接給引擎
        .key0        (db_key0), 
        .key1        (db_key1),
        .key2        (db_key2),
        .key3        (db_key3),
		  
        .note_y0     (dynamic_y0),
        .note_y1     (dynamic_y1),
        .note_y2     (dynamic_y2),
        .note_y3     (dynamic_y3),
        
        .hit_effect  (hit_effect), // 接收判定特效訊號
        .score       (score),       // 接收分數
		  .combo       (combo)  
    );

    // 3. 呼叫 UI 模組 (負責畫圖)
    vga_rhythm_ui u_ui (
        .clk      (VGA_CLK),	
        .rst_n    (reset_n),
        .h_cnt    (h_cnt),
        .v_cnt    (v_cnt),
        .video_on (video_on),
        
        .note_y0  (dynamic_y0), // 把引擎算好的動態座標交給 UI 畫出來
        .note_y1  (dynamic_y1),
        .note_y2  (dynamic_y2),
        .note_y3  (dynamic_y3),
		  
		  .note_active0(active0), .note_active1(active1), 
        .note_active2(active2), .note_active3(active3),
        
		  .score       (score),
        .combo       (combo),  // 新增接線
		  
        .vga_r    (VGA_R),
        .vga_g    (VGA_G),
        .vga_b    (VGA_B)
    );
	 

	 
	
endmodule