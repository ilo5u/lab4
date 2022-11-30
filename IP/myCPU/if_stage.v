`include "mycpu.h"
`include "csr.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    //exception
    input                          excp_flush       ,
    input                          ertn_flush       ,
    input                          refetch_flush    ,
    input                          icacop_flush     ,
    input  [31:0]                  ws_pc            ,
    input  [31:0]                  csr_eentry       ,
    input  [31:0]                  csr_era          ,
    input                          excp_tlbrefill   ,
    input  [31:0]                  csr_tlbrentry    ,
    input                          has_int          ,
    //idle
    input                          idle_flush       ,
    // inst cache interface
    output                         inst_valid        ,
    output                         inst_op           ,
    output [ 3:0]                  inst_wstrb        ,
    output [31:0]                  inst_wdata        ,
    input                          inst_addr_ok      ,
    input                          inst_data_ok      ,
    input                          icache_miss       ,
    input  [31:0]                  inst_rdata        ,
    output                         inst_uncache_en   ,
    output                         tlb_excp_cancel_req,
    //from csr
    input                          csr_pg            ,
    input                          csr_da            ,
    input  [31:0]                  csr_dmw0          ,
    input  [31:0]                  csr_dmw1          ,
    input  [ 1:0]                  csr_plv           ,
    input  [ 1:0]                  csr_datf          ,
    input                          disable_cache     ,
    //to btb
    output [31:0]                  fetch_pc          ,
    output                         fetch_en          ,
    input  [31:0]                  btb_ret_pc        ,
    input                          btb_taken         ,
    input                          btb_en            ,
    input  [ 4:0]                  btb_index         ,
    //to addr trans
    output [31:0]                  inst_addr         ,
    output                         inst_addr_trans_en,
    output                         dmw0_en           ,
    output                         dmw1_en           ,
    //tlb
    input                          inst_tlb_found    ,
    input                          inst_tlb_v        ,
    input                          inst_tlb_d        ,
    input  [ 1:0]                  inst_tlb_mat      ,
    input  [ 1:0]                  inst_tlb_plv      
);

reg          fs_valid;
wire         fs_ready_go;
wire         fs_allowin;
wire         to_fs_valid;
wire         pfs_ready_go;

wire [31:0]  seq_pc;
wire [31:0]  nextpc;
wire [31:0]  real_nextpc;

wire         pfs_excp_adef;
wire         fs_excp_tlbr;
wire         fs_excp_pif;
wire         fs_excp_ppi;
reg          fs_excp;
reg          fs_excp_num;
wire         excp;
wire [3:0]   excp_num;
wire         pfs_excp;
wire         pfs_excp_num;

wire         flush_sign;

wire         da_mode;

wire         btb_pre_error_flush;
wire [31:0]  btb_pre_error_flush_target;

wire         flush_inst_delay;
wire         flush_inst_go_dirt;

wire         fetch_btb_target;

reg          idle_lock;

wire         tlb_excp_lock_pc;

wire         fs_excp_adef;

assign {btb_pre_error_flush,
        btb_pre_error_flush_target  } = br_bus;

reg  switch_buff_valid;
reg  switch_ptr_his;
wire switch_ptr;
reg  [31:0]  sw_inst_rd_buff    ;
reg  [31:0]  sw_pc_rd_buff      ;
reg  [31:0]  sw_btb_ret_pc_buff ;
reg  [ 4:0]  sw_btb_index_buff  ;
reg          sw_btb_taken_buff  ;
reg          sw_btb_en_buff     ;
reg          sw_icache_miss_buff;
reg          sw_excp_buff       ;
reg  [ 3:0]  sw_excp_num_buff   ;
reg          sw_inst_buff_enable;

reg  [31:0]  inst_rd_buff    ;
reg  [31:0]  pc_rd_buff      ;
reg  [31:0]  btb_ret_pc_buff ;
reg  [ 4:0]  btb_index_buff  ;
reg          btb_taken_buff  ;
reg          btb_en_buff     ;
reg          icache_miss_buff;
reg          excp_buff       ;
reg  [ 3:0]  excp_num_buff   ;
reg          inst_buff_enable;

