module tlb_entry
#(
    parameter TLBNUM = 8
)
(
    input        clk,
    // search port 0
    input                       s0_fetch    ,
    input  [18:0]               s0_vppn     ,
    input                       s0_odd_page ,
    input  [ 9:0]               s0_asid     ,
    output                      s0_found    ,
    output [$clog2(TLBNUM)-1:0] s0_index    ,
    output [ 5:0]               s0_ps       ,
    output [19:0]               s0_ppn      ,
    output                      s0_v        ,
    output                      s0_d        ,
    output [ 1:0]               s0_mat      ,
    output [ 1:0]               s0_plv      ,
    //search port 1
    input                       s1_fetch    ,
    input  [18:0]               s1_vppn     ,
    input                       s1_odd_page ,
    input  [ 9:0]               s1_asid     ,
    output                      s1_found    ,
    output [$clog2(TLBNUM)-1:0] s1_index    ,
    output [ 5:0]               s1_ps       ,
    output [19:0]               s1_ppn      ,
    output                      s1_v        ,
    output                      s1_d        ,
    output [ 1:0]               s1_mat      ,
    output [ 1:0]               s1_plv      ,
    // write port 
    input                       we          ,
    input  [$clog2(TLBNUM)-1:0] w_index     ,
    input  [18:0]               w_vppn      ,
    input  [ 9:0]               w_asid      ,
    input                       w_g         ,
    input  [ 5:0]               w_ps        ,
    input                       w_e         ,
    input                       w_v0        ,
    input                       w_d0        ,
    input  [ 1:0]               w_mat0      ,
    input  [ 1:0]               w_plv0      ,
    input  [19:0]               w_ppn0      ,
    input                       w_v1        ,
    input                       w_d1        ,
    input  [ 1:0]               w_mat1      ,
    input  [ 1:0]               w_plv1      ,
    input  [19:0]               w_ppn1      ,
    // read port
    input  [$clog2(TLBNUM)-1:0] r_index     ,
    output [18:0]               r_vppn      ,
    output [ 9:0]               r_asid      ,
    output                      r_g         ,
    output [ 5:0]               r_ps        ,
    output                      r_e         ,
    output                      r_v0        ,
    output                      r_d0        ,
    output [ 1:0]               r_mat0      ,
    output [ 1:0]               r_plv0      ,
    output [19:0]               r_ppn0      ,
    output                      r_v1        ,
    output                      r_d1        ,
    output [ 1:0]               r_mat1      ,
    output [ 1:0]               r_plv1      ,
    output [19:0]               r_ppn1      ,
    // invalid port 
    input                       inv_en      ,
    input  [ 4:0]               inv_op      ,
    input  [ 9:0]               inv_asid    ,
    input  [18:0]               inv_vpn
);

reg [18:0] tlb_vppn     [TLBNUM-1:0];
reg        tlb_e        [TLBNUM-1:0];
reg [ 9:0] tlb_asid     [TLBNUM-1:0];
reg        tlb_g        [TLBNUM-1:0];
reg [ 5:0] tlb_ps       [TLBNUM-1:0];
reg [19:0] tlb_ppn0     [TLBNUM-1:0];
reg [ 1:0] tlb_plv0     [TLBNUM-1:0];
reg [ 1:0] tlb_mat0     [TLBNUM-1:0];
reg        tlb_d0       [TLBNUM-1:0];
reg        tlb_v0       [TLBNUM-1:0];
reg [19:0] tlb_ppn1     [TLBNUM-1:0];
reg [ 1:0] tlb_plv1     [TLBNUM-1:0];
reg [ 1:0] tlb_mat1     [TLBNUM-1:0];
reg        tlb_d1       [TLBNUM-1:0];
reg        tlb_v1       [TLBNUM-1:0];

reg [TLBNUM-1:0] match0;
reg [TLBNUM-1:0] match1;

reg [TLBNUM-1:0] s0_odd_page_buffer;
reg [TLBNUM-1:0] s1_odd_page_buffer;

genvar i;
generate
    for (i = 0; i < TLBNUM; i = i + 1)
        begin: match
            always @(posedge clk) begin
                if (s0_fetch) begin
                    s0_odd_page_buffer[i] <= (tlb_ps[i] == 6'd12) ? s0_odd_page : s0_vppn[8];
                    match0[i] <= (tlb_e[i] == 1'b1) && ((tlb_ps[i] == 6'd12) ? s0_vppn == tlb_vppn[i] : s0_vppn[18: 9] == tlb_vppn[i][18: 9]) && ((s0_asid == tlb_asid[i]) || tlb_g[i]);
                end
                if (s1_fetch) begin
                    s1_odd_page_buffer[i] <= (tlb_ps[i] == 6'd12) ? s1_odd_page : s1_vppn[8];
                    match1[i] <= (tlb_e[i] == 1'b1) && ((tlb_ps[i] == 6'd12) ? s1_vppn == tlb_vppn[i] : s1_vppn[18: 9] == tlb_vppn[i][18: 9]) && ((s1_asid == tlb_asid[i]) || tlb_g[i]);
                end
            end
        end
