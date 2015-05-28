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
//    bcam_tb.v:  A Test-bench for Binary Content Addressasble Memories (BCAM)    //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`timescale 1 ps/1 ps

`include "utils.vh"

// deine simulation mode
`define SIM

module bcam_tb;

  // simulation parameter
  localparam CAMD    = `CAMD      ; // memory depth
  localparam CAMW    = `CAMW      ; // data width
  localparam SEGW    = `SEGW      ; // segment width for Segmented Transposed-RAM implementation
  localparam CYCC    = `CYCC      ; // simulation cycles count
  localparam CYCT    = 10         ; // cycle      time
  localparam RSTT    = 5.2*CYCT   ; // reset      time
  localparam VERBOSE = 2          ; // verbose logging (0: no; 1: level 1; 2: level 2)
  localparam TERFAIL = 0          ; // terminate if fail?
  localparam TIMEOUT = 2*CYCT*CYCC; // simulation time
  localparam ADDRW   = `log2(CAMD); // CAM address width = log2 (CAM depth)

  // enumerate implementations
  localparam REG = 3'b000; // register-based
  localparam TRS = 3'b001; // transposed-RAM stage
  localparam TRC = 3'b010; // transposed-RAM cascade
  localparam STR = 3'b011; // segmented transposed-RAM
  localparam ALL = 3'b100; // all implementations

  reg  clk = 1'b0; // global clock
  reg  rst = 1'b1; // global reset
  reg  wEnb= 1'b0; // write enable

  reg  [CAMW -1:0] wPatt, mPatt; // patterns
  reg  [ADDRW-1:0] wAddr       ; // write address
  wire [ADDRW-1:0] mAddrBhv, mAddrReg, mAddrTRS, mAddrTRC, mAddrSTR; // match addresses
  wire             matchBhv, matchReg, matchTRS, matchTRC, matchSTR; // match indicators

  // registered outputs
  reg [ADDRW-1:0] mAddrRegR; // addresses
  reg             matchRegR; // match indicator


  integer cycc=0; // cycles count

  
  // generate clock and reset
  always  #(CYCT/2) clk = !clk; // toggle clock

  integer rep_fd, ferr;
  initial begin
    // lower reset
    #(RSTT  ) rst = 1'b0;
    //////////////////////////////////////////////
    // print header to results file
    rep_fd = $fopen("sim.res","r"); // try to open report file for read
    $ferror(rep_fd,ferr);       // detect error
    $fclose(rep_fd);
    rep_fd = $fopen("sim.res","a+"); // open report file for append
    if (ferr) begin     // if file is new (can't open for read); write header
      $fwrite(rep_fd,"* REG: Register-based Binary Content Addressasble Memory\n");
      $fwrite(rep_fd,"* TRS: Transposed-RAM Binary Content Addressasble Memory stage\n");
      $fwrite(rep_fd,"* TRC: Transposed-RAM Binary Content Addressasble Memory cascade\n");
      $fwrite(rep_fd,"* STR: Segmented Transposed-RAM Binary Content Addressasble Memory\n\n");
      $fwrite(rep_fd,"BCAM  Architectural  Parameters   # Simulation Mismatches\n");
      $fwrite(rep_fd,"===============================   =======================\n");
      $fwrite(rep_fd,"CAM     Pattern Segment Simula.   REG   TRS   TRC   STR  \n");
      $fwrite(rep_fd,"Depth   Width   Width   Cycles                           \n");
      $fwrite(rep_fd,"=========================================================\n");
    end
    // print header
    $write("Simulating BAM with the following parameters:\n");
    $write("CAM depth            : %0d\n",CAMD);
    $write("Pattern width        : %0d\n",CAMW);
    $write("Segment width (STRAM): %0d\n",SEGW);
    $write("Simulation Cycles    : %0d\n",CYCC);
    // print header if no verbose
    if (VERBOSE==1)
      $write("\n                      1k         2k         3k         4k         5k         6k         7k         8k         9k         ");
  end

  reg [5:0] pass; // result for each implementation 
  integer failCntReg = 0; // failures count
  integer failCntTRS = 0; // failures count
  integer failCntTRC = 0; // failures count
  integer failCntSTR = 0; // failures count
  integer failCntAll = 0; // failures count
  integer failCntTmp = 0; // failures count / temporal/ per few cycles
  always @(negedge clk) begin
    if (!rst) begin

      // Generate random inputs
      if ( !wEnb) begin
        `GETRAND( wEnb,1    );
        `GETRAND(wAddr,ADDRW);
        `GETRAND(wPatt,CAMW );
      end else wEnb = 1'b0;
      `GETRAND(mPatt,CAMW );

      // write input data
      if (VERBOSE==2) $write("%-7d: ",cycc);
      #(CYCT/10) // a little after falling edge
      if (VERBOSE==2) $write("Before rise: wEnb=%h; wAddr=%h; wPatt=%h; mPatt=%h --- ",wEnb,wAddr,wPatt,mPatt);
      #(CYCT/2) // a little after rising edge
      if (VERBOSE==2) $write("After rise: match=(%b,%b,%b,%b,%b); mAddr=(%h,%h,%h,%h,%h) --- ",matchBhv,matchRegR,matchTRS,matchTRC,matchSTR,mAddrBhv,mAddrRegR,mAddrTRS,mAddrTRC,mAddrSTR);
      pass[REG] = !(matchBhv || matchRegR) || (matchBhv && matchRegR && (mAddrBhv===mAddrRegR));
      pass[TRS] = !(matchBhv || matchTRS ) || (matchBhv && matchTRS  && (mAddrBhv===mAddrTRS ));
      pass[TRC] = !(matchBhv || matchTRC ) || (matchBhv && matchTRC  && (mAddrBhv===mAddrTRC ));
      pass[STR] = !(matchBhv || matchSTR ) || (matchBhv && matchSTR  && (mAddrBhv===mAddrSTR ));
      pass[ALL] = pass[REG] && pass[TRS] && pass[TRC] && pass[STR];
      if (!pass[REG]) failCntReg = failCntReg + 1;
      if (!pass[TRS]) failCntTRS = failCntTRS + 1;
      if (!pass[TRC]) failCntTRC = failCntTRC + 1;
      if (!pass[STR]) failCntSTR = failCntSTR + 1;
      if (!pass[ALL]) failCntAll = failCntAll + 1;
      failCntTmp = failCntAll          ;
      if (VERBOSE==2) $write("%s\n",pass[ALL]?"Pass":"Fail");
      if (VERBOSE==1) begin
        if ((cycc%10000)==0)  $write("\n%4d X 10k: ",cycc/10000);
        else if ((cycc%1000 )==0) $write("|");
        if ((cycc%100  )==0) begin
          if (failCntTmp>0) $write("x"); else $write("-");
        end
        failCntTmp = 0;
      end
      // finish if terminate on any failure
      if (TERFAIL && (!pass[ALL])) begin
        $write("*** Simulation terminated due to output mismatch\n");
        $fclose(rep_fd);
        $finish;
      end
      if (cycc==CYCC) begin
        // write to report file
        $fwrite(rep_fd,"%-7d %-7d %-7d %-7d   %-5d %-5d %-5d %-5d\n",CAMD,CAMW,SEGW,CYCC,failCntReg,failCntTRS,failCntTRC,failCntSTR);
        // write to STDOUT
        $write("\n*** Simulation terminated after %0d cycles with %0d failures. Results:\n",CYCC,failCntAll);
        $write("REG = %-5d mismatches\n",failCntReg);
        $write("TRS = %-5d mismatches\n",failCntTRS);
        $write("TRC = %-5d mismatches\n",failCntTRC);
        $write("STR = %-5d mismatches\n",failCntSTR);
        $fclose(rep_fd);
        $finish;
      end
      cycc=cycc+1;
    end
  end

  // Behavioral BCAM
  bcam      #( .CAMD ( CAMD     ),  // CAM depth
               .CAMW ( CAMW     ),  // CAM/pattern width
               .INOM ( 1        ),  // binary / Initial CAM with no match (has priority over IFILE)
               .REGW ( 1        ),  // binary / register write inputs wEnb, wAddr, & wPatt?
               .REGM ( 0        ),  // binary / register match input mPatt?
               .REGO ( 1        ),  // binary / register outputs match & mAddr?
               .TYPE ( "BHV"    ))  // implementation type: BHV, REG, TRAM, STRAM
  bcam_bhv_i ( .clk  ( clk      ),  // clock
               .rst  ( rst      ),  // global registers reset
               .wEnb ( wEnb     ),  // write enable
               .wAddr( wAddr    ),  // write address
               .wPatt( wPatt    ),  // write pattern
               .mPatt( mPatt    ),  // patern to match
               .match( matchBhv ),  // match indicator
               .mAddr( mAddrBhv )); // matched address

  // Register-based BCAM
  bcam      #( .CAMD ( CAMD     ),  // CAM depth
               .CAMW ( CAMW     ),  // CAM/pattern width
               .INOM ( 1        ),  // binary / Initial CAM with no match (has priority over IFILE)
               .REGW ( 0        ),  // binary / register write inputs wEnb, wAddr, & wPatt?
               .REGM ( 0        ),  // binary / register match input mPatt?
               .REGO ( 1        ),  // binary / register outputs match & mAddr?
               .TYPE ( "REG"    ))  // implementation type: BHV, REG, TRAM, STRAM
  bcam_reg_i ( .clk  ( clk      ),  // clock
               .rst  ( rst      ),  // global registers reset
               .wEnb ( wEnb     ),  // write enable
               .wAddr( wAddr    ),  // write address   / [`log2(CAMD)-1:0]
               .wPatt( wPatt    ),  // write pattern   / [      CAMW -1:0]
               .mPatt( mPatt    ),  // patern to match / [      CAMW -1:0]
               .match( matchReg ),  // match indicator
               .mAddr( mAddrReg )); // matched address / [`log2(CAMD)-1:0]

  // Transposed-RAM stage (Brute-Force) BCAM
  bcam      #( .CAMD ( CAMD     ),  // CAM depth
               .CAMW ( CAMW     ),  // CAM/pattern width
               .INOM ( 1        ),  // binary / Initial CAM with no match (has priority over IFILE)
               .REGW ( 0        ),  // binary / register write inputs wEnb, wAddr, & wPatt?
               .REGM ( 0        ),  // binary / register match input mPatt?
               .REGO ( 1        ),  // binary / register outputs match & mAddr?
               .BRAM ( "M20K"   ),  // BRAM type- "M20K":Altera's M20K; "GEN":generic
               .TYPE ( "TRS"    ))  // implementation type: BHV, REG, TRAM, STRAM
  bcam_trs_i ( .clk  ( clk      ),  // clock
               .rst  ( rst      ),  // global registers reset
               .wEnb ( wEnb     ),  // write enable
               .wAddr( wAddr    ),  // write address   / [`log2(CAMD)-1:0]
               .wPatt( wPatt    ),  // write pattern   / [      CAMW -1:0]
               .mPatt( mPatt    ),  // patern to match / [      CAMW -1:0]
               .match( matchTRS ),  // match indicator
               .mAddr( mAddrTRS )); // matched address / [`log2(CAMD)-1:0]

  // Transposed-RAM cascade (Brute-Force) BCAM
  bcam      #( .CAMD ( CAMD     ),  // CAM depth
               .CAMW ( CAMW     ),  // CAM/pattern width
               .INOM ( 1        ),  // binary / Initial CAM with no match (has priority over IFILE)
               .REGW ( 0        ),  // binary / register write inputs wEnb, wAddr, & wPatt?
               .REGM ( 0        ),  // binary / register match input mPatt?
               .REGO ( 1        ),  // binary / register outputs match & mAddr?
               .BRAM ( "M20K"   ),  // BRAM type- "M20K":Altera's M20K; "GEN":generic
               .TYPE ( "TRC"    ))  // implementation type: BHV, REG, TRAM, STRAM
  bcam_trc_i ( .clk  ( clk      ),  // clock
               .rst  ( rst      ),  // global registers reset
               .wEnb ( wEnb     ),  // write enable
               .wAddr( wAddr    ),  // write address   / [`log2(CAMD)-1:0]
               .wPatt( wPatt    ),  // write pattern   / [      CAMW -1:0]
               .mPatt( mPatt    ),  // patern to match / [      CAMW -1:0]
               .match( matchTRC ),  // match indicator
               .mAddr( mAddrTRC )); // matched address / [`log2(CAMD)-1:0]

  // Segmented Transposed-RAM BCAM
  bcam      #( .CAMD ( CAMD     ),  // CAM depth
               .CAMW ( CAMW     ),  // CAM/pattern width
               .SEGW ( SEGW     ),  // Segment width
               .INOM ( 1        ),  // binary / Initial CAM with no match (has priority over IFILE)
               .REGW ( 0        ),  // binary / register write inputs wEnb, wAddr, & wPatt?
               .REGM ( 0        ),  // binary / register match input mPatt?
               .REGO ( 0        ),  // binary / register outputs match & mAddr?
               .BRAM ( "M20K"   ),  // BRAM type- "M20K":Altera's M20K; "GEN":generic
               .TYPE ( "STRAM"  ))  // implementation type: BHV, REG, TRAM, STRAM
  bcam_str_i ( .clk  ( clk      ),  // clock
               .rst  ( rst      ),  // global registers reset
               .wEnb ( wEnb     ),  // write enable
               .wAddr( wAddr    ),  // write address   / [`log2(CAMD)-1:0]
               .wPatt( wPatt    ),  // write pattern   / [      CAMW -1:0]
               .mPatt( mPatt    ),  // patern to match / [      CAMW -1:0]
               .match( matchSTR ),  // match indicator
               .mAddr( mAddrSTR )); // matched address / [`log2(CAMD)-1:0]

  // Register outputs / second stage
  always @(posedge clk, posedge rst)
    if (rst) {mAddrRegR,matchRegR} <= {(ADDRW   +1       ){1'b0}};
    else     {mAddrRegR,matchRegR} <= { mAddrReg,matchReg       };

endmodule
