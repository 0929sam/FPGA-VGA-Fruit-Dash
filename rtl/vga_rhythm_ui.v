module vga_rhythm_ui(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  h_cnt, v_cnt,
    input  wire        video_on,

    input  wire [9:0]  note_y0, note_y1, note_y2, note_y3,
    input  wire [3:0]  hit_effect, 
    input  wire [15:0] score,
    input  wire [15:0] combo, // 新增：接收 Combo

    output reg  [7:0]  vga_r, vga_g, vga_b
);

    parameter NOTE_W = 10'd60; parameter NOTE_H = 10'd20;
    parameter TRK0_X = 10'd160; parameter TRK1_X = 10'd266;
    parameter TRK2_X = 10'd373; parameter TRK3_X = 10'd480;
    parameter JUDGE_Y = 10'd400;

    // ==========================================
    // 畫出分數 (左上角)
    // ==========================================
    wire sc0_on, sc1_on, sc2_on;
    vga_draw_digit d_sc2(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd20), .y(10'd20), .digit(score[11:8]), .is_on(sc2_on));
    vga_draw_digit d_sc1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd50), .y(10'd20), .digit(score[7:4]),  .is_on(sc1_on));
    vga_draw_digit d_sc0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd80), .y(10'd20), .digit(score[3:0]),  .is_on(sc0_on));
    wire show_score = sc0_on | sc1_on | sc2_on;

    // ==========================================
    // 畫出 Combo (右上角)
    // ==========================================
    wire cb0_on, cb1_on;
    vga_draw_digit d_cb1(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd550), .y(10'd20), .digit(combo[7:4]), .is_on(cb1_on));
    vga_draw_digit d_cb0(.h_cnt(h_cnt), .v_cnt(v_cnt), .x(10'd580), .y(10'd20), .digit(combo[3:0]), .is_on(cb0_on));
    wire show_combo = cb0_on | cb1_on;

    // --- (原本的 hit_effect 倒數邏輯保留) ---
    reg [4:0] flash_cnt [3:0];
    wire frame_pulse = (h_cnt == 10'd799 && v_cnt == 10'd524);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flash_cnt[0] <= 0; flash_cnt[1] <= 0; flash_cnt[2] <= 0; flash_cnt[3] <= 0;
        end else begin
            if (hit_effect[0]) flash_cnt[0] <= 5'd10; else if (flash_cnt[0] > 0 && frame_pulse) flash_cnt[0] <= flash_cnt[0] - 1;
            if (hit_effect[1]) flash_cnt[1] <= 5'd10; else if (flash_cnt[1] > 0 && frame_pulse) flash_cnt[1] <= flash_cnt[1] - 1;
            if (hit_effect[2]) flash_cnt[2] <= 5'd10; else if (flash_cnt[2] > 0 && frame_pulse) flash_cnt[2] <= flash_cnt[2] - 1;
            if (hit_effect[3]) flash_cnt[3] <= 5'd10; else if (flash_cnt[3] > 0 && frame_pulse) flash_cnt[3] <= flash_cnt[3] - 1;
        end
    end

    wire is_flash0 = (flash_cnt[0] > 0) && (h_cnt >= TRK0_X-30) && (h_cnt <= TRK0_X+30) && (v_cnt >= 380) && (v_cnt <= 420);
    wire is_flash1 = (flash_cnt[1] > 0) && (h_cnt >= TRK1_X-30) && (h_cnt <= TRK1_X+30) && (v_cnt >= 380) && (v_cnt <= 420);
    wire is_flash2 = (flash_cnt[2] > 0) && (h_cnt >= TRK2_X-30) && (h_cnt <= TRK2_X+30) && (v_cnt >= 380) && (v_cnt <= 420);
    wire is_flash3 = (flash_cnt[3] > 0) && (h_cnt >= TRK3_X-30) && (h_cnt <= TRK3_X+30) && (v_cnt >= 380) && (v_cnt <= 420);

    // ==========================================
    // 圖形判定邏輯 (四種不同形狀)
    // ==========================================
    wire is_judge_line = (v_cnt >= JUDGE_Y - 2) && (v_cnt <= JUDGE_Y + 2);
    wire is_track_line = (h_cnt == 10'd106) || (h_cnt == 10'd213) || (h_cnt == 10'd320) || (h_cnt == 10'd426) || (h_cnt == 10'd533);

    // 軌道 0：紅色長方形 (寬 60, 高 20)
    wire is_note0 = (h_cnt >= TRK0_X - 30) && (h_cnt <= TRK0_X + 30) && 
                    (v_cnt >= note_y0) && (v_cnt <= note_y0 + 20);

    // 軌道 1：藍色菱形/圓形近似 (半徑 20)
    // 利用絕對值畫菱形：|dx| + |dy| <= R
    wire [10:0] dx1 = (h_cnt > TRK1_X) ? (h_cnt - TRK1_X) : (TRK1_X - h_cnt);
    wire [10:0] dy1 = (v_cnt > note_y1 + 15) ? (v_cnt - (note_y1 + 15)) : ((note_y1 + 15) - v_cnt);
    wire is_note1 = (dx1 + dy1 <= 10'd20) && (v_cnt >= note_y1); // 加了 y 界限避免菱形切到上面

    // 軌道 2：黃色三角形 (底 40, 高 30)
    // y 越大(越靠近底)，允許的 x 寬度越寬
    wire [10:0] dy2 = (v_cnt >= note_y2) ? (v_cnt - note_y2) : 0;
    wire is_note2 = (v_cnt >= note_y2) && (v_cnt <= note_y2 + 30) &&
                    (h_cnt >= TRK2_X - (dy2[10:1])) && // dy2/2
                    (h_cnt <= TRK2_X + (dy2[10:1]));

    // 軌道 3：紫色正方形 (寬 30, 高 30)
    wire is_note3 = (h_cnt >= TRK3_X - 15) && (h_cnt <= TRK3_X + 15) && 
                    (v_cnt >= note_y3) && (v_cnt <= note_y3 + 30);
    // ==========================================
    // 輸出顏色
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {vga_r, vga_g, vga_b} <= 24'h000000;
        else if (!video_on) {vga_r, vga_g, vga_b} <= 24'h000000;
        else begin
            if (show_score)      {vga_r, vga_g, vga_b} <= 24'hFFA500; // 橘色分數
            else if (show_combo) {vga_r, vga_g, vga_b} <= 24'h00FFFF; // 青色 Combo
            
            else if (is_flash0 || is_flash1 || is_flash2 || is_flash3) {vga_r, vga_g, vga_b} <= 24'hFFFFFF;

            else if (is_note0) {vga_r, vga_g, vga_b} <= 24'hFF0000;
            else if (is_note1) {vga_r, vga_g, vga_b} <= 24'h0000FF;
            else if (is_note2) {vga_r, vga_g, vga_b} <= 24'hFFFF00;
            else if (is_note3) {vga_r, vga_g, vga_b} <= 24'hFF00FF;
            
            else if (is_judge_line) {vga_r, vga_g, vga_b} <= 24'h00FF00;
            else if (is_track_line) {vga_r, vga_g, vga_b} <= 24'h333333;
            else {vga_r, vga_g, vga_b} <= 24'h000000;
        end
    end
endmodule