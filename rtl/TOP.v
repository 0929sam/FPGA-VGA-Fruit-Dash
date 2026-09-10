module TOP(		
    input            CLOCK_50,
    input            reset_n,     
    input            KEY0,        // 右
    input            KEY1,        // 左
    input            KEY2,        // 【新增回腳位清單】遊戲操作：瞬間衝刺位移 / 選單：任意鍵
    input            KEY3,        // 跳躍
    
    output [6:0]     HEX0, HEX1, HEX2, HEX3,
    output reg [7:0] VGA_R, VGA_G, VGA_B,
    output           VGA_CLK, VGA_BLANK_N, VGA_HS, VGA_VS, VGA_SYNC_N						
);
	
    // =========================================================
    //  1. 時脈產生器 & VGA 時序邏輯
    // =========================================================
    clk_gen u0 (.refclk(CLOCK_50), .rst(~reset_n), .outclk_0(VGA_CLK), .locked());
    
    reg [9:0] h_cnt, v_cnt;
    always @(posedge VGA_CLK or negedge reset_n) begin
        if(!reset_n) h_cnt <= 10'd0;
        else if(h_cnt == 10'd799) h_cnt <= 10'd0;
        else h_cnt <= h_cnt + 10'd1;	
    end
    always @(posedge VGA_CLK or negedge reset_n) begin
        if(!reset_n) v_cnt <= 10'd0; 
        else if(h_cnt == 10'd799) begin
            if(v_cnt == 10'd524) v_cnt <= 10'd0;
            else v_cnt <= v_cnt + 10'd1;
        end
    end
    assign VGA_HS = (h_cnt >= 656 && h_cnt <= 751) ? 1'b0 : 1'b1;
    assign VGA_VS = (v_cnt >= 490 && v_cnt <= 491) ? 1'b0 : 1'b1;
    wire video_on = (h_cnt < 640 && v_cnt < 480);
    assign VGA_BLANK_N = video_on; assign VGA_SYNC_N  = 1'b0;
    
    wire frame_pulse = (h_cnt == 10'd799 && v_cnt == 10'd524);

    // =========================================================
    //  2. 遊戲主狀態機 (FSM)
    // =========================================================
    localparam STATE_START    = 2'd0;
    localparam STATE_PLAY     = 2'd1;
    localparam STATE_GAMEOVER = 2'd2;
    reg [1:0] current_state; reg [1:0] last_state; reg soft_reset; 

    reg [2:0] hp; reg [3:0] t1, t0; reg [3:0] s0, s1, s2, s3; reg [5:0] hurt_timer;     
    wire game_over = (current_state == STATE_GAMEOVER);

    // 選單導航：包含 KEY2 偵測
    reg any_key_d0, any_key_d1;
    wire any_key_pressed = any_key_d1 && !any_key_d0;
    always @(posedge VGA_CLK or negedge reset_n) begin
        if (!reset_n) begin
            any_key_d0 <= 1'b1; any_key_d1 <= 1'b1;
        end else begin
            any_key_d0 <= KEY0 && KEY1 && KEY3 && KEY2; // 偵測納入 KEY2
            any_key_d1 <= any_key_d0;
        end
    end

    always @(posedge VGA_CLK or negedge reset_n) begin
        if (!reset_n) begin current_state <= STATE_START; soft_reset <= 1'b0; end 
        else begin
            soft_reset <= 1'b0;
            case (current_state)
                STATE_START:    if (any_key_pressed) begin current_state <= STATE_PLAY; soft_reset <= 1'b1; end
                STATE_PLAY:     if ((hp == 0) || (t1 == 4'd0 && t0 == 4'd0)) current_state <= STATE_GAMEOVER;
                STATE_GAMEOVER: if (any_key_pressed) current_state <= STATE_START;
                default:        current_state <= STATE_START;
            endcase
        end
    end

    always @(posedge VGA_CLK or negedge reset_n) begin
        if (!reset_n) last_state <= STATE_START; else last_state <= current_state;
    end
    wire game_just_ended = (last_state == STATE_PLAY && current_state == STATE_GAMEOVER);

    reg [5:0] fps_cnt;
    wire sec_pulse = (fps_cnt == 6'd59) && frame_pulse && (current_state == STATE_PLAY);
    always @(posedge VGA_CLK or negedge reset_n) begin
        if (!reset_n) fps_cnt <= 6'd0;
        else if (frame_pulse && (current_state == STATE_PLAY)) fps_cnt <= (fps_cnt == 6'd59) ? 6'd0 : fps_cnt + 6'd1;
    end

    // =========================================================
    //  2.5 排行榜系統 (跨局保留最高紀錄)
    // =========================================================
    reg [15:0] h1, h2, h3, h4, h5; wire [15:0] current_score = {s3, s2, s1, s0};
    always @(posedge VGA_CLK or negedge reset_n) begin
        if (!reset_n) begin h1 <= 0; h2 <= 0; h3 <= 0; h4 <= 0; h5 <= 0; end 
        else if (game_just_ended) begin
            if (current_score > h1) begin h1 <= current_score; h2 <= h1; h3 <= h2; h4 <= h3; h5 <= h4; end 
            else if (current_score > h2) begin h2 <= current_score; h3 <= h2; h4 <= h3; h5 <= h4; end 
            else if (current_score > h3) begin h3 <= current_score; h4 <= h3; h5 <= h4; end 
            else if (current_score > h4) begin h4 <= current_score; h5 <= h4; end 
            else if (current_score > h5) begin h5 <= current_score; end
        end
    end

    // =========================================================
    //  3. 實體化玩家控制端【接入 KEY2】
    // =========================================================
    wire [9:0] player_x, player_y;
    player_ctrl u_player (
        .clk(VGA_CLK), .rst_n(reset_n && !soft_reset), 
        .frame_pulse(frame_pulse && (current_state == STATE_PLAY)),
        .key_left(KEY1), .key_right(KEY0), .key_jump(KEY3),
        .key_dash(KEY2), // 【這裡把實體 KEY2 綁定進去端點】
        .player_x(player_x), .player_y(player_y)
    );

    // =========================================================
    //  3.5 實體化掉落物管理
    // =========================================================
    wire item_active; wire [2:0] item_lane; wire [1:0] item_type; wire [9:0] item_y;
    wire [9:0] item_x = (item_lane == 3'd0) ? 10'd160 : (item_lane == 3'd1) ? 10'd240 :
                        (item_lane == 3'd2) ? 10'd320 : (item_lane == 3'd3) ? 10'd400 : 10'd480;

    wire [6:0] current_level = (s3 * 7'd20) + (s2 * 7'd2) + (s1 >= 4'd5 ? 7'd1 : 7'd0);
    wire x_overlap = (player_x + 10'd32 > item_x) && (player_x < item_x + 10'd32);
    wire y_overlap = (player_y + 10'd32 > item_y) && (player_y < item_y + 10'd32);
    wire hit_trigger = item_active && x_overlap && y_overlap;

    item_manager u_item (
        .clk(VGA_CLK), .rst_n(reset_n && !soft_reset), .frame_pulse(frame_pulse && (current_state == STATE_PLAY)),
        .hit_trigger(hit_trigger), .level(current_level),
        .active(item_active), .lane(item_lane), .type(item_type), .y_pos(item_y)
    );

    // =========================================================
    //  3.8 ROM 影像模組讀取
    // =========================================================
    wire inside_item = (h_cnt >= item_x && h_cnt < item_x + 10'd32) && (v_cnt >= item_y && v_cnt < item_y + 10'd32);
    wire [9:0] rom_addr = inside_item ? ((h_cnt - item_x) + ((v_cnt - item_y) * 10'd32)) : 10'd0;
    wire [11:0] rom_q_apple, rom_q_banana, rom_q_bomb, rom_q_clock;
    apple  u_apple  (.address(rom_addr), .clock(VGA_CLK), .q(rom_q_apple));
    banana u_banana (.address(rom_addr), .clock(VGA_CLK), .q(rom_q_banana));
    bomb   u_bomb   (.address(rom_addr), .clock(VGA_CLK), .q(rom_q_bomb));
    clock  u_clock  (.address(rom_addr), .clock(VGA_CLK), .q(rom_q_clock));	
    wire [11:0] current_rom_q = (item_type == 2'd0) ? rom_q_apple : (item_type == 2'd1) ? rom_q_banana : (item_type == 2'd2) ? rom_q_bomb : rom_q_clock;

    wire inside_player = (h_cnt >= player_x && h_cnt < player_x + 10'd32) && (v_cnt >= player_y && v_cnt < player_y + 10'd32);
    wire [9:0] player_rom_addr = inside_player ? ((h_cnt - player_x) + ((v_cnt - player_y) * 10'd32)) : 10'd0;
    wire [11:0] rom_q_player;
    people u_player_rom (.address(player_rom_addr), .clock(VGA_CLK), .q(rom_q_player));

    // =========================================================
    //  4. 遊戲數值加減邏輯
    // =========================================================
    wire add_5    = (hit_trigger && item_active && item_type == 2'd0);
    wire add_10   = (hit_trigger && item_active && item_type == 2'd1);
    wire hit_bomb = (hit_trigger && item_active && item_type == 2'd2);
    wire add_time = (hit_trigger && item_active && item_type == 2'd3); 

    always @(posedge VGA_CLK or negedge reset_n) begin
        if (!reset_n) begin s0 <= 0; s1 <= 0; s2 <= 0; s3 <= 0; hp <= 3'd5; t1 <= 4'd6; t0 <= 4'd0; hurt_timer <= 6'd0; end 
        else if (soft_reset) begin s0 <= 0; s1 <= 0; s2 <= 0; s3 <= 0; hp <= 3'd5; t1 <= 4'd6; t0 <= 4'd0; hurt_timer <= 6'd0; end 
        else if (frame_pulse && (current_state == STATE_PLAY)) begin
            if (hurt_timer > 0) hurt_timer <= hurt_timer - 6'd1;
            if (hit_bomb && hurt_timer == 0) begin hp <= hp - 3'd1; hurt_timer <= 6'd60; end
            if (add_5) begin
                if (s0 == 4'd5) begin s0 <= 4'd0; if (s1 == 4'd9) begin s1 <= 4'd0; if (s2 == 4'd9) begin s2 <= 4'd0; s3 <= s3 + 1; end else s2 <= s2 + 1; end else s1 <= s1 + 1; end else s0 <= 4'd5;
            end else if (add_10) begin
                if (s1 == 4'd9) begin s1 <= 4'd0; if (s2 == 4'd9) begin s2 <= 4'd0; s3 <= s3 + 1; end else s2 <= s2 + 1; end else s1 <= s1 + 1;
            end
            if (add_time) begin
                if (t1 == 4'd9 && t0 >= 4'd4) begin t1 <= 4'd9; t0 <= 4'd9; end else if (t0 >= 4'd5) begin t0 <= t0 - 4'd5; t1 <= t1 + 4'd1; end else begin t0 <= t0 + 4'd5; end
            end else if (sec_pulse) begin
                if (t0 == 4'd0) begin t1 <= t1 - 4'd1; t0 <= 4'd9; end else begin t0 <= t0 - 4'd1; end
            end
        end
    end

    // =========================================================
    //  5. 七段顯示器 & VGA OSD 渲染電路
    // =========================================================
    wire [6:0] seg0, seg1, seg2, seg3, seg_t0, seg_t1;
    bcd_to_7seg d0(.bcd(s0), .seg(seg0)); bcd_to_7seg d1(.bcd(s1), .seg(seg1));
    bcd_to_7seg d2(.bcd(s2), .seg(seg2)); bcd_to_7seg d3(.bcd(s3), .seg(seg3));
    bcd_to_7seg dt0(.bcd(t0), .seg(seg_t0)); bcd_to_7seg dt1(.bcd(t1), .seg(seg_t1));

    wire [6:0] final_seg3 = (current_state == STATE_START) ? 7'b1100111 : seg3; 
    wire [6:0] final_seg2 = (current_state == STATE_START) ? 7'b0000101 : seg2; 
    wire [6:0] final_seg1 = (current_state == STATE_START) ? 7'b1001111 : seg1; 
    wire [6:0] final_seg0 = (current_state == STATE_START) ? 7'b1011011 : seg0; 

    assign HEX0 = {~final_seg0[0], ~final_seg0[1], ~final_seg0[2], ~final_seg0[3], ~final_seg0[4], ~final_seg0[5], ~final_seg0[6]};
    assign HEX1 = {~final_seg1[0], ~final_seg1[1], ~final_seg1[2], ~final_seg1[3], ~final_seg1[4], ~final_seg1[5], ~final_seg1[6]};
    assign HEX2 = {~final_seg2[0], ~final_seg2[1], ~final_seg2[2], ~final_seg2[3], ~final_seg2[4], ~final_seg2[5], ~final_seg2[6]};
    assign HEX3 = {~final_seg3[0], ~final_seg3[1], ~final_seg3[2], ~final_seg3[3], ~final_seg3[4], ~final_seg3[5], ~final_seg3[6]};

    wire draw_hp_all = (hp>=1 && h_cnt>=20 && h_cnt<=40 && v_cnt>=20 && v_cnt<=40) |
                       (hp>=2 && h_cnt>=50 && h_cnt<=70 && v_cnt>=20 && v_cnt<=40) |
                       (hp>=3 && h_cnt>=80 && h_cnt<=100 && v_cnt>=20 && v_cnt<=40) |
                       (hp>=4 && h_cnt>=110 && h_cnt<=130 && v_cnt>=20 && v_cnt<=40) |
                       (hp>=5 && h_cnt>=140 && h_cnt<=160 && v_cnt>=20 && v_cnt<=40);

    wire [3:0] lvl_bcd_1 = current_level / 10; wire [3:0] lvl_bcd_0 = current_level % 10;
    wire [6:0] seg_l1, seg_l0;
    bcd_to_7seg dl1(.bcd(lvl_bcd_1), .seg(seg_l1)); bcd_to_7seg dl0(.bcd(lvl_bcd_0), .seg(seg_l0));

    wire draw_level_all, d_L, d_l1, d_l0;
    vga_osd_digit osd_L (.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd20), .y(10'd60), .seg(7'b0001110), .draw(d_L));
    vga_osd_digit osd_l1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd40), .y(10'd60), .seg(seg_l1),     .draw(d_l1));
    vga_osd_digit osd_l0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd60), .y(10'd60), .seg(seg_l0),     .draw(d_l0));
    assign draw_level_all = d_L | d_l1 | d_l0;

    wire draw_score_all, d_s0, d_s1, d_s2, d_s3;
    vga_osd_digit osd0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd600), .y(10'd20), .seg(seg0), .draw(d_s0));
    vga_osd_digit osd1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd580), .y(10'd20), .seg(seg1), .draw(d_s1));
    vga_osd_digit osd2(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd560), .y(10'd20), .seg(seg2), .draw(d_s2));
    vga_osd_digit osd3(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd540), .y(10'd20), .seg(seg3), .draw(d_s3));
    assign draw_score_all = d_s0 | d_s1 | d_s2 | d_s3;

    wire draw_time_all, d_t0, d_t1;
    vga_osd_digit osd_t0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd330), .y(10'd20), .seg(seg_t0), .draw(d_t0));
    vga_osd_digit osd_t1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd310), .y(10'd20), .seg(seg_t1), .draw(d_t1));
    assign draw_time_all = d_t0 | d_t1;

    // 結算畫面: "End" 文字
    wire draw_end_text, d_E, d_n, d_d;
    vga_osd_digit osd_E(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd290), .y(10'd100), .seg(7'b1001111), .draw(d_E));
    vga_osd_digit osd_n(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd310), .y(10'd100), .seg(7'b0010101), .draw(d_n));
    vga_osd_digit osd_d(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd330), .y(10'd100), .seg(7'b0111101), .draw(d_d));
    assign draw_end_text = (current_state == STATE_GAMEOVER) && (d_E | d_n | d_d);
    wire is_end_box = (current_state == STATE_GAMEOVER) && (h_cnt >= 260 && h_cnt <= 380 && v_cnt >= 80 && v_cnt <= 300);

    // 主選單畫面: "PRESS" 對話框
    wire draw_press_vga, dp_P, dp_R, dp_E, dp_S1, dp_S2;
    vga_osd_digit p_P (.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd270), .y(10'd220), .seg(7'b1100111), .draw(dp_P));
    vga_osd_digit p_R (.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd290), .y(10'd220), .seg(7'b1110111), .draw(dp_R));
    vga_osd_digit p_E (.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd310), .y(10'd220), .seg(7'b1001111), .draw(dp_E));
    vga_osd_digit p_S1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd330), .y(10'd220), .seg(7'b1011011), .draw(dp_S1));
    vga_osd_digit p_S2(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd350), .y(10'd220), .seg(7'b1011011), .draw(dp_S2));
    assign draw_press_vga = (current_state == STATE_START) && (dp_P | dp_R | dp_E | dp_S1 | dp_S2);
    wire is_start_box = (current_state == STATE_START) && (h_cnt >= 240 && h_cnt <= 400 && v_cnt >= 200 && v_cnt <= 260);

    // =========================================================
    //  5.8 前三名排行榜實體化呼叫
    // =========================================================
    wire [6:0] h1_s3, h1_s2, h1_s1, h1_s0;
    bcd_to_7seg h1_3(.bcd(h1[15:12]), .seg(h1_s3)); bcd_to_7seg h1_2(.bcd(h1[11:8]),  .seg(h1_s2));
    bcd_to_7seg h1_1(.bcd(h1[7:4]),   .seg(h1_s1)); bcd_to_7seg h1_0(.bcd(h1[3:0]),   .seg(h1_s0));
    wire draw_h1_all, dh1_3, dh1_2, dh1_1, dh1_0;
    vga_osd_digit oh1_3(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd290), .y(10'd150), .seg(h1_s3), .draw(dh1_3));
    vga_osd_digit oh1_2(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd310), .y(10'd150), .seg(h1_s2), .draw(dh1_2));
    vga_osd_digit oh1_1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd330), .y(10'd150), .seg(h1_s1), .draw(dh1_1));
    vga_osd_digit oh1_0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd350), .y(10'd150), .seg(h1_s0), .draw(dh1_0));
    assign draw_h1_all = (current_state == STATE_GAMEOVER) && (dh1_3 | dh1_2 | dh1_1 | dh1_0);

    wire [6:0] h2_s3, h2_s2, h2_s1, h2_s0;
    bcd_to_7seg h2_3(.bcd(h2[15:12]), .seg(h2_s3)); bcd_to_7seg h2_2(.bcd(h2[11:8]),  .seg(h2_s2));
    bcd_to_7seg h2_1(.bcd(h2[7:4]),   .seg(h2_s1)); bcd_to_7seg h2_0(.bcd(h2[3:0]),   .seg(h2_s0));
    wire draw_h2_all, dh2_3, dh2_2, dh2_1, dh2_0;
    vga_osd_digit oh2_3(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd290), .y(10'd190), .seg(h2_s3), .draw(dh2_3));
    vga_osd_digit oh2_2(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd310), .y(10'd190), .seg(h2_s2), .draw(dh2_2));
    vga_osd_digit oh2_1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd330), .y(10'd190), .seg(h2_s1), .draw(dh2_1));
    vga_osd_digit oh2_0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd350), .y(10'd190), .seg(h2_s0), .draw(dh2_0));
    assign draw_h2_all = (current_state == STATE_GAMEOVER) && (dh2_3 | dh2_2 | dh2_1 | dh2_0);

    wire [6:0] h3_s3, h3_s2, h3_s1, h3_s0;
    bcd_to_7seg h3_3(.bcd(h3[15:12]), .seg(h3_s3)); bcd_to_7seg h3_2(.bcd(h3[11:8]),  .seg(h3_s2));
    bcd_to_7seg h3_1(.bcd(h3[7:4]),   .seg(h3_s1)); bcd_to_7seg h3_0(.bcd(h3[3:0]),   .seg(h3_s0));
    wire draw_h3_all, dh3_3, dh3_2, dh3_1, dh3_0;
    vga_osd_digit oh3_3(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd290), .y(10'd230), .seg(h3_s3), .draw(dh3_3));
    vga_osd_digit oh3_2(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd310), .y(10'd230), .seg(h3_s2), .draw(dh3_2));
    vga_osd_digit oh3_1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd330), .y(10'd230), .seg(h3_s1), .draw(dh3_1));
    vga_osd_digit oh3_0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd350), .y(10'd230), .seg(h3_s0), .draw(dh3_0));
    assign draw_h3_all = (current_state == STATE_GAMEOVER) && (dh3_3 | dh3_2 | dh3_1 | dh3_0);

    wire is_player = inside_player; wire is_item = inside_item; wire is_ground = (v_cnt >= 10'd432);
    wire player_blink_visible = (hurt_timer == 0) || hurt_timer[2];

    // =========================================================
    //  6. 畫面色彩渲染
    // =========================================================
    always @(posedge VGA_CLK or negedge reset_n) begin
        if(!reset_n) {VGA_R, VGA_G, VGA_B} <= 24'h000000;
        else if (!video_on) {VGA_R, VGA_G, VGA_B} <= 24'h000000; 
        else begin
            if (draw_press_vga)          {VGA_R, VGA_G, VGA_B} <= 24'h00FFFF; 
            else if (draw_end_text)      {VGA_R, VGA_G, VGA_B} <= 24'hFF0000; 
            else if (draw_h1_all)        {VGA_R, VGA_G, VGA_B} <= 24'hFFFF00; 
            else if (draw_h2_all)        {VGA_R, VGA_G, VGA_B} <= 24'hFFFFFF; 
            else if (draw_h3_all)        {VGA_R, VGA_G, VGA_B} <= 24'hFF8C00; 
            else if (is_start_box)       {VGA_R, VGA_G, VGA_B} <= 24'h000000; 
            else if (is_end_box)         {VGA_R, VGA_G, VGA_B} <= 24'h000000; 
            else if (draw_hp_all)        {VGA_R, VGA_G, VGA_B} <= 24'hFF0000;
            else if (draw_level_all)     {VGA_R, VGA_G, VGA_B} <= 24'h00FFFF; 
            else if (draw_score_all)     {VGA_R, VGA_G, VGA_B} <= 24'hFFFFFF; 
            else if (draw_time_all) begin
                if (t1 == 0 && t0 <= 9)  {VGA_R, VGA_G, VGA_B} <= 24'hFF0000;
                else                     {VGA_R, VGA_G, VGA_B} <= 24'hFFFF00;
            end
            else if (is_player) begin
                if (game_over) begin
                    {VGA_R, VGA_G, VGA_B} <= 24'h555555; 
                end else if (player_blink_visible) begin
                    if (rom_q_player != 12'hF0F) begin
                        {VGA_R, VGA_G, VGA_B} <= {rom_q_player[11:8], 4'h0, rom_q_player[7:4], 4'h0, rom_q_player[3:0], 4'h0};
                    end else begin
                        {VGA_R, VGA_G, VGA_B} <= is_ground ? 24'h228B22 : 24'h0A0A2A; 
                    end
                end else begin
                    {VGA_R, VGA_G, VGA_B} <= is_ground ? 24'h228B22 : 24'h0A0A2A; 
                end
            end
            else if (is_item) begin
                if (current_rom_q != 12'hF0F) begin
                    {VGA_R, VGA_G, VGA_B} <= {current_rom_q[11:8], 4'h0, current_rom_q[7:4], 4'h0, current_rom_q[3:0], 4'h0};
                end else begin
                    {VGA_R, VGA_G, VGA_B} <= is_ground ? 24'h228B22 : 24'h0A0A2A; 
                end
            end
            else if (is_ground)          {VGA_R, VGA_G, VGA_B} <= 24'h228B22; 
            else                         {VGA_R, VGA_G, VGA_B} <= 24'h0A0A2A; 
        end
    end
endmodule