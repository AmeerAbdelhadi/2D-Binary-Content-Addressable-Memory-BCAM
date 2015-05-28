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
// bcam_str.v: Segmented Transposed-RAM Binary Content Addressasble Memory (BCAM) //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module bcam_str
 #( parameter                CAMD = 16384 ,  // CAM depth / a multiply of SEGW
    parameter                CAMW = 9     ,  // CAM/pattern width
    parameter                SEGW = 8     ,  // Segment width
    parameter                BYPS = 1     ,  // Bypassed?  (binary; 0 or 1)
    parameter                PIPE = 0     ,  // Pipelined? (binary; 0 or 1)
    parameter                INOM = 1     ,  // binary / Initial CAM with no match
    parameter                BRAM = "M20K")  // BRAM type- "M20K":Altera's M20K; "GEN":generic
  ( input                    clk          ,  // clock
    input                    rst          ,  // global registers reset
    input                    wEnb         ,  // write enable
    input  [`log2(CAMD)-1:0] wAddr        ,  // write address
    input  [      CAMW -1:0] wPatt        ,  // write patterns
    input  [      CAMW -1:0] mPatt        ,  // patern to match
    output                   match        ,  // match indicator
    output [`log2(CAMD)-1:0] mAddr        ); // matched address

  localparam ADDRW = `log2(CAMD); // address width
  localparam nSEG  = CAMD / SEGW; // number of segments
  localparam SEGAW = `log2(nSEG); // Segment address width
  localparam BITAW = `log2(SEGW); // within segment bit address width

  ///////////////////////////////////////////////////////////////////////////////

  // split writting address into two parts
  // highert part for segments addressing and
  // lower part gor within segment addressing
  wire [SEGAW-1:0] wAddrH = wAddr[ADDRW-1:BITAW];
  wire [BITAW-1:0] wAddrL = wAddr[BITAW-1:0    ];

  // wAddrL one-hot decoder
  reg [SEGW-1:0] wAddrLOH;
  always @(*) begin
    wAddrLOH         = {SEGW{1'b0}};
    wAddrLOH[wAddrL] = 1'b1        ;
  end

  // first stage registering
  reg [BITAW-1:0] wAddrLR  ;
  reg [SEGW -1:0] wAddrLOHR;
  reg [SEGAW-1:0] wAddrHR  ;
  reg [CAMW -1:0] wPattR   ;
  reg [CAMW -1:0] mPattR   ;
  reg wEnbR                ;
  always @(posedge clk, posedge rst)
    if (rst) {wAddrLR,wAddrLOHR,wAddrHR,wPattR,mPattR,wEnbR} <= {{(BITAW + SEGW    + SEGAW +CAMW +CAMW + 1  ){1'b0}}};
    else     {wAddrLR,wAddrLOHR,wAddrHR,wPattR,mPattR,wEnbR} <= {  wAddrL, wAddrLOH, wAddrH,wPatt,mPatt,wEnb}        ;

  // second stage registering
  reg [CAMW-1:0] mPattRR;
  always @(posedge clk, posedge rst)
    if (rst) mPattRR <= {CAMW{1'b0}};
    else     mPattRR <= mPattR      ;

  ///////////////////////////////////////////////////////////////////////////////

  // Transposed RAM as a CAM

  wire [nSEG-1:0] matchSeg;
  reg wEnbCAM; // write enable for CAM / control signal generated by FSM
  reg addRmv ; // add or remove (inverted) pattern from CAM / control signal generated by FSM
  wire [CAMW-1:0] data2rmv ; // data to remove
  wire [CAMW-1:0] data2rmvI; // data to remove / internal / unregestered
  reg  [CAMW-1:0] data2rmvR; // data to remove / registered
  wire rmvSameAdd = !addRmv & (wPatt==data2rmv); // trying to remove same just added pattern

  trcam #( .CAMD ( nSEG                     ),  // CAM depth (power of 2)
           .CAMW ( CAMW                     ),  // CAM/pattern width / for one stage (<=14)
           .INOM ( INOM                     ),  // binary / Initial CAM with no match
           .BRAM ( BRAM                     ))  // BRAM type- "M20K":Altera's M20K; "GEN":generic
  trcami ( .clk  ( clk                      ),  // clock
           .rst  ( rst                      ),  // global registers reset
           .wEnb ( wEnbCAM & !(rmvSameAdd)  ),  // write enable
           .wrEr ( addRmv                   ),  // add or remove (inverted) pattern from CAM
           .wAddr( wAddrH                   ),  // write address   / in : [`log2(CAMD)-1:0]
           .wPatt( addRmv? wPatt : data2rmv ),  // write pattern   / in : [      CAMW -1:0]
           .mPatt( mPatt                    ),  // patern to match / in : [      CAMW -1:0]
           .match( matchSeg                 )); // match / one-hot / out: [      CAMD -1:0]

  ///////////////////////////////////////////////////////////////////////////////

  // Trace RAM - a dual-ported RAM with byte-enable

  wire [(CAMW+1)*SEGW-1:0] rDataB    ; // read data from portB
  wire [(CAMW+1)*SEGW-1:0] rDataA    ; // read data from portA
  reg  [ CAMW   *SEGW-1:0] rDataA_WOV; // read data from portA / without valid bits

  wire [SEGAW-1:0] mAddrHP; // match address   / higher part  / previous cycle
  reg  [SEGAW-1:0] mAddrHI; // internal mAddr  / higher part  / registered mAddrP
  wire             matchHP; // match indicator / previous cycle

  dpram_be #( .MEMD  ( nSEG                    ),  // memory depth
              .DATAW ( (CAMW+1)*SEGW           ),  // data width; a multiply of BYTEW / additional valid bit for each byte
              .BYTEW (  CAMW+1                 ),  // byte (segment) width            / additional valid bit for each byte
              .IZERO ( 1                       ),  // binary / Initial RAM with zeros (has priority over IFILE)
              .IFILE ( ""                      ))  // initialization hex file (don't pass extension), optional
  trram     ( .clk   ( clk                     ),  // clock
              .rst   (rst                      ),  // global registers reset
              // Port A - True port; write with byte-enable or full width read
              .wEnbA ( !addRmv                 ),  // write enable for port A           / in
              .bEnbA ( PIPE?wAddrLOHR:wAddrLOH ),  // byte-enable  for port A (one-hot) / in : [DATAW/BYTEW-1:0]
              .addrA ( wAddrH                  ),  // read/write addresses              / in : [`log2(MEMD)-1:0]
              .wDataA( {1'b1,wPatt}            ),  // write data, with active valid bit / in : [DATAW      -1:0]
              .rDataA( rDataA                  ),  // read  data                        / out: [DATAW      -1:0]
              // Port B - read only
              .rAddrB( mAddrHP                 ),  // read address                      / in : [`log2(MEMD)-1:0]
              .rDataB( rDataB                  )); // read data                         / out: [DATAW      -1:0]

  // remove valid bit (last bit of each CAMW+1 segment) from rDataA
  integer si;
  always @(*)
    for (si=0;si<SEGW;si=si+1)
       rDataA_WOV[CAMW*si +: CAMW] = rDataA[(CAMW+1)*si +: CAMW];
  ///////////////////////////////////////////////////////////////////////////////

  // priority encoder between segments (mAddr higher part); its width is nSEG = CAMD / SEGW
  // generated automatically by ./pe script
  wire [nSEG-1:0] matchSegMsked; // masked onehot match
  pe_nseg pe_nseg_inst (
    .clk( clk           ), // clock for pipelined priority encoder
    .rst( rst           ), // registers reset for pipelined priority encoder
    .oht( matchSegMsked ), // one-hot match input / in : [      nSEG -1:0]
    .bin( mAddrHP       ), // first match index   / out: [`log2(nSEG)-1:0]
    .vld( matchHP       )  // match indicator     / out
  );

  // register higher part of mAddr to match the timing of the lower part
  always @(posedge clk, posedge rst)
    if (rst) mAddrHI = {SEGAW{1'b0}};
    else     mAddrHI = mAddrHP      ;

  assign mAddr[ADDRW-1:BITAW] = mAddrHI;

  // register match indicator to match the timing of mAddr
  reg matchH;
  always @(posedge clk, posedge rst)
    if (rst) matchH = 1'b0  ;
    else     matchH = matchHP;

  ///////////////////////////////////////////////////////////////////////////////

  // priority encoder within segments (mAddr lower part)

  reg [SEGW-1:0] mAddrLOH; // lower part of mAaddr / one-hot
  always @(*)
    for (si=0;si<SEGW;si=si+1)
      mAddrLOH[si] = (rDataB[si*(CAMW+1) +: (CAMW+1)] == {1'b1,mPattRR});

  // priority encoder within segments (mAddr lower part); its width is SEGW
  // generated automatically by ./pe script
  wire matchL;
  pe_segw pe_segw_inst (
    .clk( clk              ), // clock for pipelined priority encoder
    .rst( rst              ), // registers reset for pipelined priority encoder
    .oht( mAddrLOH         ), // one-hot match input / in : [      ENCW -1:0]
    .bin( mAddr[BITAW-1:0] ), // first match index   / out: [`log2(ENCW)-1:0]
    .vld( matchL           )  // match indicator     / out
  );

  assign match = matchH && matchL;

  ///////////////////////////////////////////////////////////////////////////////

  // Generate data to remove and detect if segment match should be removed

  // MUX to get data to remove
  //PIPELINING: assign data2rmv = rDataA[wAddrLR*(CAMW+1) +: CAMW];
  // change behavioral mux into structual mux
  //assign data2rmvI = rDataA[wAddrLR*(CAMW+1) +: CAMW];
  mux_data2rmv mux_data2rmv_inst(clk,rst,rDataA_WOV,wAddrLR,data2rmvI);
  assign data2rmv  = PIPE ? data2rmvR : data2rmvI; //PIPELINING

  // data to remove locations / one-hot
  wire [SEGW-1:0] data2rmvLoc ;
  reg  [SEGW-1:0] data2rmvLocI; // internal / unregistered
  reg  [SEGW-1:0] data2rmvLocR; // registered
  always @(*)
    for (si=0;si<SEGW;si=si+1)
      //PIPELINING: data2rmvLoc[si] = (rDataA[si*(CAMW+1) +: (CAMW+1)] == {1'b1,data2rmv});
      data2rmvLocI[si] = (rDataA[si*(CAMW+1) +: (CAMW+1)] == {1'b1,data2rmv});
  assign data2rmvLoc = PIPE ? data2rmvLocR : data2rmvLocI; //PIPELINING

  // mask data2rmvLoc to eliminate current data location and check multiple occurrences of data to remove
  //PIPELINING wire multiOcc = | (data2rmvLoc & (~wAddrLOHR)); // data to remove has other occurrences in segment
  reg  multiOccR;

  // change behavioral reduction or into structual or tree
  //wire multiOccI = | (data2rmvLoc & (~wAddrLOHR)); // data to remove has other occurrences in segment
  reduction_or reduction_or_inst(clk,rst, data2rmvLoc & (~wAddrLOHR), multiOccI);

  wire multiOcc  = PIPE ? multiOccR : multiOccI; //PIPELINING

  // registering
  always @(posedge clk, posedge rst)
    if (rst) {data2rmvR,data2rmvLocR,multiOccR} <= {{CAMW{1'b0}},{SEGW{1'b0}}, 1'b0     };
    else     {data2rmvR,data2rmvLocR,multiOccR} <= {data2rmvI   ,data2rmvLocI, multiOccI};

  ///////////////////////////////////////////////////////////////////////////////

  // CAM bypassing

  // is bypass?
  // bypass to add match if registered write pattern equals to pattern to match
  // bypass to remove match if data2rmv equal mPatt and data2rmv is valid and has single occurrence
  wire isBypAdd = (wPattR  ==mPatt)                && wEnbR;
  wire isBypRmv = (data2rmv==mPatt) && (!multiOcc) && wEnbR;

  // register
  reg isBypAddR, isBypRmvR;
  reg [SEGAW-1:0] wAddrHRR;
  always @(posedge clk, posedge rst)
    if (rst) {wAddrHRR,isBypAddR,isBypRmvR} <= {{SEGAW{1'b0}},1'b0    ,1'b0    };
    else     {wAddrHRR,isBypAddR,isBypRmvR} <= {wAddrHR      ,isBypAdd,isBypRmv};

/////////////// retiming //////////////
//// will increase registers count ////

  // onehot registerd write address
  reg [nSEG-1:0] wAddrH1HotRR;
//always @(*) begin
//  wAddrH1HotRR           = 0   ;
//  wAddrH1HotRR[wAddrHRR] = 1'b1;
//end

  reg [nSEG-1:0] wAddrH1HotR;
  always @(*) begin
    wAddrH1HotR          = 0   ;
    wAddrH1HotR[wAddrHR] = 1'b1;
  end
  always @(posedge clk, posedge rst)
    if (rst) wAddrH1HotRR <= {nSEG{1'b0}};
    else     wAddrH1HotRR <= wAddrH1HotR ;

/////////////// retiming //////////////

  // masked onehot match
  assign  matchSegMsked =  BYPS ? (  isBypAddR ?               ( wAddrH1HotRR | matchSeg)
                                               : ( isBypRmvR ? (~wAddrH1HotRR & matchSeg) : matchSeg )  )
                                : matchSeg;

  ///////////////////////////////////////////////////////////////////////////////

  // Controller /  Mealy FSM
  // Inputs : wEnb  multiOcc
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
      S0: if (wEnb) {nxtStt,wEnbCAM,addRmv}={S1,1'b1     ,1'b1};
          else      {nxtStt,wEnbCAM,addRmv}={S0,1'b0     ,1'b1};
      S1: if (wEnb) {nxtStt,wEnbCAM,addRmv}={S0,!multiOcc,1'b0};
          else      {nxtStt,wEnbCAM,addRmv}={S0,!multiOcc,1'b0};
    endcase

endmodule
