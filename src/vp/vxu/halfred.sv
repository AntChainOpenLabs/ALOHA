//////////////////////////////////////////////////
// Engineer: 
// Email: 
//
// Project Name: MVP
// Module Name: halfred
// Modify Date: 

// Description: i_a multiply by 1/2 with modulo Q
//////////////////////////////////////////////////

module halfred #(
    parameter data_width_p = 64
) (
    input      [data_width_p-1:0] a_i,
    input      [data_width_p-1:0] mod_i,
    input      [data_width_p-1:0] imod_i,
    output reg [data_width_p-1:0] halfred_o
);

wire [data_width_p-1:0] mux_o;

assign mux_o = a_i[0] ? (mod_i + 1) >> 1 : 'b0;  // add (HE_MOD + 1)/2 if i_a is odd

always @(*) begin
    halfred_o = mux_o + a_i[data_width_p-1:1];
end

endmodule