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
// mwram_gen.v: Generic mixed width RAM; not synthesizable with Altera's devices. //
//              May not be synthesizable with other vendors;                      //
//              Check your vendor's recommended HDL coding style.                 //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module mwram_gen
 #( parameter                                WR_DW  = 1  ,  // write data width
    parameter                                RD_DW  = 32 ,  // read data width (a multiply of WR_DW)
    parameter                                RD_D   = 512,  // read depth
    parameter                                IZERO  = 1  )  // initialize to zeros
  ( input                                    clk         ,  // clock
    input                                    rst         ,  // global registers reset
    input                                    wEnb        ,  // write enable
    input      [`log2(RD_D*RD_DW/WR_DW)-1:0] wAddr       ,  // write address
    input      [WR_DW                  -1:0] wData       ,  // write data
    input      [`log2(RD_D)            -1:0] rAddr       ,  // read address
    output reg [RD_DW                  -1:0] rData       ); // read data

  localparam WR_D  = RD_D*RD_DW/WR_DW  ; // write depth
  localparam WR_AW = `log2(WR_D)       ; // write address width
  localparam RD_AW = `log2(RD_D)       ; // read  address width
  localparam DSELW = `log2(RD_DW/WR_DW); // data selector width

  reg [RD_DW-1:0] mem [0:RD_D-1]; // memory array
  integer iA;

  initial
    if (IZERO)
      for (iA=0; iA<WR_D; iA=iA+1)
        mem[iA[WR_AW-1:DSELW]][iA[DSELW-1:0]*WR_DW +: WR_DW] <= {WR_DW{1'b0}};

  always @ (posedge clk) begin
    if (wEnb) mem[wAddr[WR_AW-1:DSELW]][wAddr[DSELW-1:0]*WR_DW +: WR_DW] <= wData;
    rData <= mem[rAddr]; // q doesn't get d in this clock cycle
  end


endmodule
