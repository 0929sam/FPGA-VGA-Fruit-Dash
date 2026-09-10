module player_ctrl(
    input        clk,           
    input        rst_n,         
    input        frame_pulse,   
    input        key_left,      // KEY1
    input        key_right,     // KEY0
    input        key_jump,      // KEY3
    input        key_dash,      // KEY2 【新增衝刺控制端】
    
    output reg [9:0] player_x,  
    output reg [9:0] player_y   
);

    parameter GROUND_Y   = 10'd400; 
    parameter PLAYER_W   = 10'd32;  
    parameter MOVE_SPEED = 10'd5;   
    parameter DASH_DIST  = 10'd40;  // 【新增】衝刺距離：40像素 (剛好半條軌道間距)
    
    reg is_jumping;
    reg signed [10:0] y_vel;    
    
    // --- 衝刺按鍵下沿偵測與鎖存器 ---
    reg dash_d0, dash_d1;
    reg dash_req;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dash_d0  <= 1'b1;
            dash_d1  <= 1'b1;
            dash_req <= 1'b0;
        end else begin
            dash_d0 <= key_dash;
            dash_d1 <= dash_d0;
            if (dash_d1 && !dash_d0) // 按下 KEY2 的瞬間
                dash_req <= 1'b1;
            else if (frame_pulse)    // 每個物理幀處理完後自動清除請求
                dash_req <= 1'b0;
        end
    end
    
    // --- 物理引擎更新 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x   <= 10'd304; 
            player_y   <= GROUND_Y;
            is_jumping <= 1'b0;
            y_vel      <= 11'd0;
        end 
        else if (frame_pulse) begin
            
            // 1. 優先處理 KEY2 瞬間位移邏輯
            if (dash_req) begin
                if (!key_right) begin // 向右走 (!KEY0) 的同時按下 KEY2
                    if (player_x + PLAYER_W + DASH_DIST < 10'd640)
                        player_x <= player_x + DASH_DIST;
                    else
                        player_x <= 10'd640 - PLAYER_W; // 右邊界保護
                end
                else if (!key_left) begin // 向左走 (!KEY1) 的同時按下 KEY2
                    if (player_x > DASH_DIST)
                        player_x <= player_x - DASH_DIST;
                    else
                        player_x <= 10'd0; // 左邊界保護
                end
            end 
            
            // 2. 常規左右移動邏輯 (沒按衝刺時才執行)
            else begin
                if (!key_left && (player_x > MOVE_SPEED)) 
                    player_x <= player_x - MOVE_SPEED;
                else if (!key_right && (player_x < (10'd640 - PLAYER_W - MOVE_SPEED))) 
                    player_x <= player_x + MOVE_SPEED;
            end

            // 3. 跳躍與重力 (保持不變)
            if (!is_jumping) begin
                if (!key_jump) begin
                    is_jumping <= 1'b1;
                    y_vel      <= -11'd15; 
                end
            end 
            else begin
                y_vel <= y_vel + 11'd1; 
                if ( ($signed({1'b0, player_y}) + y_vel) >= $signed({1'b0, GROUND_Y}) ) begin
                    player_y   <= GROUND_Y; 
                    is_jumping <= 1'b0;     
                    y_vel      <= 11'd0;    
                end else begin
                    player_y   <= $unsigned($signed({1'b0, player_y}) + y_vel); 
                end
            end
        end
    end
endmodule