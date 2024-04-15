//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: VP
// Module Name: vp_top_tb
// Modify Date: 
//
// Description:
// VP integrated verification testbench
//////////////////////////////////////////////////

`timescale 1ns/100ps
`include "vp_defines.vh"
`include "common_defines.vh"

module top;
    parameter DATA_WIDTH = `LANE_DATA_WIDTH;
    parameter NLANE = `SYS_NUM_LANE;
    parameter TF_ITEM_NUM = `TF_ITEM_NUM;
    parameter TF_ADDR_WIDTH = `TF_ADDR_WIDTH;

    logic[DATA_WIDTH - 1:0] tf_mem[0:NLANE][0:2 ** TF_ADDR_WIDTH];

    genvar i;

    //tf mem fill
    function automatic longint unsigned ntt_tf_index(longint unsigned i, longint unsigned j);
        return (1 << i) + (j % (1 << i));
    endfunction

    function automatic longint unsigned powerMod(longint unsigned a, longint unsigned b, longint unsigned c);
        longint unsigned ans = 1;
        a = a % c;

        while(b > 0) begin
            if(b[0]) begin
                ans = (128'(ans)) * (128'(a)) % c;
            end

            b = b >> 1;
            a = (128'(a)) * (128'(a)) % c;
        end

        return ans;
    endfunction

    //don't use longint unsigned as type of len, otherwise vcs will crash
    function automatic longint unsigned BitReverse(longint unsigned aNum, int unsigned len);
        longint unsigned Num = 0;
        int unsigned i = 0;

        for(i = 0;i < len;i++) begin
            Num |= aNum[0] << ((len - 1) - i);
            aNum >>= 1;
        end

        return Num;
    endfunction

    function automatic longint unsigned intt_invtf_index(longint unsigned i, longint unsigned j, longint unsigned ntt_logn);
        return (1 << (ntt_logn - 1 - i)) + BitReverse((j / (1 << i)) % (1 << (ntt_logn - 1 - i)), ntt_logn - 1 - i);
    endfunction

    longint unsigned tf_vl = 524288;
    longint unsigned tf_stage_cyc = tf_vl / DATA_WIDTH / 2 / (NLANE / 2);
    longint unsigned tf_ntt_logn = $clog2(tf_vl / DATA_WIDTH);
    longint unsigned tf_item_id;
    longint unsigned tf_stage;
    longint unsigned tf_instage;
    longint unsigned tf_raddr;
    longint unsigned tf_raddr_m1;
    bit[TF_ADDR_WIDTH - 1:0] tf_tfaddr;
    longint unsigned tf_tfaddr2;
    longint unsigned tf_w_base[TF_ITEM_NUM] = '{64'd3825716582911, 64'd79932510954937, 64'd101017252977188};
    longint unsigned tf_reverse_w_base[TF_ITEM_NUM] = '{64'd264250557364078134, 64'd101614808487310449, 64'd106746493840490977};
    longint unsigned tf_mod_q[TF_ITEM_NUM] = {64'd576460825317867521, 64'd576460924102115329, 64'd576462951330889729};
    longint unsigned tf_w_index;
    longint unsigned tf_w;

    longint unsigned j;

    generate
        for(i = 0;i < NLANE / 2;i++) begin
            initial begin
                for(tf_item_id = 0;tf_item_id < TF_ITEM_NUM;tf_item_id++) begin
                    for(tf_stage = 0;tf_stage < tf_ntt_logn;tf_stage++) begin
                        for(tf_instage = 0;tf_instage < tf_stage_cyc;tf_instage++) begin
                            tf_raddr = (tf_instage >> 1) | (tf_instage[0] << ($clog2(tf_stage_cyc) - 1));
                            tf_raddr_m1 = ((tf_instage - 1) >> 1) | (((tf_instage - 1) & 'b1) << ($clog2(tf_stage_cyc) - 1));

                            if(tf_stage < $clog2(NLANE / 2)) begin
                                tf_tfaddr = tf_stage;
                                tf_tfaddr2 = tf_stage;
                            end
                            else begin
                                tf_tfaddr = (1 << (tf_stage - $clog2(NLANE / 2))) + (tf_instage & ((1 << (tf_stage - $clog2(NLANE / 2))) - 1)) + $clog2(NLANE / 2) - 1;
                                tf_tfaddr2 = (1 << (tf_stage - $clog2(NLANE / 2))) + (tf_instage & ((1 << (tf_stage - $clog2(NLANE / 2))) - 1)) + $clog2(NLANE / 2) - 1;
                            end

                            tf_tfaddr |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));
                            tf_tfaddr2 |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));

                            if(!tf_instage[0]) begin
                                tf_w_index = ntt_tf_index(tf_stage, tf_raddr * NLANE + unsigned'(i));
                            end
                            else begin
                                tf_w_index = ntt_tf_index(tf_stage, tf_raddr_m1 * NLANE + unsigned'(i) + NLANE / 2);
                            end

                            tf_w = powerMod(tf_w_base[tf_item_id], BitReverse(tf_w_index, tf_ntt_logn), tf_mod_q[tf_item_id]);

                            if(tf_tfaddr == 'h100) begin
                                //$display("stage = %0d, instage = %0d, i = %0d, w_index = %0d, tfaddr = %0d, w = %0x, tfaddr2 = %0d, TF_ADDR_WIDTH = %0d, raddr = %0d, raddr_m1 = %0d, i = %0d", tf_stage, tf_instage, i, tf_w_index, tf_tfaddr, tf_w, tf_tfaddr2, TF_ADDR_WIDTH, tf_raddr, tf_raddr_m1, i);
                            end

                            if($isunknown(tf_mem[i * 2][tf_tfaddr])) begin
                                tf_mem[i * 2][tf_tfaddr] = tf_w;
                            end
                            else if(tf_mem[i * 2][tf_tfaddr] !== tf_w) begin
                                $display("error: ntt: tf_item_id = %0d, tfaddr = %0d, w_index = %0d - %0x !== %0x", tf_item_id, tf_tfaddr, tf_w_index, tf_mem[i * 2][tf_tfaddr], tf_w);
                            end

                            if(tf_tfaddr != tf_tfaddr2) begin
                                $display("error: ntt: tf_item_id = %0d, tfaddr = %0x and tfaddr2 = %0x aren't equal!", tf_item_id, tf_tfaddr, tf_tfaddr2);
                            end

                            //$display("stage = %0d, instage = %0d, i = %0d, tfaddr = %0x", tf_stage, tf_instage, i, tf_tfaddr);

                            tf_raddr = tf_stage_cyc - 1 - tf_instage;

                            if(tf_stage >= (tf_ntt_logn - $clog2(NLANE / 2))) begin
                                tf_tfaddr = tf_ntt_logn - tf_stage - 1;
                                tf_tfaddr2 = tf_ntt_logn - tf_stage - 1;
                            end
                            else begin
                                tf_tfaddr = (1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) + ((tf_stage_cyc - tf_instage - 1) & ((1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) - 1)) + $clog2(NLANE / 2) - 1;
                                tf_tfaddr2 = (1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) + ((tf_stage_cyc - tf_instage - 1) & ((1 << (tf_ntt_logn - 1 - $clog2(NLANE / 2) - tf_stage)) - 1)) + $clog2(NLANE / 2) - 1;
                            end

                            tf_tfaddr |= 1 << (TF_ADDR_WIDTH - 1 - $clog2(TF_ITEM_NUM));
                            tf_tfaddr2 |= 1 << (TF_ADDR_WIDTH - 1 - $clog2(TF_ITEM_NUM));

                            tf_tfaddr |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));
                            tf_tfaddr2 |= (tf_item_id << (TF_ADDR_WIDTH - $clog2(TF_ITEM_NUM)));

                            tf_w_index = intt_invtf_index(tf_stage, BitReverse(tf_raddr * NLANE + 2 * unsigned'(i), tf_ntt_logn), tf_ntt_logn);
                            tf_w = powerMod(tf_reverse_w_base[tf_item_id], BitReverse(tf_w_index, tf_ntt_logn), tf_mod_q[tf_item_id]);

                            if($isunknown(tf_mem[i * 2][tf_tfaddr])) begin
                                tf_mem[i * 2][tf_tfaddr] = tf_w;
                            end
                            else if(tf_mem[i * 2][tf_tfaddr] !== tf_w) begin
                                $display("error: intt: tf_item_id = %0d, tfaddr = %0d, w_index = %0d - %0x !== %0x", tf_item_id, tf_tfaddr, tf_w_index, tf_mem[i * 2][tf_tfaddr], tf_w);
                            end

                            if(tf_tfaddr != tf_tfaddr2) begin
                                $display("error: intt: tf_item_id = %0d, tfaddr = %0x and tfaddr2 = %0x aren't equal!", tf_item_id, tf_tfaddr, tf_tfaddr2);
                            end
                        end
                    end
                end

                for(j = 0;j < 2 ** TF_ADDR_WIDTH;j++) begin
                    if($isunknown(tf_mem[i * 2][j])) begin
                        tf_mem[i * 2][j] = 0;
                    end

                    if($isunknown(tf_mem[i * 2 + 1][j])) begin
                        tf_mem[i * 2 + 1][j] = 0;
                    end
                end

                $writememh({"tf_rom/tf_rom", $sformatf(".%0d", i * 2)}, tf_mem[i * 2]);
                $writememh({"tf_rom/tf_rom", $sformatf(".%0d", i * 2 + 1)}, tf_mem[i * 2 + 1]);
            end
        end
    endgenerate
endmodule