wire [31:0] btb_ret_pc_o;
wire [ 4:0] btb_index_o;
wire        btb_taken_o;
wire        btb_en_o;
wire        icache_miss_o;
wire        excp_o;
wire [ 3:0] excp_num_o;
wire [31:0] fs_inst_o;
wire [31:0] fs_pc_o;

assign btb_ret_pc_o  = (inst_buff_enable && !switch_ptr) ? btb_ret_pc_buff  : switch_buff_valid ? sw_btb_ret_pc_buff  :btb_ret_pc ;
assign btb_index_o   = (inst_buff_enable && !switch_ptr) ? btb_index_buff   : switch_buff_valid ? sw_btb_index_buff   :btb_index  ;
assign btb_taken_o   = (inst_buff_enable && !switch_ptr) ? btb_taken_buff   : switch_buff_valid ? sw_btb_taken_buff   :btb_taken  ;
assign btb_en_o      = (inst_buff_enable && !switch_ptr) ? btb_en_buff      : switch_buff_valid ? sw_btb_en_buff      :btb_en     ;
assign icache_miss_o = (inst_buff_enable && !switch_ptr) ? icache_miss_buff : switch_buff_valid ? sw_icache_miss_buff :icache_miss;
assign excp_o        = (inst_buff_enable && !switch_ptr) ? excp_buff        : switch_buff_valid ? sw_excp_buff        :excp       ;
assign excp_num_o    = (inst_buff_enable && !switch_ptr) ? excp_num_buff    : switch_buff_valid ? sw_excp_num_buff    :excp_num   ;
assign fs_inst_o     = (inst_buff_enable && !switch_ptr) ? inst_rd_buff     : switch_buff_valid ? sw_inst_rd_buff     :inst_rdata;
assign fs_pc_o       = (inst_buff_enable && !switch_ptr) ? pc_rd_buff       : switch_buff_valid ? sw_pc_rd_buff       :fs_pc;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {btb_ret_pc_o,      //108:77
                       btb_index_o,       //76:72
                       btb_taken_o,       //71:71
                       btb_en_o,          //70:70
                       icache_miss_o,     //69:69
                       excp_o,            //68:68
                       excp_num_o,        //67:64
                       fs_inst_o,         //63:32
                       fs_pc_o            //31:0
                      };

assign flush_sign = ertn_flush || excp_flush || refetch_flush || icacop_flush || idle_flush;

assign flush_inst_delay = flush_sign && !inst_addr_ok || idle_flush;
assign flush_inst_go_dirt = flush_sign && inst_addr_ok && !idle_flush;

//flush state machine
reg [31:0] flush_inst_req_buffer;
reg        flush_inst_req_state;
localparam flush_inst_req_empty = 1'b0;
localparam flush_inst_req_full  = 1'b1;

always @(posedge clk) begin
    if (reset) begin
        flush_inst_req_state <= flush_inst_req_empty;
    end 
    else case (flush_inst_req_state)
        flush_inst_req_empty: begin
            if(flush_inst_delay) begin
                flush_inst_req_buffer <= nextpc;
                flush_inst_req_state  <= flush_inst_req_full;
            end
        end
        flush_inst_req_full: begin
            if(pfs_ready_go) begin
                flush_inst_req_state  <= flush_inst_req_empty;
            end
            else if (flush_sign) begin
                flush_inst_req_buffer <= nextpc;
            end
        end
    endcase
end

assign fetch_btb_target = btb_taken && btb_en;

always @(posedge clk) begin
    if (reset) begin
        idle_lock <= 1'b0;
    end
    else if (idle_flush && !has_int) begin
        idle_lock <= 1'b1;
    end
    else if (has_int) begin
        idle_lock <= 1'b0;
    end
end

//br state machine
reg [31:0] br_target_inst_req_buffer;
reg [ 2:0] br_target_inst_req_state;
localparam br_target_inst_req_empty = 3'b001;
localparam br_target_inst_req_wait_slot = 3'b010;
localparam br_target_inst_req_wait_br_target = 3'b100;

