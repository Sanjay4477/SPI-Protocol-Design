module spi_ms_top_tb;
  // Parameter
  parameter SLAVE_COUNT = 4;

  // Clocks & reset
  logic sys_clk, rst_n;
  logic [3:0] spi_div_ratio;

  // Master interface
  logic         txn_en;
  logic [1:0]   txn_len;
  logic [1:0]   spi_mode;
  logic [$clog2(SLAVE_COUNT)-1:0] s_addr;
  logic         busy_m;
  logic [31:0]  tx_data_m;
  logic [31:0]  rx_data_m;

  // Slave interface (arrays)
  logic [31:0]  tx_data_s [(SLAVE_COUNT-1):0];
  logic [31:0]  rx_data_s [(SLAVE_COUNT-1):0];
  logic [SLAVE_COUNT-1:0] busy_s;
  
  spi_ms_top #(.SLAVE_COUNT(SLAVE_COUNT)) spi_top_dut(
    .sys_clk        (sys_clk),
    .rst_n          (rst_n),
    .spi_div_ratio  (spi_div_ratio),
    .txn_en         (txn_en),
    .txn_len        (txn_len),
    .spi_mode       (spi_mode),
    .s_addr         (s_addr),
    .daisy_chain    (1'b0),
    .default_val    (spi_mode[1]),
    .busy_m         (busy_m),
    .busy_s         (busy_s),
    .tx_data_m      (tx_data_m),
    .rx_data_m      (rx_data_m),
    .tx_data_s      (tx_data_s),
    .rx_data_s      (rx_data_s)
//     .tx_data_s[0]  (tx_data_s[0]),
//     .tx_data_s[1]  (tx_data_s[1]),
//     .tx_data_s[2]  (tx_data_s[2]),
//     .tx_data_s[3]  (tx_data_s[3]),

//     .rx_data_s[0]  (rx_data_s[0]),
//     .rx_data_s[1]  (rx_data_s[1]),
//     .rx_data_s[2]  (rx_data_s[2]),
//     .rx_data_s[3]  (rx_data_s[3])
  );
  
//   genvar i;
//   generate
//     for (genvar i=0; i<SLAVE_COUNT; i++) begin
//       // Drive the DUT’s unpacked input array from your TB array
//       assign spi_top_dut.tx_data_s[i] = tx_data_s[i];
//       // Read the DUT’s unpacked output array into your TB array
//       assign rx_data_s[i] = spi_top_dut.rx_data_s[i];
//     end
//  endgenerate
  
  initial begin
    $dumpfile("spi_ms.vcd");
    $dumpvars;
  end
  
  genvar idx;
  generate  
    for (idx=0; idx<SLAVE_COUNT; idx++) begin: MONITOR_SLAVES    
      always @(tx_data_s[idx]) begin      
        $display("[%0t ns] --> Slave[%0d] Tx: tx_data_s[%0d] changed to %0h", $time, idx, idx, tx_data_s[idx]);    
      end  
      always @(rx_data_s[idx]) begin      
        $display("[%0t ns] --> Slave[%0d] Rx: rx_data_s[%0d] changed to %0h", $time, idx, idx, rx_data_s[idx]);
      end
    end
  endgenerate
  
  initial sys_clk = 0;
  always #5 sys_clk = ~sys_clk;
  
  initial begin
    //rst_n = 1;   
    rst_n = 0;
    txn_en = 0;
    spi_div_ratio = 2;
    txn_len = 2'b11;       // 32-bit
    spi_mode = 2'b00;       // CPOL=0, CPHA=0
            
    tx_data_m = 32'hDEAD_BEEF;
    
    $monitor("[%0t ns] --> Master Tx: tx_data_m changed to %0h", $time, tx_data_m);
    $monitor("[%0t ns] --> Master Rx: rx_data_m changed to %0h", $time, rx_data_m);
    
    for(int i=0; i<SLAVE_COUNT; i++) begin
      tx_data_s[i] = 32'h1111_1111 * (i+1);
    end
    
    s_addr = 3;
    
    $monitor("[%0t ns] --> Master => Tx: %0h; Rx: %0h  |  Slave_%0d => Tx: %0h; Rx: %0h", $time, tx_data_m, rx_data_m, s_addr, tx_data_s[s_addr], rx_data_s[s_addr]);
    
    #20 rst_n = 1;
    
    @(posedge sys_clk);      
    txn_en = 1;      
    @(posedge sys_clk);      
    txn_en = 0;
    
    wait (!busy_m);
    #6000;
  
    $finish;
    
  end
  
endmodule
