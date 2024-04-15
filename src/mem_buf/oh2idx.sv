module oh2idx #(
    parameter  IDX_WIDTH = 4,
    localparam OH_WIDTH  = 1 << IDX_WIDTH
) (
    input        [OH_WIDTH-1:0]  one_hot,
    output logic [IDX_WIDTH-1:0] index
);
    always_comb begin
        index = 0;
        for (int i=0; i<OH_WIDTH; i++) begin
            if(one_hot[i])
                index |= i[IDX_WIDTH-1:0];
        end
    end

endmodule