always @(posedge clk) begin
    if (reset) begin
        br_target_inst_req_state <= br_target_inst_req_empty;
    end
    else case (br_target_inst_req_state) 
        br_target_inst_req_empty: begin
            if (flush_sign) begin
                br_target_inst_req_state <= br_target_inst_req_empty; 
            end
            // else if(btb_pre_error_flush && !fs_valid && !inst_addr_ok) begin
            //     br_target_inst_req_state  <= br_target_inst_req_wait_slot;
            //     br_target_inst_req_buffer <= btb_pre_error_flush_target;
            // end
            // else if(btb_pre_error_flush && !inst_addr_ok && fs_valid || btb_pre_error_flush && inst_addr_ok && !fs_valid) begin
            //     br_target_inst_req_state  <= br_target_inst_req_wait_br_target;
            //     br_target_inst_req_buffer <= btb_pre_error_flush_target;
            // end
            else if(btb_pre_error_flush && !inst_addr_ok && fs_valid || btb_pre_error_flush && !fs_valid && !inst_addr_ok) begin
                br_target_inst_req_state  <= br_target_inst_req_wait_br_target;
                br_target_inst_req_buffer <= btb_pre_error_flush_target;
            end
        end
        br_target_inst_req_wait_slot: begin
            if(flush_sign) begin
                br_target_inst_req_state <= br_target_inst_req_empty;
            end
            else if(pfs_ready_go) begin
                br_target_inst_req_state <= br_target_inst_req_wait_br_target;
            end
        end
        br_target_inst_req_wait_br_target: begin
            if(pfs_ready_go || flush_sign) begin
                br_target_inst_req_state <= br_target_inst_req_empty;
            end
        end
        default: begin
            br_target_inst_req_state <= br_target_inst_req_empty;
        end
    endcase
end

