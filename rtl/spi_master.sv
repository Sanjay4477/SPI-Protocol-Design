module spi_master #(parameter SLAVE_COUNT = 4)(
  input sys_clk, // System_Clock 
  input rst_n, // Reset (Active-Low)
  
  input ext_spi_clk, // External SPI clock with double the required sclk frequency
  input txn_en, // Transaction_Enable
  output busy_m, // Master_Busy
  
  input MISO, // Master_In Slave_Out
  output reg MOSI, // Master_Out Slave_In
  output sclk, // Serial_Clock
  //output reg [(SLAVE_COUNT-1):0] ss_n, // Multiple Slave_Select (Active-Low)
  output reg ss_n_m, // Slave_Select (Active-Low) from Master
  
  input [($clog2(SLAVE_COUNT)-1):0] s_addr, // Slave_Address
  input [1:0] txn_len, // Transaction_Length: 00-8bit; 01-16bit; 10-24bit, 11-32bit
  input [1:0] spi_mode, // SPI_Mode = {CPOL,CPHA}
  input default_val, // Default_Value to fill in MOSI
  input [31:0] tx_data_m, // Data to be Transmitted to Slave
  output reg [31:0] rx_data_m // Data Received from Slave
);
  
  wire CPOL = spi_mode[1]; // Serial_Clock Polarity
  wire CPHA = spi_mode[0]; // Serial_Clock Phase
  
  localparam SLAVE_ADDR_LEN = $clog2(SLAVE_COUNT); // Slave_Address Length
  
  // SPI Transaction FSM States
  localparam SPI_IDLE  = 2'b00, // Idle - Ready for new process
             SPI_PRE_Txn  = 2'b01, // Pre-Transaction process
             SPI_ON_Txn  = 2'b11, // SPI on Transaction in progress
             SPI_POST_Txn = 2'b10; // Post-Transaction process
  
  reg [4:0] spi_txn_ctr_m; // SPI_Transaction_Counter
  reg [1:0] spi_state_m; // SPI FSM current_state
  wire spi_idle_m, spi_pre_txn_m, spi_on_txn_m, spi_post_txn_m;
  
  // Transaction Buffers
  reg [31:0] rx_buff_m;
  reg [32:0] tx_buff_m;
  
  // Internal Clock signals
  reg spi_clk_temp; // Temporary SPI clock to divide from the ext_spi_clk_x2
  wire spi_clk_int_m; // Internal version of sclk that is used for Mode-based Sampling and Shifting
  wire bit_done_m;
  
  // Decode states of SPI FSM
  assign spi_idle_m = (spi_state_m == SPI_IDLE);
  assign spi_pre_txn_m = (spi_state_m == SPI_PRE_Txn);
  assign spi_on_txn_m = (spi_state_m == SPI_ON_Txn);
  assign spi_post_txn_m = (spi_state_m == SPI_POST_Txn);
  assign busy_m = ~spi_idle_m;

  assign bit_done_m = (~|spi_txn_ctr_m) & ext_spi_clk;
  
  // If sys_clk is of higher frequency (>=100MHz), then it's advisable to derive the ext_spi_clk into the system to avoid CDC
  always@(posedge ext_spi_clk or negedge rst_n)
    begin
      if(~rst_n) begin
        spi_clk_temp <= 1'b0;
      end else begin
        spi_clk_temp <= ~spi_clk_temp;
      end
    end
  
  
  // Serial_Clock should not work when not in use
  assign sclk = (spi_on_txn_m) ? (CPOL ^ spi_clk_temp) : CPOL; // Actual sclk of the SPI Interface
  
  // Internal version of sclk that is used for Mode-based Sampling and Shifting
  assign spi_clk_int_m = (sclk ^ CPOL) ^ CPHA; 

  // SPI Transaction FSM States
  always@(posedge sys_clk)
    begin
      if(~rst_n)
        begin
          spi_state_m <= SPI_IDLE;
        end
      else
        begin
          case(spi_state_m)
            SPI_IDLE:
              begin
                spi_state_m <= (txn_en) ? SPI_PRE_Txn : SPI_IDLE;
              end
            SPI_PRE_Txn: // Waits for 1st Active sclk 
              begin
                //spi_state <= (CPOL == (spi_clk_temp ^ CPOL)) ? SPI_ON_Txn : SPI_PRE_Txn;
                if ((CPOL ^ spi_clk_temp) != CPOL) 
                  spi_state_m <= SPI_ON_Txn;  
                else 
                  spi_state_m <= SPI_PRE_Txn;                      
              end
            
                SPI_ON_Txn: // Shift or Sample all bits, count down, wait for IDLE polarity
              begin
                //spi_state <= (((~|spi_txn_ctr & ext_spi_clk) & (CPOL == sclk))) ? SPI_POST_Txn : SPI_ON_Txn;
                if (bit_done_m && ((CPOL ^ spi_clk_temp) == CPOL)) 
                  spi_state_m <= SPI_POST_Txn;  
                else 
                  spi_state_m <= SPI_ON_Txn;
              end
            
            SPI_POST_Txn: // Latch & cleanup
              begin
                spi_state_m <= SPI_IDLE;
              end
          endcase
        end
    end

  // SPI Transaction Counter
  always@(negedge ext_spi_clk or posedge spi_pre_txn_m)
    begin
      if(spi_pre_txn_m)
        begin
          case(txn_len)
            2'b00: // 8bit - so spi_txn_ctr starts from 24 to 32.
              begin
                spi_txn_ctr_m <= 5'd24; // 24 + 8 = 32
              end
            2'b01: // 16bit - so spi_txn_ctr starts from 16 to 32.
              begin
                spi_txn_ctr_m <= 5'd16; // 16 + 16 = 32
              end
            2'b10: // 24bit - so spi_txn_ctr starts from 08 to 32.
              begin
                spi_txn_ctr_m <= 5'd8; // 8 + 24 = 32
              end
            2'b11: // 32bit - so spi_txn_ctr starts from 00 to 32.
              begin
               spi_txn_ctr_m <= 5'd0; // 0 + 32 = 32
              end
          endcase
        end
      else
        begin
          spi_txn_ctr_m <= spi_txn_ctr_m + {4'h0,(spi_clk_temp & spi_on_txn_m)}; //
        end
    end

  // MOSI handle according to Transaction length
  always@(*)
    begin
      if(busy_m)
        case(txn_len)
          
          // MOSI = (CPHA) ? tx_buff[N] (i.e., trailing_edge) : tx_buff[N-1] (i.e., leading_edge);
          // CPHA = 0 => MOSI data is sampled on the 1st edge (leading) of sclk
          // CPHA = 1 => MOSI data is sampled on the 2nd edge (trailing) of sclk
          
          2'b00:
            begin
              MOSI = (CPHA) ? tx_buff_m[8] : tx_buff_m[7]; 
            end
          2'b01:
            begin
              MOSI = (CPHA) ? tx_buff_m[16] : tx_buff_m[15];
            end
          2'b10:
            begin
              MOSI = (CPHA) ? tx_buff_m[24] : tx_buff_m[23];
            end
          2'b11:
            begin
              MOSI = (CPHA) ? tx_buff_m[32] : tx_buff_m[31];
            end 
        endcase
      else
        MOSI = default_val;
    end
  
  // Transmit Buffer
  always@(negedge spi_clk_int_m or posedge spi_pre_txn_m)
    begin
      if(spi_pre_txn_m)
        begin
          tx_buff_m = {default_val, tx_data_m}; // The next tx_data_m is transmitted only after a new txn is enabled, else default_val is reflected
        end
      else
        begin
          tx_buff_m = {tx_buff_m[31:0], default_val}; // Shift Left => Insert default_val into LSB of tx_buff
        end
    end
  
  // Receive Buffer
  always@(posedge spi_clk_int_m or posedge spi_idle_m)
    begin
      if(spi_idle_m)
        begin
          rx_buff_m = 32'h0; // In IDLE state, no data is received
        end
      else
        begin
          rx_buff_m = {rx_buff_m[30:0], MISO}; // Shift Left => Sample MISO into LSB of rx_buff
        end
    end
  
  // Stores received  data in rx_buff to rx_data_m
  always@(posedge sys_clk)
    begin  
      rx_data_m <= (spi_post_txn_m) ? rx_buff_m : rx_data_m;
    end

  // Master's Slave_Select Handle
  always@(posedge sys_clk)
    begin
      if(~rst_n)
        begin
          ss_n_m <= 1'b1;
        end
      else
        begin
          case(spi_state_m)
            SPI_IDLE, SPI_POST_Txn: ss_n_m <= 1'b1;
            
            SPI_PRE_Txn, SPI_ON_Txn: ss_n_m <= 1'b0;
            
            default: ss_n_m <= 1'b1;
          endcase
        end
    end
endmodule
