module spi_slave_sel #(parameter SLAVE_COUNT = 4)(
  input ss_n_m,
  input [($clog2(SLAVE_COUNT)-1):0] s_addr,
  output reg [(SLAVE_COUNT-1):0] ss_n
);
  
  genvar i;
  generate
   for (i=0; i<SLAVE_COUNT; i=i+1) begin
     assign ss_n[i] = (s_addr == i) ? ss_n_m : 1'b1;
   end
  endgenerate
  
endmodule