// pre-IF stage
assign pfs_ready_go = (inst_valid || pfs_excp) && inst_addr_ok;
assign to_fs_valid  = ~reset && pfs_ready_go;
assign seq_pc       = fs_pc + 32'h4;
assign nextpc       = (excp_flush && !excp_tlbrefill)               ? csr_eentry                 :
                      (excp_flush && excp_tlbrefill)                ? csr_tlbrentry              :
                      ertn_flush                                    ? csr_era                    :
                      (refetch_flush || icacop_flush || idle_flush) ? (ws_pc + 32'h4)            :
                      btb_pre_error_flush                           ? btb_pre_error_flush_target :
                      fetch_btb_target                              ? btb_ret_pc                 :
                                                                      seq_pc;                                                   

assign real_nextpc = (flush_inst_req_state == flush_inst_req_full)                                  ? flush_inst_req_buffer     :
                     (br_target_inst_req_state == br_target_inst_req_wait_br_target) && !flush_sign ? br_target_inst_req_buffer : nextpc;

assign tlb_excp_lock_pc = tlb_excp_cancel_req && br_target_inst_req_state != br_target_inst_req_wait_br_target && flush_inst_req_state != flush_inst_req_full;

//when flush_sign meet icache_busy 1, flush_sign's inst valid should not set immediately
wire fetch_stop = switch_buff_valid && inst_buff_enable || inst_buff_enable && inst_data_ok || switch_buff_valid && inst_data_ok;
assign inst_valid = (!fetch_stop && !pfs_excp && !tlb_excp_lock_pc || flush_sign || btb_pre_error_flush) && !(idle_flush || idle_lock);
assign inst_op     = 1'b0;
assign inst_wstrb  = 4'h0;
assign inst_addr   = real_nextpc; //nextpc
assign inst_wdata  = 32'b0;

//inst read buffer  use for stall situation
always @(posedge clk) begin
    if (reset || (fs_ready_go && ds_allowin && !switch_ptr) || flush_sign || btb_pre_error_flush) begin
        inst_rd_buff <= 32'b0;
        inst_buff_enable  <= 1'b0;
    end
    else if (inst_data_ok && !(ds_allowin && !switch_ptr) && !inst_buff_enable) begin
        inst_rd_buff     <= inst_rdata;
        pc_rd_buff       <= fs_pc;
        btb_ret_pc_buff  <= btb_ret_pc;
        btb_index_buff   <= btb_index;
        btb_taken_buff   <= btb_taken;
        btb_en_buff      <= btb_en;
        icache_miss_buff <= icache_miss;
        excp_buff        <= excp;
        excp_num_buff    <= excp_num;

        inst_buff_enable  <= 1'b1;
    end
end

always @(posedge clk) begin
    if (reset || (fs_ready_go && ds_allowin && switch_ptr) || flush_sign || btb_pre_error_flush) begin
        switch_buff_valid <= 1'b0;
    end
    else if (inst_data_ok && inst_buff_enable) begin
        sw_inst_rd_buff     <= inst_rdata;
        sw_pc_rd_buff       <= fs_pc;
        sw_btb_ret_pc_buff  <= btb_ret_pc;
        sw_btb_index_buff   <= btb_index;
        sw_btb_taken_buff   <= btb_taken;
        sw_btb_en_buff      <= btb_en;
        sw_icache_miss_buff <= icache_miss;
        sw_excp_buff        <= excp;
        sw_excp_num_buff    <= excp_num;

        switch_buff_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if (reset || flush_sign || btb_pre_error_flush || (fs_ready_go && ds_allowin)) begin
        switch_ptr_his <= 1'b0;
    end
    else if (!inst_buff_enable && switch_buff_valid) begin
        switch_ptr_his <= 1'b1;
    end
end

assign switch_ptr = !inst_buff_enable && switch_buff_valid || switch_ptr_his;

//exception
assign pfs_excp_adef = (real_nextpc[0] || real_nextpc[1]); //user can only access low half address space, trigger only in tlb trans
assign fs_excp_adef  = fs_pc[31] && (csr_plv == 2'd3) && inst_addr_trans_en;
//tlb 
assign fs_excp_tlbr = !inst_tlb_found && inst_addr_trans_en;
assign fs_excp_pif  = !inst_tlb_v && inst_addr_trans_en;
assign fs_excp_ppi  = (csr_plv > inst_tlb_plv) && inst_addr_trans_en;

assign tlb_excp_cancel_req = fs_excp_tlbr || fs_excp_pif || fs_excp_ppi;

assign pfs_excp = pfs_excp_adef;
assign pfs_excp_num = {pfs_excp_adef};

assign excp = fs_excp || fs_excp_tlbr || fs_excp_pif || fs_excp_ppi || fs_excp_adef;
assign excp_num = {fs_excp_ppi, fs_excp_pif, fs_excp_tlbr, fs_excp_num || fs_excp_adef};

//addr trans
assign inst_addr_trans_en = csr_pg && !csr_da && !dmw0_en && !dmw1_en;

//addr dmw trans  //TOT
assign dmw0_en = ((csr_dmw0[`PLV0] && csr_plv == 2'd0) || (csr_dmw0[`PLV3] && csr_plv == 2'd3)) && (fs_pc[31:29] == csr_dmw0[`VSEG]);
assign dmw1_en = ((csr_dmw1[`PLV0] && csr_plv == 2'd0) || (csr_dmw1[`PLV3] && csr_plv == 2'd3)) && (fs_pc[31:29] == csr_dmw1[`VSEG]);

//uncache judgement
assign da_mode = csr_da && !csr_pg;

assign inst_uncache_en = (da_mode && (csr_datf == 2'b0))                 ||
                         (dmw0_en && (csr_dmw0[`DMW_MAT] == 2'b0))       ||
                         (dmw1_en && (csr_dmw1[`DMW_MAT] == 2'b0))       ||
                         (inst_addr_trans_en && (inst_tlb_mat == 2'b0))  ||
                         disable_cache;

//assign inst_uncache_en = 1'b1; //used for debug

// IF stage
assign fs_ready_go    = inst_data_ok || inst_buff_enable || excp;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset || flush_inst_delay /*|| btb_pre_error_flush*/) begin
        fs_valid <= 1'b0;
    end
    else if (to_fs_valid) begin
        fs_valid <= to_fs_valid;
    end
    else if (btb_pre_error_flush) begin
        fs_valid <= inst_addr_ok;
    end

    if (reset) begin
        fs_pc        <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
        fs_excp      <= 1'b0;
        fs_excp_num  <= 4'b0;
    end
    else if (to_fs_valid && (!fetch_stop || flush_inst_go_dirt || btb_pre_error_flush && inst_addr_ok)) begin
        fs_pc        <= real_nextpc;
        fs_excp      <= pfs_excp;
        fs_excp_num  <= pfs_excp_num;
    end
end

//btb
assign fetch_pc  = real_nextpc;
assign fetch_en  = inst_valid && inst_addr_ok || flush_sign;

endmodule
