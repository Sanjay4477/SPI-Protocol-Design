module miso_bus_sel #(parameter SLAVE_COUNT = 4)(
  input [(SLAVE_COUNT-1):0] MISO_bus,
  input [($clog2(SLAVE_COUNT)-1):0] s_addr,
  output reg MISO
);
  
  assign MISO = MISO_bus[s_addr];
  
endmodule
