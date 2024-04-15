//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: ENCODER
// Module Name: idx2oh
// Modify Date: 
//
// Description:
// index to one-hot
//////////////////////////////////////////////////
module idx2oh #(
    parameter  IDX_WIDTH = 4,
    localparam OH_WIDTH  = 1 << IDX_WIDTH
) (
    input        [IDX_WIDTH-1:0]    index,
    output logic [OH_WIDTH-1:0]     one_hot
);
    generate
        genvar i;
        for(i=0; i<OH_WIDTH; i++) begin
            assign one_hot[i] = index == i;
        end
    endgenerate
endmodule : idx2oh