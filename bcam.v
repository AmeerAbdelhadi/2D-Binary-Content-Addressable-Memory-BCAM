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
//          bcam.v: Binary Content Addressable Memory (BCAM) wrapper for:         //
//       Behavioral (BHV), register-based (REG), transposed-RAM stage (TRS)       //
//         ,transposed-RAM cascade (TRC) & segmented transposed-RAM (STR)         //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

`ifndef SIM
// configure architectural parameters for synthesis
// to define CAMD, CAMW, SEGW, and TYPE
`include "config.vh"
`endif

`ifndef TYPE
`define TYPE ""
`endif

`ifndef PIPE
`define PIPE 0
`endif

`ifndef BYPS
`define BYPS 1
`endif

module bcam
 #( parameter                CAMD = `CAMD ,  // CAM depth / a multiply of SEGW
    parameter                CAMW = `CAMW ,  // CAM/pattern width
    parameter                SEGW = `SEGW ,  // Segment width / STRAM only
    parameter                BYPS = `BYPS ,  // Bypassed? (binary; 0 or 1)
    parameter                PIPE = `PIPE ,  // Pipelined? (binary; 0 or 1)
    parameter                INOM = 1     ,  // binary / Initial CAM with no match
    parameter                REGW = 1     ,  // binary / register write inputs wEnb, wAddr, & wPatt?
    parameter                REGM = 1     ,  // binary / register match input mPatt?
    parameter                REGO = 1     ,  // binary / register outputs match & mAddr?
    parameter                BRAM = "M20K",  // BRAM type- "M20K":Altera's M20K; "GEN":generic
    parameter                TYPE = `TYPE )  // implementation type: BHV, REG, TRS, TRC, & STR
  ( input                    clk           ,  // clock
    input                    rst           ,  // global registers reset
    input                    wEnb          ,  // write enable
    input  [`log2(CAMD)-1:0] wAddr         ,  // write address
    input  [      CAMW -1:0] wPatt         ,  // write patterns
    input  [      CAMW -1:0] mPatt         ,  // patern to match
    output                   match         ,  // match indicator
    output [`log2(CAMD)-1:0] mAddr         ); // matched address

  localparam ADDRW = `log2(CAMD); // address width

  // register inputs 1
  reg wEnbR;
  reg [ADDRW-1:0] wAddrR;
  reg [CAMW -1:0] wPattR,mPattR;
  always @(posedge clk, posedge rst)
    if (rst) {wEnbR,wAddrR,wPattR,mPattR} <= {(1   +ADDRW+CAMW +CAMW ){1'b0}};
    else     {wEnbR,wAddrR,wPattR,mPattR} <= { wEnb,wAddr,wPatt,mPatt       };

  // register inputs 2
  reg wEnbRR;
  reg [ADDRW-1:0] wAddrRR;
  reg [CAMW -1:0] wPattRR,mPattRR;
  always @(posedge clk, posedge rst)
    if (rst) {wEnbRR,wAddrRR,wPattRR,mPattRR} <= {(1    +ADDRW +CAMW  +CAMW  ){1'b0}};
    else     {wEnbRR,wAddrRR,wPattRR,mPattRR} <= { wEnbR,wAddrR,wPattR,mPattR       };

  // assign inputs
  wire             wEnbI  = PIPE ? wEnbRR  : ( REGW ? wEnbR  : wEnb  );
  wire [ADDRW-1:0] wAddrI = PIPE ? wAddrRR : ( REGW ? wAddrR : wAddr );
  wire [CAMW -1:0] wPattI = PIPE ? wPattRR : ( REGW ? wPattR : wPatt );
  wire [CAMW -1:0] mPattI = PIPE ? mPattRR : ( REGM ? mPattR : mPatt );

  // generate and instantiate BCAM with specific implementation
  wire             matchI;
  wire [ADDRW-1:0] mAddrI;
  generate
    if (TYPE=="BHV") begin
      // instantiate behavioral BCAM
      bcam_bhv  #( .CAMD ( CAMD   ),  // CAM depth
                   .CAMW ( CAMW   ),  // CAM/pattern width
                   .INOM ( INOM   ))  // binary / Initial CAM with no match (has priority over IFILE)
      bcam_bhv_i ( .clk  ( clk    ),  // clock
                   .rst  ( rst    ),  // global registers reset
                   .wEnb ( wEnbI  ),  // write enable
                   .wAddr( wAddrI ),  // write address
                   .wPatt( wPattI ),  // write pattern
                   .mPatt( mPattI ),  // patern to match
                   .match( matchI ),  // match indicator
                   .mAddr( mAddrI )); // matched address
    end
    else if (TYPE=="REG") begin
      // instantiate register-based BCAM
      bcam_reg  #( .CAMD ( CAMD   ),  // CAM depth
                   .CAMW ( CAMW   ),  // CAM/pattern width
                   .PIPE ( PIPE   ),  // Pipelined? (binary; 0 or 1)
                   .INOM ( INOM   ))  // binary / Initial CAM with no match (has priority over IFILE)
      bcam_reg_i ( .clk  ( clk    ),  // clock
                   .rst  ( rst    ),  // global registers reset
                   .wEnb ( wEnbI  ),  // write enable
                   .wAddr( wAddrI ),  // write address
                   .wPatt( wPattI ),  // write pattern
                   .mPatt( mPattI ),  // patern to match
                   .match( matchI ),  // match indicator
                   .mAddr( mAddrI )); // matched address
    end
    else if (TYPE=="TRS") begin
      // instantiate transposed-RAM stage BCAM (TRS)
      bcam_trc  #( .CAMD ( CAMD   ),  // CAM depth
                   .CAMW ( CAMW   ),  // CAM/pattern width
                   .STGW ( 524288 ),  // maximum stage width (9 for M20k; infinity for uncascaded) - allow STGW+1 for last stage if required
                   .BYPS ( BYPS   ),  // Bypassed?  (binary; 0 or 1)
                   .PIPE ( PIPE   ),  // Pipelined? (binary; 0 or 1)
                   .INOM ( INOM   ),  // binary / Initial CAM with no match (has priority over IFILE)
                   .BRAM ( BRAM   ))  // BRAM type- "M20K":Altera's M20K; "GEN":generic
      bcam_trs_i ( .clk  ( clk    ),  // clock
                   .rst  ( rst    ),  // global registers reset
                   .wEnb ( wEnbI  ),  // write enable
                   .wAddr( wAddrI ),  // write address
                   .wPatt( wPattI ),  // write pattern
                   .mPatt( mPattI ),  // patern to match
                   .match( matchI ),  // match indicator
                   .mAddr( mAddrI )); // matched address
    end
    else if (TYPE=="TRC") begin
      // instantiate transposed-RAM cascade BCAM (TRC)
      bcam_trc  #( .CAMD ( CAMD   ),  // CAM depth
                   .CAMW ( CAMW   ),  // CAM/pattern width
                   .STGW ( 9      ),  // maximum stage width (9 for M20k; infinity for uncascaded) - allow STGW+1 for last stage if required
                   .BYPS ( BYPS   ),  // Bypassed?  (binary; 0 or 1)
                   .PIPE ( PIPE   ),  // Pipelined? (binary; 0 or 1)
                   .INOM ( INOM   ),  // binary / Initial CAM with no match (has priority over IFILE)
                   .BRAM ( BRAM   ))  // BRAM type- "M20K":Altera's M20K; "GEN":generic
      bcam_trc_i ( .clk  ( clk    ),  // clock
                   .rst  ( rst    ),  // global registers reset
                   .wEnb ( wEnbI  ),  // write enable
                   .wAddr( wAddrI ),  // write address
                   .wPatt( wPattI ),  // write pattern
                   .mPatt( mPattI ),  // patern to match
                   .match( matchI ),  // match indicator
                   .mAddr( mAddrI )); // matched address
    end
    else begin // default: STRAM
      // instantiate segmented transposed-RAM BCAM (STRAM)
      bcam_str  #( .CAMD ( CAMD   ),  // CAM depth
                   .CAMW ( CAMW   ),  // CAM/pattern width
                   .SEGW ( SEGW   ),  // Segment width
                   .BYPS ( BYPS   ),  // Bypassed?  (binary; 0 or 1)
                   .PIPE ( PIPE   ),  // Pipelined? (binary; 0 or 1)
                   .INOM ( INOM   ),  // binary / Initial CAM with no match (has priority over IFILE)
                   .BRAM ( BRAM   ))  // BRAM type- "M20K":Altera's M20K; "GEN":generic
      bcam_str_i ( .clk  ( clk    ),  // clock
                   .rst  ( rst    ),  // global registers reset
                   .wEnb ( wEnbI  ),  // write enable
                   .wAddr( wAddrI ),  // write address
                   .wPatt( wPattI ),  // write pattern
                   .mPatt( mPattI ),  // patern to match
                   .match( matchI ),  // match indicator
                   .mAddr( mAddrI )); // matched address
    end
  endgenerate

  // register outputs 1
  reg             matchIR;
  reg [ADDRW-1:0] mAddrIR;
  always @(posedge clk, posedge rst)
    if (rst) {matchIR,mAddrIR} <= {(1     +ADDRW ){1'b0}};
    else     {matchIR,mAddrIR} <= { matchI,mAddrI       };

  // register outputs 2
  reg             matchIRR;
  reg [ADDRW-1:0] mAddrIRR;
  always @(posedge clk, posedge rst)
    if (rst) {matchIRR,mAddrIRR} <= {(1      +ADDRW  ){1'b0}};
    else     {matchIRR,mAddrIRR} <= { matchIR,mAddrIR       };

  // assign outputs
  assign match = PIPE ? matchIRR : ( REGO ? matchIR : matchI);
  assign mAddr = PIPE ? mAddrIRR : ( REGO ? mAddrIR : mAddrI);

endmodule

