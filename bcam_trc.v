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
//                                  bcam_trc.v:                                   //
//  Brute-force/Transposed-RAM Binary Content Addressasble Memory (BCAM) cascade  //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module bcam_trc
 #( parameter                 CAMD = 128   ,  // CAM depth
    parameter                 CAMW = 9     ,  // CAM/pattern width
    parameter                 STGW = 9     ,  // maximum stage width (9 for M20k; infinity for uncascaded) - allow STGW+1 for last stage if required
    parameter                 BYPS = 1     ,  // Bypassed?  (binary; 0 or 1)
    parameter                 PIPE = 0     ,  // Pipelined? (binary; 0 or 1)
    parameter                 INOM = 1     ,  // binary / Initial CAM with no match
    parameter                 BRAM = "M20K")  // BRAM type- "M20K":Altera's M20K; "GEN":generic
  ( input                     clk          ,  // clock
     input                    rst          ,  // global registers reset
     input                    wEnb         ,  // write enable
     input  [`log2(CAMD)-1:0] wAddr        ,  // write address
     input  [      CAMW -1:0] wPatt        ,  // write pattern
     input  [      CAMW -1:0] mPatt        ,  // patern to match
     output                   match        ,  // match indicator
     output [`log2(CAMD)-1:0] mAddr        ); // matched address

  ///////////////////////////////////////////////////////////////////////////////

  // Stage parameters
  localparam nSTG  = CAMW/STGW+((CAMW%STGW)>1)                                            ; // number of stage
  localparam LSTGW = ((CAMW%STGW)==0) ? STGW : (((CAMW%STGW)==1) ? (STGW+1) : (CAMW%STGW)); // last stage width

  // generate and instantiate transposed RAM structure
  wire [CAMD-1:0] matchStg [nSTG-1:0];
  genvar gi;
  generate
    for (gi=0 ; gi<nSTG ; gi=gi+1) begin: STGgi
        // instantiate transposed-RAM stage BCAM (TRS)
        bcam_trs  #( .CAMD ( CAMD                                       ),  // CAM depth
                     .CAMW ( gi<(nSTG-1) ? STGW : LSTGW                 ),  // CAM/pattern width
                     .BYPS ( BYPS                                       ),  // Bypassed?  (binary; 0 or 1)
                     .PIPE ( PIPE                                       ),  // Pipelined? (binary; 0 or 1)
                     .INOM ( INOM                                       ),  // binary / Initial CAM with no match (has priority over IFILE)
                     .BRAM ( BRAM                                       ))  // BRAM type- "M20K":Altera's M20K; "GEN":generic
        bcam_trs_i ( .clk  ( clk                                        ),  // clock
                     .rst  ( rst                                        ),  // global registers reset
                     .wEnb ( wEnb                                       ),  // write enable
                     .wAddr( wAddr                                      ),  // write address    / [`log2(CAMD)-1:0]
                     .wPatt( wPatt[gi*STGW +: (gi<(nSTG-1)?STGW:LSTGW)] ),  // write pattern    / [      CAMW -1:0]
                     .mPatt( mPatt[gi*STGW +: (gi<(nSTG-1)?STGW:LSTGW)] ),  // patern to match  / [      CAMW -1:0]
                     .match( matchStg[gi]                               ));  // match / one-hot / [      CAMD -1:0]
    end
  endgenerate

  ///////////////////////////////////////////////////////////////////////////////

  // cascading by AND'ing matches

  integer i;
  reg [CAMD-1:0] matchOH; // match one-hot
  always @(*) begin
    matchOH = {CAMD{1'b1}};
    for (i=0; i<nSTG; i=i+1)
      matchOH = matchOH & matchStg[i];
  end

  ///////////////////////////////////////////////////////////////////////////////

  // binary match (priority encoded) with CAMD width
  // generated automatically by ./pe script
  pe_camd pe_trc_inst (
    .clk( clk     ), // clock for pipelined priority encoder
    .rst( rst     ), // registers reset for pipelined priority encoder
    .oht( matchOH ), // one-hot match input / in : [      CAMD -1:0]
    .bin( mAddr   ), // first match index   / out: [`log2(CAMD)-1:0]
    .vld( match   )  // match indicator     / out
  );

  ///////////////////////////////////////////////////////////////////////////////

endmodule
