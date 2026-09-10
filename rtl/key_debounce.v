module key_debounce (
    input  wire clk,      // 系統時脈 (25.175MHz)
    input  wire rst_n,
    input  wire key_in,   // 原始按鍵輸入 (Active Low)
    output reg  key_out   // 防彈跳後的輸出 (Active Low，保持按鍵習慣)
);

    // 25.175MHz 下，計數到約 500,000 大約是 20ms 的延遲 (足以消除彈跳)
    parameter DELAY_MAX = 20'd500_000;
    
    reg [19:0] delay_cnt;
    reg key_sync_0, key_sync_1;

    // 兩級同步器 (降低 Metastability)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync_0 <= 1'b1;
            key_sync_1 <= 1'b1;
        end else begin
            key_sync_0 <= key_in;
            key_sync_1 <= key_sync_0;
        end
    end

    // 計數器與狀態更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt <= 20'd0;
            key_out   <= 1'b1;
        end else begin
            // 如果輸入狀態跟目前輸出的狀態不一樣
            if (key_sync_1 != key_out) begin
                delay_cnt <= delay_cnt + 20'd1;
                // 如果狀態維持不一樣超過 20ms，就認定是有效按壓，更新輸出
                if (delay_cnt >= DELAY_MAX) begin
                    key_out <= key_sync_1;
                    delay_cnt <= 20'd0;
                end
            end else begin
                delay_cnt <= 20'd0; // 如果中途狀態又縮回去了(彈跳)，計數器歸零
            end
        end
    end
endmodule