endgenerate

assign s0_found = !(!match0);
assign s1_found = !(!match1);

assign {s0_index, s0_ps, s0_ppn, s0_v, s0_d, s0_mat, s0_plv} = {35{match0[0] & s0_odd_page_buffer[0] }} & {3'd0, tlb_ps[0], tlb_ppn1[0], tlb_v1[0], tlb_d1[0], tlb_mat1[0], tlb_plv1[0]} |
                                                               {35{match0[1] & s0_odd_page_buffer[1] }} & {3'd1, tlb_ps[1], tlb_ppn1[1], tlb_v1[1], tlb_d1[1], tlb_mat1[1], tlb_plv1[1]} |
                                                               {35{match0[2] & s0_odd_page_buffer[2] }} & {3'd2, tlb_ps[2], tlb_ppn1[2], tlb_v1[2], tlb_d1[2], tlb_mat1[2], tlb_plv1[2]} |
                                                               {35{match0[3] & s0_odd_page_buffer[3] }} & {3'd3, tlb_ps[3], tlb_ppn1[3], tlb_v1[3], tlb_d1[3], tlb_mat1[3], tlb_plv1[3]} |
                                                               {35{match0[4] & s0_odd_page_buffer[4] }} & {3'd4, tlb_ps[4], tlb_ppn1[4], tlb_v1[4], tlb_d1[4], tlb_mat1[4], tlb_plv1[4]} |
                                                               {35{match0[5] & s0_odd_page_buffer[5] }} & {3'd5, tlb_ps[5], tlb_ppn1[5], tlb_v1[5], tlb_d1[5], tlb_mat1[5], tlb_plv1[5]} |
                                                               {35{match0[6] & s0_odd_page_buffer[6] }} & {3'd6, tlb_ps[6], tlb_ppn1[6], tlb_v1[6], tlb_d1[6], tlb_mat1[6], tlb_plv1[6]} |
                                                               {35{match0[7] & s0_odd_page_buffer[7] }} & {3'd7, tlb_ps[7], tlb_ppn1[7], tlb_v1[7], tlb_d1[7], tlb_mat1[7], tlb_plv1[7]} ;

assign {s1_index, s1_ps, s1_ppn, s1_v, s1_d, s1_mat, s1_plv} = {35{match1[0] & s1_odd_page_buffer[0] }} & {3'd0, tlb_ps[0], tlb_ppn1[0], tlb_v1[0], tlb_d1[0], tlb_mat1[0], tlb_plv1[0]} |
                                                               {35{match1[1] & s1_odd_page_buffer[1] }} & {3'd1, tlb_ps[1], tlb_ppn1[1], tlb_v1[1], tlb_d1[1], tlb_mat1[1], tlb_plv1[1]} |
                                                               {35{match1[2] & s1_odd_page_buffer[2] }} & {3'd2, tlb_ps[2], tlb_ppn1[2], tlb_v1[2], tlb_d1[2], tlb_mat1[2], tlb_plv1[2]} |
                                                               {35{match1[3] & s1_odd_page_buffer[3] }} & {3'd3, tlb_ps[3], tlb_ppn1[3], tlb_v1[3], tlb_d1[3], tlb_mat1[3], tlb_plv1[3]} |
                                                               {35{match1[4] & s1_odd_page_buffer[4] }} & {3'd4, tlb_ps[4], tlb_ppn1[4], tlb_v1[4], tlb_d1[4], tlb_mat1[4], tlb_plv1[4]} |
                                                               {35{match1[5] & s1_odd_page_buffer[5] }} & {3'd5, tlb_ps[5], tlb_ppn1[5], tlb_v1[5], tlb_d1[5], tlb_mat1[5], tlb_plv1[5]} |
                                                               {35{match1[6] & s1_odd_page_buffer[6] }} & {3'd6, tlb_ps[6], tlb_ppn1[6], tlb_v1[6], tlb_d1[6], tlb_mat1[6], tlb_plv1[6]} |
                                                               {35{match1[7] & s1_odd_page_buffer[7] }} & {3'd7, tlb_ps[7], tlb_ppn1[7], tlb_v1[7], tlb_d1[7], tlb_mat1[7], tlb_plv1[7]} |
                                                               {35{match1[0] & ~s1_odd_page_buffer[0] }} & {3'd0, tlb_ps[0], tlb_ppn0[0], tlb_v0[0], tlb_d0[0], tlb_mat0[0], tlb_plv0[0]} |
                                                               {35{match1[1] & ~s1_odd_page_buffer[1] }} & {3'd1, tlb_ps[1], tlb_ppn0[1], tlb_v0[1], tlb_d0[1], tlb_mat0[1], tlb_plv0[1]} |
                                                               {35{match1[2] & ~s1_odd_page_buffer[2] }} & {3'd2, tlb_ps[2], tlb_ppn0[2], tlb_v0[2], tlb_d0[2], tlb_mat0[2], tlb_plv0[2]} |
                                                               {35{match1[3] & ~s1_odd_page_buffer[3] }} & {3'd3, tlb_ps[3], tlb_ppn0[3], tlb_v0[3], tlb_d0[3], tlb_mat0[3], tlb_plv0[3]} |
                                                               {35{match1[4] & ~s1_odd_page_buffer[4] }} & {3'd4, tlb_ps[4], tlb_ppn0[4], tlb_v0[4], tlb_d0[4], tlb_mat0[4], tlb_plv0[4]} |
                                                               {35{match1[5] & ~s1_odd_page_buffer[5] }} & {3'd5, tlb_ps[5], tlb_ppn0[5], tlb_v0[5], tlb_d0[5], tlb_mat0[5], tlb_plv0[5]} |
                                                               {35{match1[6] & ~s1_odd_page_buffer[6] }} & {3'd6, tlb_ps[6], tlb_ppn0[6], tlb_v0[6], tlb_d0[6], tlb_mat0[6], tlb_plv0[6]} |
                                                               {35{match1[7] & ~s1_odd_page_buffer[7] }} & {3'd7, tlb_ps[7], tlb_ppn0[7], tlb_v0[7], tlb_d0[7], tlb_mat0[7], tlb_plv0[7]} ;

always @(posedge clk) begin
    if (we) begin
        tlb_vppn [w_index] <= w_vppn;
        tlb_asid [w_index] <= w_asid;
        tlb_g    [w_index] <= w_g; 
        tlb_ps   [w_index] <= w_ps;  
        tlb_ppn0 [w_index] <= w_ppn0;
        tlb_plv0 [w_index] <= w_plv0;
        tlb_mat0 [w_index] <= w_mat0;
        tlb_d0   [w_index] <= w_d0;
        tlb_v0   [w_index] <= w_v0; 
        tlb_ppn1 [w_index] <= w_ppn1;
        tlb_plv1 [w_index] <= w_plv1;
        tlb_mat1 [w_index] <= w_mat1;
        tlb_d1   [w_index] <= w_d1;
        tlb_v1   [w_index] <= w_v1; 
    end
end

assign r_vppn  =  tlb_vppn [r_index]; 
assign r_asid  =  tlb_asid [r_index]; 
assign r_g     =  tlb_g    [r_index]; 
assign r_ps    =  tlb_ps   [r_index]; 
assign r_e     =  tlb_e    [r_index]; 
assign r_v0    =  tlb_v0   [r_index]; 
assign r_d0    =  tlb_d0   [r_index]; 
assign r_mat0  =  tlb_mat0 [r_index]; 
assign r_plv0  =  tlb_plv0 [r_index]; 
assign r_ppn0  =  tlb_ppn0 [r_index]; 
assign r_v1    =  tlb_v1   [r_index]; 
assign r_d1    =  tlb_d1   [r_index]; 
assign r_mat1  =  tlb_mat1 [r_index]; 
assign r_plv1  =  tlb_plv1 [r_index]; 
assign r_ppn1  =  tlb_ppn1 [r_index]; 

//tlb entry invalid 
generate 
    for (i = 0; i < TLBNUM; i = i + 1) 
        begin: invalid_tlb_entry 
            always @(posedge clk) begin
                if (we && (w_index == i)) begin
                    tlb_e[i] <= w_e;
                end
                else if (inv_en) begin
                    if (inv_op == 5'd0 || inv_op == 5'd1) begin
                        tlb_e[i] <= 1'b0;
                    end
                    else if (inv_op == 5'd2) begin
                        if (tlb_g[i]) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd3) begin
                        if (!tlb_g[i]) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd4) begin
                        if (!tlb_g[i] && (tlb_asid[i] == inv_asid)) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd5) begin
                        if (!tlb_g[i] && (tlb_asid[i] == inv_asid) && 
                           ((tlb_ps[i] == 6'd12) ? (tlb_vppn[i] == inv_vpn) : (tlb_vppn[i][18:10] == inv_vpn[18:10]))) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                    else if (inv_op == 5'd6) begin
                        if ((tlb_g[i] || (tlb_asid[i] == inv_asid)) && 
                           ((tlb_ps[i] == 6'd12) ? (tlb_vppn[i] == inv_vpn) : (tlb_vppn[i][18:10] == inv_vpn[18:10]))) begin
                            tlb_e[i] <= 1'b0;
                        end
                    end
                end
            end
        end 
endgenerate

endmodule
