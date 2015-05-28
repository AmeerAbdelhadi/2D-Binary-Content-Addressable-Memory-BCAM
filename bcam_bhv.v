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
// bcam_bhv.v: Behavioral description of Binary Content Addressasble Memory (BCAM)//
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module bcam_bhv
 #( parameter                    CAMD = 512,  // CAM depth
    parameter                    CAMW = 32 ,  // CAM/pattern width
    parameter                    INOM = 1  )  // binary / Initial CAM with no match (has priority over IFILE)
  ( input                        clk       ,  // clock
    input                        rst       ,  // global registers reset
    input                        wEnb      ,  // write enable
    input      [`log2(CAMD)-1:0] wAddr     ,  // write address
    input      [      CAMW -1:0] wPatt     ,  // write pattern
    input      [      CAMW -1:0] mPatt     ,  // patern to match
    output reg                   match     ,  // match indicator
    output reg [`log2(CAMD)-1:0] mAddr     ); // matched address

  // assign memory array
  reg [CAMW-1:0] mem [0:CAMD-1];

  // valid bit
  reg [CAMD-1:0] vld;

  // initialize memory, with zeros if INOM or file if IFILE.
  integer i;
  initial
    if (INOM)
      for (i=0; i<CAMD; i=i+1)
        {vld[i],mem[i]} = {1'b0,{CAMW{1'b0}}};

  always @(posedge clk) begin
    // write to memory
    if (wEnb)
      {vld[wAddr],mem[wAddr]} = {1'b1,wPatt};
    // search memory
    match = 0;
    mAddr = 0;
    match = (mem[mAddr]==mPatt) && vld[mAddr];
    while ((!match) && (mAddr<(CAMD-1))) begin
      mAddr=mAddr+1;
      match = (mem[mAddr]==mPatt) && vld[mAddr];
    end
  end

endmodule
