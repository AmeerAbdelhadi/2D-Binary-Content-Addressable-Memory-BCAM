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
//                                   bcam_trs.v:                                  //
//   Brute-force/Transposed-RAM Binary Content Addressasble Memory (BCAM) stage   //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module bcam_trs
 #( parameter                 CAMD = 128   ,  // CAM depth
    parameter                 CAMW = 9     ,  // CAM/pattern width
    parameter                 BYPS = 1     ,  // Bypassed?  (binary; 0 or 1)
    parameter                 PIPE = 0     ,  // Pipelined? (binary; 0 or 1)
    parameter                 INOM = 1     ,  // binary / Initial CAM with no match
    parameter                 BRAM = "M20K")  // BRAM type- "M20K":Altera's M20K; "GEN":generic
  ( input                     clk          ,  // clock
     input                    rst          ,  // global registers reset
     input                    wEnb         ,  // write enable
     input  [`log2(CAMD)-1:0] wAddr        ,  // write address   / [`log2(CAMD)-1:0]
     input  [      CAMW -1:0] wPatt        ,  // write pattern   / [      CAMW -1:0]
     input  [      CAMW -1:0] mPatt        ,  // patern to match / [      CAMW -1:0]
     output [      CAMD -1:0] match        ); // match / one-hot / [      CAMD -1:0]

  localparam ADDRW = `log2(CAMD);

  ///////////////////////////////////////////////////////////////////////////////

  // Trace RAM - a single-ported RAM

  reg               addRmv; // add or remove (inverted) pattern from CAM / control for CAM
  wire [CAMW-1:0] rDataRAM;  // read data from RAM (should be erased from CAM)

  spram #( .MEMD ( CAMD     ),  // memory depth
           .DATAW( CAMW     ),  // data width
           .IZERO( INOM     ),  // binary / Initial RAM with zeros (has priority over IFILE)
           .IFILE( ""       ))  // initialization hex file (don't pass extension), optional
  trram  ( .clk  ( clk      ),  // clock
           .wEnb ( !addRmv  ),  // write enable for port B
           .addr ( wAddr    ),  // write/read address / [`log2(MEMD)-1:0]
           .wData( wPatt    ),  // write data         / [DATAW      -1:0]
           .rData( rDataRAM )); // read  data         / [DATAW  -1:0]

  ///////////////////////////////////////////////////////////////////////////////

  // Transposed RAM as a CAM

  wire [CAMD-1:0] match1Hot                    ; // pattern one-hot match from CAM
  reg  wEnbCAM                                 ; // write enable for CAM / control for CAM
  wire rmvSameAdd = !addRmv & (wPatt==rDataRAM); // trying to remove same just added pattern

  trcam  #( .CAMD ( CAMD                      ),  // CAM depth (power of 2)
            .CAMW ( CAMW                      ),  // CAM/pattern width / for one stage (<=14)
            .INOM ( INOM                      ),  // binary / Initial CAM with no match
            .BRAM ( BRAM                      ))  // BRAM type- "M20K":Altera's M20K; "GEN":generic
  trcam_i ( .clk  ( clk                       ),  // clock
            .rst  ( rst                       ),  // global registers reset
            .wEnb ( wEnbCAM & !(rmvSameAdd)   ),  // write enable
            .wrEr ( addRmv                    ),  // add or remove (inverted) pattern from CAM
            .wAddr( wAddr                     ),  // write address   / [`log2(CAMD)-1:0]
            .wPatt( addRmv ? wPatt : rDataRAM ),  // write pattern   / [      CAMW -1:0]
            .mPatt( mPatt                     ),  // patern to match / [      CAMW -1:0]
            .match( match1Hot                 )); // match / one-hot / [      CAMD -1:0]

  ///////////////////////////////////////////////////////////////////////////////

  // CAM bypassing

  // register write address and pattern on wEnb
  reg [ADDRW-1:0] wAddrR;
  reg [CAMW -1:0] wPattR;
  always @(posedge clk, posedge rst)
    if (rst)       {wAddrR,wPattR} <= {{(ADDRW+CAMW ){1'b0}}};
    else if (wEnb) {wAddrR,wPattR} <= {  wAddr,wPatt       };

  // bypass if registered write pattern equals to pattern to match
  wire isByp = (wPattR==mPatt);

  // second stage bypassing
  reg isBypR;
  reg [ADDRW-1:0] wAddrRR;
  always @(posedge clk, posedge rst)
    if (rst) {wAddrRR,isBypR} <= {{(ADDRW +1    ){1'b0}}};
    else     {wAddrRR,isBypR} <= {  wAddrR,isByp        };

/////////////// retiming //////////////
//// will increase registers count ////

  // onehot registerd write address
  reg [CAMD-1:0] wAddr1HotRR ;
//always @(*) begin
//  wAddr1HotRR          = 0   ;
//  wAddr1HotRR[wAddrRR] = 1'b1;
//end

  reg [CAMD-1:0] wAddr1HotR ;
  always @(*) begin
    wAddr1HotR         = 0   ;
    wAddr1HotR[wAddrR] = 1'b1;
  end
  always @(posedge clk, posedge rst)
    if (rst) wAddr1HotRR <= {CAMD{1'b0}};
    else     wAddr1HotRR <= wAddr1HotR ;

/////////////// retiming //////////////

  // masked onehot match to onehot output
  assign match = BYPS ? ( isBypR ? ( wAddr1HotRR | match1Hot) 
                                 : (~wAddr1HotRR & match1Hot) )
                      : match1Hot;

  ///////////////////////////////////////////////////////////////////////////////

  // controller / Mealy FSM
  // Inputs : wEnb
  // Outputs: addRmv wEnbCAM

  reg curStt, nxtStt  ;
  localparam S0 = 1'b0;
  localparam S1 = 1'b1;

  // synchronous
  always @(posedge clk, posedge rst)
    if (rst) curStt <= S0    ;
    else     curStt <= nxtStt;

  // combinatorial
  always @(*)
    case (curStt)
      S0: if (wEnb) {nxtStt,wEnbCAM,addRmv}={S1,2'b11};
          else      {nxtStt,wEnbCAM,addRmv}={S0,2'b01};
      S1: if (wEnb) {nxtStt,wEnbCAM,addRmv}={S0,2'b10};
          else      {nxtStt,wEnbCAM,addRmv}={S0,2'b10};
    endcase

  ///////////////////////////////////////////////////////////////////////////////

endmodule
