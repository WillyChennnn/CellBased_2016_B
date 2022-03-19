`timescale 1ns/10ps
module CLE ( clk, reset, rom_q, rom_a, sram_q, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset;
input  [7:0]  rom_q;
output reg [6:0]  rom_a;
input  [7:0]  sram_q;
output reg [9:0]  sram_a;
output reg [7:0]  sram_d;
output reg        sram_wen;
output        finish;

parameter IDLE = 4'd0,
          LABEL = 4'd1,
          LABEL_DONE = 4'd2,
          SCAN_S1 = 4'd3,
          WRITE_S1 = 4'd4,
          S1_DONE = 4'd5,
          SCAN_S2 = 4'd6,
          WRITE_S2 = 4'd7,
          DONE = 4'd8;




reg [3:0] state, n_state;
reg [3:0] cnt, n_cnt;
reg [7:0] tmp_label;
reg [4:0] row, n_row;
reg [4:0] col, n_col;
reg [7:0] min, n_min;
wire [9:0] c_addr;
reg [9:0] sram_addr, bias;
wire [8:0] diff;
reg [7:0] record;
assign c_addr = {row,5'd0} + col;
assign finish = (state == DONE)?1'b1:1'b0;
assign diff = sram_q - min;

always@(posedge clk or posedge reset)begin
    if(reset)begin
        state <= IDLE; 
    end
    else begin
        state <= n_state;
    end
end
always@(*)begin
    case(state)
        IDLE:n_state = LABEL;
        LABEL:begin
            if(&sram_a)begin
                n_state = LABEL_DONE;
            end
            else begin
                n_state = state;
            end
        end
        LABEL_DONE: n_state = SCAN_S1;
        SCAN_S1:begin
            if(cnt == 4'd8)begin
                n_state = WRITE_S1;
            end
            else begin
                n_state = SCAN_S1;
            end
        end
        WRITE_S1:begin
            if(&sram_a)begin
                n_state = S1_DONE;
            end
            else if(cnt == 4'd7)begin
                n_state = SCAN_S1;
            end
            else begin
                n_state = state;
            end
        end
        S1_DONE: n_state = SCAN_S2;
        SCAN_S2:begin
            if(cnt == 4'd8)begin
                n_state = WRITE_S2;
            end
            else begin
                n_state = SCAN_S2;
            end
        end
        WRITE_S2:begin
            if(row == 5'd1 && col == 5'd30 && sram_a == 10'd95)begin
                n_state = DONE;
            end
            else if(cnt == 4'd7)begin
                n_state = SCAN_S2;
            end
            else begin
                n_state = state;
            end
        end
        DONE:begin
            n_state = DONE;
        end 
        default:n_state = IDLE;
    endcase
end

always@(posedge clk or posedge reset)begin
    if(reset)begin
        cnt <= 4'd8;
    end
    else if(state == IDLE)begin
        cnt <= 4'd8;
    end
    else begin
        cnt <= n_cnt;
    end
end
always@(*)begin
    if(state == LABEL)begin
        if(cnt == 4'd0)begin
            n_cnt = 4'd8;
        end
        else begin
            n_cnt = cnt - 4'd1;
        end
    end
    else if(state == LABEL_DONE)begin
        n_cnt = 4'd0;
    end
    else if(state == SCAN_S1 || state == SCAN_S2)begin
        if(cnt == 4'd8)begin
            n_cnt = 4'd0;
        end
        else begin
            n_cnt = cnt + 4'd1;
        end
    end
    else begin
        if(cnt == 4'd7)begin
            n_cnt = 4'd0;
        end
        else begin
            n_cnt = cnt + 4'd1;
        end 
    end    
end

always@(posedge clk or posedge reset)begin
    if(reset)begin
        tmp_label <= 8'd1;
    end
    else if(rom_q[cnt])begin
        tmp_label <= tmp_label + 8'd1;
    end
    else begin
    end
end

always@(posedge clk or posedge reset)begin
    if(reset)begin
        rom_a <= 7'd0;
    end
    else if(cnt == 4'd0)begin
        rom_a <= rom_a + 7'd1;
    end
end

// set row and column
always@(posedge clk or posedge reset)begin
    if(reset)begin
        row <= 5'd1;
        col <= 5'd1;
    end
    else begin
        row <= n_row;
        col <= n_col;
    end
end
always@(*)begin
    if(state == WRITE_S1 && cnt == 4'd7)begin
        // from left to right, top to down
        if(col == 5'd30)begin
            n_row = row + 5'd1;
            n_col = 5'd1;
        end
        else begin
            n_row = row;
            n_col = col + 5'd1;
        end
    end
    else if(state == S1_DONE)begin
        n_row = 5'd30;
        n_col = 5'd1;
    end
    else if(state == WRITE_S2 && cnt == 4'd7)begin
        // from left to right, down to top
        if(col == 5'd30)begin
            n_row = row - 5'd1;
            n_col = 5'd1;
        end
        else begin
            n_row = row;
            n_col = col + 5'd1;
        end
    end
    else begin
        n_row = row;
        n_col = col;
    end
end

// caculate sram addr
always@(*)begin
    if(cnt < 4'd4)begin
        sram_addr = c_addr - bias;
    end
    else begin
        sram_addr = c_addr + bias;
    end
end
always@(*)begin
    case(cnt)
        4'd0: bias = 10'd33;
        4'd1: bias = 10'd32;
        4'd2: bias = 10'd31;
        4'd3: bias = 10'd1;
        4'd4: bias = 10'd1;
        4'd5: bias = 10'd31;
        4'd6: bias = 10'd32;
        4'd7: bias = 10'd33;
        default: bias = 10'd0;
    endcase
end

always@(posedge clk or posedge reset)begin
    if(reset)begin
        record <= 8'd0;
    end
    else if(state == SCAN_S1 || state == SCAN_S2)begin
        if(~|sram_q)begin
            record[cnt-4'd1] <=1'b0;
        end
        else begin
            record[cnt-4'd1] <= 1'b1;
        end
    end
    else begin
    end
end

always@(posedge clk or posedge reset)begin
    if(reset)begin
        min <= 8'hFF;
    end
    else if(state == LABEL_DONE)begin
        min <= 8'hFF;
    end
    else begin
        min <= n_min;
    end
end
always@(*)begin
    if(state == WRITE_S1 && cnt == 4'd7)begin
        n_min = 8'hFF;
    end
    else if(state == WRITE_S2 && cnt == 4'd7)begin
        n_min = 8'hFF;
    end
    else if(state == SCAN_S1 || state == SCAN_S2)begin
        if(~|sram_q)begin
            n_min = min;
        end
        else if(diff[8])begin
            n_min = sram_q;
        end
        else begin
            n_min = min;
        end
    end
    else begin
        n_min = min;
    end
end

always@(*)begin
    case(state)
        LABEL:begin
            sram_wen = (cnt[3])?1'b1 :1'b0;
            sram_a = (cnt[3])?10'd0:{rom_a,3'd0} + 4'd7 - cnt;
            sram_d = (rom_q[cnt])? tmp_label : 8'd0;
        end
        SCAN_S1:begin
            sram_wen = 1'b1;
            sram_a = sram_addr;
            sram_d = 8'd0;
        end
        WRITE_S1:begin
            sram_wen = 1'b0;
            sram_a = sram_addr;
            sram_d = (record[cnt])? min:8'd0;
        end
        SCAN_S2:begin
            sram_wen = 1'b1;
            sram_a = sram_addr;
            sram_d = 8'd0;
        end
        WRITE_S2:begin
            sram_wen = 1'b0;
            sram_a = sram_addr;
            sram_d = (record[cnt])? min:8'd0;
        end
        default:begin
            sram_wen = 1'b1;
            sram_a = 10'd0;
            sram_d = 8'd0;
        end
    endcase
end


endmodule
