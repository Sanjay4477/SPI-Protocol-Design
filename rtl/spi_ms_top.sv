`include "spi_clk_gen.sv"
`include "spi_master.sv"
`include "spi_slave.sv"
`include "spi_slave_sel.sv"
`include "miso_bus_sel.sv"

module spi_ms_top #(parameter SLAVE_COUNT = 4)(
  input sys_clk, // System_Clock
  input rst_n, // Reset (Active-Low)
  input [3:0] spi_div_ratio, 
  
  input txn_en,
  input [1:0] txn_len, // 00-8bit; 01-16bit; 10-24bit; 11-32bit
  input [1:0] spi_mode, // SPI_Mode = {CPOL,CPHA}
  input [($clog2(SLAVE_COUNT)-1):0] s_addr, // Slave_Address
  
  input daisy_chain, // Daisy_Chain Configuration Enable
  input default_val, // Default_Value to fill in MOSI/MISO
  output busy_m, // Master_Busy
  output reg [(SLAVE_COUNT-1):0] busy_s, // Slave_Busy
  
  input [31:0] tx_data_m, // Data to be Transmitted to Slave
  output reg [31:0] rx_data_m, // Data Received from Slave
  
  input [31:0] tx_data_s [(SLAVE_COUNT-1):0], // Data to be Transmitted to Master
  output reg [31:0] rx_data_s [(SLAVE_COUNT-1):0] // Data Received from Master
);
  
  wire ext_spi_clk, sclk;
  reg MOSI, MISO, ss_n_m;
  reg [(SLAVE_COUNT)-1:0] ss_n, MISO_bus;
  

  spi_clk_gen clk_gen_inst(
    .sys_clk_in   (sys_clk),
    .rst_n    (rst_n),
    .spi_div_ratio (spi_div_ratio),
    .spi_clk_out  (ext_spi_clk)
  );
  
  spi_master #(.SLAVE_COUNT(SLAVE_COUNT)) spi_m_dut(
    .sys_clk       (sys_clk),
    .rst_n         (rst_n),
    .ext_spi_clk   (ext_spi_clk),
    .txn_en        (txn_en),
    .busy_m        (busy_m),
    .MISO          (MISO),
    .MOSI          (MOSI),
    .sclk          (sclk),
    .ss_n_m        (ss_n_m),
    .s_addr        (s_addr),     
    .txn_len       (txn_len),
    .spi_mode      (spi_mode),
    .default_val   (default_val),
    .tx_data_m     (tx_data_m),
    .rx_data_m     (rx_data_m)
  );
  
  spi_slave_sel s_sel_inst(
    .ss_n_m (ss_n_m),
    .s_addr (s_addr),
    .ss_n (ss_n)
  );
  
  miso_bus_sel miso_s_inst(
    .MISO_bus (MISO_bus),
    .s_addr (s_addr),
    .MISO (MISO)
  );
  
  genvar i;
  generate
    for (i=0; i<SLAVE_COUNT; i=i+1) begin : SLAVE_GEN
      spi_slave spi_s_dut(
        .sys_clk(sys_clk),
        .rst_n(rst_n),
        .busy_s(busy_s[i]),
        .ss_n(ss_n[i]),
        .sclk(sclk),
        .SDI(MOSI),
        .SDO(MISO_bus[i]),
        .txn_len(txn_len),
        .spi_mode(spi_mode),
        .daisy_chain(daisy_chain),
        .default_val(default_val),
        .tx_data_s(tx_data_s[i]),
        .rx_data_s(rx_data_s[i])
      );
    end
  endgenerate
  
endmodule
  
  
  
