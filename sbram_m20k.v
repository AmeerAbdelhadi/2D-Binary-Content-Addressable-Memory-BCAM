////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2014, University of British Columbia (UBC); All rights reserved. //
//                                                                                //
// Redistribution  and  use  in  source   and  binary  forms,   with  or  without //
// modification,  are permitted  provided that  the following conditions are met: //
//   * Redistributions   of  source   code  must  retain   the   above  copyright //
//     notice,  this   list   of   conditions   and   the  following  disclaimer. //
//   * Redistributions  in  binary  form  must  reproduce  the  above   copyright //
//     notice, this  list  of  conditions  and the  following  disclaimer in  the //
//     documentation and/or  other  materials  provided  with  the  distribution. //
//   * Neither the name of the University of British Columbia (UBC) nor the names //
//     of   its   contributors  may  be  used  to  endorse  or   promote products //
//     derived from  this  software without  specific  prior  written permission. //
//                                                                                //
// THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" //
// AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE //
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE //
// DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE //
// FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL //
// DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR //
// SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER //
// CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, //
// OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE //
// OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//             sbram_m20k.v: Single-bit width RAM using Altera's M20K             //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module sbram_m20k
 #( parameter                DEPTH  = 16384,  // read depth > 16K
    parameter                IZERO  = 1    )  // initialize to zeros
  ( input                    clk           ,  // clock
    input                    rst           ,  // global registers reset
    input                    wEnb          ,  // write enable
    input [`log2(DEPTH)-1:0] wAddr         ,  // write address
    input                    wData         ,  // write data
    input [`log2(DEPTH)-1:0] rAddr         ,  // read address
    output                   rData         ); // read data

  localparam ADDRW = `log2(DEPTH); // 
  localparam nM20K = DEPTH/16384;

  wire [nM20K-1:0] rDataAll;

  reg  [nM20K-1:0] M20KSel;
  // binary to one-hot
  always @(*) begin
    M20KSel                    = 0   ;
    M20KSel[wAddr[ADDRW-1:14]] = wEnb;
  end


  // generate and instantiate mixed-width BRAMs
  genvar gi;
  generate
    for (gi=0 ; gi<nM20K ; gi=gi+1) begin: BRAMgi
          mwram_m20k  #( .WR_DW( 1            ),  // write width
                         .RD_DW( 1            ),  // read width
                         .IZERO( IZERO        ))  // initialize to zeros
          mwram_m20k_i ( .clk  ( clk          ),  // clock
                         .rst  ( rst          ),  // global registers reset
                         .wEnb ( M20KSel[gi]  ),  // write enable
                         .wAddr( wAddr[13:0]  ),  // write address [13:0]
                         .wData( wData        ),  // write data
                         .rAddr( rAddr[13:0]  ),  // read address [ 13:0]
                         .rData( rDataAll[gi] )); // read data [31:0]

    end
  endgenerate

  assign rData = rDataAll[rAddr[ADDRW-1:14]];

endmodule
