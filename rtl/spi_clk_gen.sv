module spi_clk_gen(
  input sys_clk_in, rst_n,
  input [3:0] spi_div_ratio,
  output spi_clk_out
);
  
  reg [15:0] clk_arr;
  assign spi_clk_out = clk_arr[spi_div_ratio];

  ////// "Frequency: clk_arr[i] == clk_in / 2**i" //////

  ////// Initial Clock_Divider //////
  assign clk_arr[0] = sys_clk_in;
  
  //   always@(posedge clk_in or negedge rst_n)
  //   begin      
  //     if(~rst_n)        
  //       begin          
  //         clk_arr[0] <= 0;        
  //       end          
  //     else              
  //       begin        
  //         clk_arr[0] <= ~clk_arr[0];       
  //       end    
  //   end

  ////// Clock_Array Generation //////   
  genvar i;    
  generate      
    for (i=0; i<15; i=i+1)         
      begin          
        always@(posedge clk_arr[i] or negedge rst_n)            
          begin              
            if(~rst_n)                
              begin                  
                clk_arr[i+1] <= 0;                
              end              
            else                
              begin                  
                clk_arr[i+1] <= ~clk_arr[i+1];               
              end            
          end        
      end    
  endgenerate
  
endmodule
