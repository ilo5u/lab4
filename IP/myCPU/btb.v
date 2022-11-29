module btb
#(
    parameter BTBNUM = 8
)
(
    input             clk           ,
    input             reset         ,
    //from/to if
    input  [31:0]     fetch_pc      ,
    input             fetch_en      ,
    output [31:0]     ret_pc        ,
    output            taken         ,
    output            ret_en        ,
    output [ 4:0]     ret_index     ,
    //from id
    input             operate_en    ,
    input  [31:0]     operate_pc    ,
    input  [ 4:0]     operate_index ,
    input             pop_ras       ,
    input             push_ras      ,
    input             add_entry     ,
    input             delete_entry  ,
    input             pre_error     ,
    input             pre_right     ,
    input             target_error  ,
    input             right_orien   ,
    input  [31:0]     right_target  
);

reg [29:0] pc      [BTBNUM-1:0];
reg [29:0] target  [BTBNUM-1:0];
reg [ 2:0] counter [BTBNUM-1:0];

reg [BTBNUM-1:0] jirl_flag;
reg [BTBNUM-1:0] valid    ;

reg [29:0] ras [7:0];
reg [ 2:0] ras_ptr;

reg [29:0] ras_buffer;

wire ras_full;
wire ras_empty;

reg [BTBNUM-1:0] match_rd;

wire [29:0] match_target;
wire [ 2:0] match_counter;
wire [$clog2(BTBNUM)-1:0] match_index;
wire        match_jirl_flag;

wire all_entry_valid;
wire [$clog2(BTBNUM)-1:0] select_one_invalid_entry;

wire [$clog2(BTBNUM)-1:0] add_entry_index;

assign add_entry_index = all_entry_valid ? fcsr[$clog2(BTBNUM)-1:0] : select_one_invalid_entry;

assign all_entry_valid = &valid;

assign select_one_invalid_entry = !valid[ 0] ? 3'd0  :
                                  !valid[ 1] ? 3'd1  :
                                  !valid[ 2] ? 3'd2  :
                                  !valid[ 3] ? 3'd3  :
                                  !valid[ 4] ? 3'd4  :
                                  !valid[ 5] ? 3'd5  :
                                  !valid[ 6] ? 3'd6  :
                                  !valid[ 7] ? 3'd7  : 3'h0; 

always @(posedge clk) begin
    if (reset) begin
        valid <= 8'b0;
    end
    else if (operate_en) begin
        if (add_entry) begin
            valid[add_entry_index]     <= 1'b1;
            pc[add_entry_index]        <= operate_pc[31:2];
            target[add_entry_index]    <= right_target[31:2];
            counter[add_entry_index]   <= 3'b100;
            jirl_flag[add_entry_index] <= pop_ras;
        end
        else if (delete_entry) begin
            valid[operate_index]       <= 1'b0;
            jirl_flag[add_entry_index] <= 1'b0;
        end
        else if (target_error && !pop_ras) begin
            target[operate_index]      <= right_target[31:2];
            counter[operate_index]     <= 3'b100;
            jirl_flag[add_entry_index] <= pop_ras;
        end
        else if (pre_error || pre_right) begin
            if (right_orien) begin
                if (counter[operate_index] != 3'b111) begin
                    counter[operate_index] <= counter[operate_index] + 3'b1;
                end
            end
            else begin
                if (counter[operate_index] != 3'b000) begin
                    counter[operate_index] <= counter[operate_index] - 3'b1;
                end
            end
        end
    end
    
end

genvar i;
generate 
    for (i = 0; i < BTBNUM; i = i + 1)
        begin: match
        always @(posedge clk) begin
            if (reset) begin
                match_rd[i] <= 1'b0;
            end
            else if (fetch_en) begin
                match_rd[i] <= (fetch_pc[31:2] == pc[i]) && valid[i] && !(jirl_flag[i] && ras_empty);
            end
        end
        end
endgenerate

always @(posedge clk) begin
    if (fetch_en) begin
        ras_buffer <= ras[ras_ptr - 3'b1]; //ras modify may before inst fetch
    end
end

assign {match_target, match_counter, match_index, match_jirl_flag} = {37{match_rd[0 ]}} & {target[0 ], counter[0 ], 3'd0 , jirl_flag[0 ]} |
                                                                     {37{match_rd[1 ]}} & {target[1 ], counter[1 ], 3'd1 , jirl_flag[1 ]} |
                                                                     {37{match_rd[2 ]}} & {target[2 ], counter[2 ], 3'd2 , jirl_flag[2 ]} |
                                                                     {37{match_rd[3 ]}} & {target[3 ], counter[3 ], 3'd3 , jirl_flag[3 ]} |
                                                                     {37{match_rd[4 ]}} & {target[4 ], counter[4 ], 3'd4 , jirl_flag[4 ]} |
                                                                     {37{match_rd[5 ]}} & {target[5 ], counter[5 ], 3'd5 , jirl_flag[5 ]} |
                                                                     {37{match_rd[6 ]}} & {target[6 ], counter[6 ], 3'd6 , jirl_flag[6 ]} |
                                                                     {37{match_rd[7 ]}} & {target[7 ], counter[7 ], 3'd7 , jirl_flag[7 ]};

assign ret_pc = match_jirl_flag ? {ras_buffer, 2'b0} : {match_target, 2'b0};
assign ret_en = |match_rd;
assign taken  = match_counter[2];
assign ret_index = match_index;

assign ras_full  = (ras_ptr == 3'd7);
assign ras_empty = (ras_ptr == 3'd0);

always @(posedge clk) begin
    if (reset) begin
        ras_ptr <= 3'b0;
    end
    else if (operate_en) begin
        if (push_ras && !ras_full) begin
            ras[ras_ptr] <= operate_pc[31:2] + 30'b1;
            ras_ptr <= ras_ptr + 3'b1;
        end
        else if (pop_ras && !ras_empty) begin
            ras_ptr <= ras_ptr - 3'b1;
        end
    end
end

reg [5:0] fcsr;

always @(posedge clk) begin
    if (reset) begin
        fcsr <= 6'b100010;
    end
    else begin
        fcsr[0] <= fcsr[5];
        fcsr[1] <= fcsr[0];
        fcsr[2] <= fcsr[1];
        fcsr[3] <= fcsr[2] ^ fcsr[5];
        fcsr[4] <= fcsr[3] ^ fcsr[5];
        fcsr[5] <= fcsr[4];
    end
end

endmodule
