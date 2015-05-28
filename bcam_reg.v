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
//      bcam_reg.v: Register-based Binary Content Addressasble Memory (BCAM)      //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module bcam_reg
 #( parameter                CAMD = 16,  // CAM depth
    parameter                CAMW = 4 ,  // CAM/pattern width
    parameter                PIPE = 0 ,  // Pipelined? (binary; 0 or 1)
    parameter                INOM = 1 )  // binary / Initial CAM with no match
  ( input                    clk      ,  // clock
    input                    rst      ,  // global registers reset
    input                    wEnb     ,  // write enable
    input  [`log2(CAMD)-1:0] wAddr    ,  // write address
    input  [      CAMW -1:0] wPatt    ,  // write pattern
    input  [      CAMW -1:0] mPatt    ,  // patern to match
    output                   match    ,  // match indicator
    output [`log2(CAMD)-1:0] mAddr    ); // matched address

  // wAddr one-hot decoder
  reg [CAMD-1:0] lineWEnb;
  always @(*) begin
    lineWEnb        = {CAMD{1'b0}};
    lineWEnb[wAddr] = wEnb        ;
  end

  // write data and valid bit (MSB)
  reg [CAMW:0] CAMReg [0:CAMD-1];
  integer i;
  always @(posedge clk, posedge rst)
    for (i=0; i<CAMD; i=i+1)
      if (rst && INOM) CAMReg[i] <= {(CAMW+1){1'b0}};
      else if (lineWEnb[i]) CAMReg[i] <= {1'b1,wPatt};

  // onehot match
  reg [CAMD-1:0] matchOnehot;
  always @(*)
    for (i=0; i<CAMD; i=i+1)
      matchOnehot[i] = (CAMReg[i] == {1'b1,mPatt});

  // binary match (priority encoded) with CAMD width
  // generated automatically by ./pe script
  pe_camd pe_reg_inst (
    .clk( clk         ), // clock for pipelined priority encoder
    .rst( rst         ), // registers reset for pipelined priority encoder
    .oht( matchOnehot ), // one-hot match input / in : [      CAMD -1:0]
    .bin( mAddr       ), // first match index   / out: [`log2(CAMD)-1:0]
    .vld( match       )  // match indicator     / out
  );

endmodule


