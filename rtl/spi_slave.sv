module spi_slave(
  input sys_clk, // System_Clock
  input rst_n, // Reset (Active-Low)
  
  output busy_s, // Slave_Busy
  
  input ss_n, // Slave_Select (Active-Low)
  input sclk, // Serial_Clock
  input SDI, // Slave Data_In
  output SDO, // Slave Data_Out       
  
  input [1:0] txn_len, // 00-8bit; 01-16bit; 10-24bit; 11-32bit
  input [1:0] spi_mode, // SPI_Mode = {CPOL,CPHA}
  input daisy_chain, // Daisy_Chain Configuration Enable
  input default_val, // Default_Value to fill in MISO
  input [31:0] tx_data_s, // Data to be Transmitted to Master
  output reg [31:0] rx_data_s // Data Received from Master
);
  
  
  // SPI Transaction FSM States
  localparam SPI_IDLE  = 2'b00, // Idle - Ready for new process
             SPI_PRE_Txn  = 2'b01, // Pre-Transaction process
             SPI_ON_Txn  = 2'b11, // SPI on Transaction in progress
             SPI_POST_Txn = 2'b10; // Post-Transaction process
  
  reg [4:0] spi_txn_ctr_s; // SPI_Transaction_Counter
  reg [1:0] spi_state_s; // SPI FSM current_state
  wire spi_idle_s, spi_pre_txn_s, spi_on_txn_s, spi_post_txn_s;
  reg SDO_s;
  wire CPOL = spi_mode[1]; // Serial_Clock Polarity
  wire CPHA = spi_mode[0]; // Serial_Clock Phase
  
  // Transaction Buffers
  reg [31:0] rx_buff_s;
  reg [32:0] tx_buff_s;
  
  wire spi_clk_int_s; // Internal version of sclk that is used for Mode-based Sampling and Shifting

  assign SDO = (ss_n) ? ((daisy_chain) ? SDI : 1'dZ)  : SDO_s;

  // Decode states
  assign spi_idle_s = (spi_state_s == SPI_IDLE);
  assign spi_pre_txn_s = (spi_state_s == SPI_PRE_Txn);
  assign spi_on_txn_s = (spi_state_s == SPI_ON_Txn);
  assign spi_post_txn_s = (spi_state_s == SPI_POST_Txn);
  assign busy_s = ~spi_idle_s;

  // Internal version of sclk that is used for Mode-based Sampling and Shifting
  assign spi_clk_int_s = (sclk ^ CPOL) ^ CPHA;

  //SPI Transaction FSM States
  always@(posedge sys_clk)
    begin
      if(~rst_n)
        begin
          spi_state_s <= SPI_IDLE;
        end
      else
        begin
          case(spi_state_s)
            SPI_IDLE:
              begin
                spi_state_s <= (~ss_n) ? SPI_PRE_Txn : SPI_IDLE;
              end
            SPI_PRE_Txn:
              begin
                spi_state_s <= SPI_ON_Txn;
              end
            SPI_ON_Txn:
              begin
                spi_state_s <= (ss_n) ? SPI_POST_Txn : SPI_ON_Txn;
              end
            SPI_POST_Txn:
              begin
                spi_state_s <= SPI_IDLE;
              end
          endcase
        end
    end
  
  // MISO handle according to Transaction length
  always@(*)
    begin
      if(busy_s)
        case(txn_len)
          
          // MOSI = (CPHA) ? tx_buff[N] (i.e., trailing_edge) : tx_buff[N-1] (i.e., leading_edge);
          // CPHA = 0 => MOSI data is sampled on the 1st edge (leading) of sclk
          // CPHA = 1 => MOSI data is sampled on the 2nd edge (trailing) of sclk
          
          2'b00:
            begin
              SDO_s = (CPHA) ? tx_buff_s[8] : tx_buff_s[7];
            end
          2'b01:
            begin
              SDO_s = (CPHA) ? tx_buff_s[16] : tx_buff_s[15];
            end
          2'b10:
            begin
              SDO_s = (CPHA) ? tx_buff_s[24] : tx_buff_s[23];
            end
          2'b11:
            begin
              SDO_s = (CPHA) ? tx_buff_s[32] : tx_buff_s[31];
            end 
        endcase
      else
        SDO_s = default_val;
    end

  // Transmit Buffer
  always@(negedge spi_clk_int_s or posedge spi_pre_txn_s)
    begin
      if(spi_pre_txn_s)
        begin
          tx_buff_s = {default_val, tx_data_s}; // The next tx_data_m is transmitted only after a new txn is enabled, else default_val is reflected
        end
      else
        begin
          tx_buff_s = {tx_buff_s[31:0], default_val}; // Shift Left => Insert default_val into LSB of tx_buff
        end
    end

  // Receive Buffer
  always@(posedge spi_clk_int_s or posedge spi_idle_s)
    begin
      if(spi_idle_s)
        begin
          rx_buff_s = 32'h0; // In IDLE state, no data is received
        end
      else
        begin
          rx_buff_s = {rx_buff_s[30:0], SDI}; // Shift Left => Sample MISO into LSB of rx_buff
        end
    end
  
  // Stores received data in rx_buff to rx_data_m
  always@(posedge sys_clk)
    begin  
      rx_data_s <= (spi_post_txn_s) ? rx_buff_s : rx_data_s;
    end
endmodule
