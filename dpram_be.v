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
//                 dpram_be.v: Dual-ported RAM with byte-enable                   //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module dpram_be
 #( parameter MEMD  = 8*1024, // memory depth
    parameter DATAW = 90    , // data width; a multiply of BYTEW
    parameter BYTEW = 9     , // byte (segment) width
    parameter IZERO = 0     , // binary / Initial RAM with zeros (has priority over IFILE)
    parameter IFILE = ""    )  // initialization hex file (don't pass extension), optional
  ( input                    clk   ,  // clock
    input                    rst   ,  // global registers reset
    // Port A - True port; write with byte-enable or full width read
    input                    wEnbA ,  // write enable for port A
    input  [DATAW/BYTEW-1:0] bEnbA ,  // byte-enable  for port A (one-hot) / [DATAW/BYTEW-1:0]
    input  [`log2(MEMD)-1:0] addrA ,  // read/write addresses              / [`log2(MEMD)-1:0]
    input  [BYTEW      -1:0] wDataA,  // write data                        / [DATAW      -1:0]
    output [DATAW      -1:0] rDataA,  // read  data                        / [DATAW      -1:0]
    // Port B - read only
    input  [`log2(MEMD)-1:0] rAddrB , // read address                      / [`log2(MEMD)-1:0]
    output [DATAW      -1:0] rDataB); // read data                         / [DATAW      -1:0]


  localparam nBYTE = DATAW/BYTEW; // number of byte slices
  localparam ADDRW = `log2(MEMD); // address width

  // outputs for M20K bytes
  wire [nBYTE*10-1:0] rDataA10;
  wire [nBYTE*10-1:0] rDataB10;

  // generate and instantiate true dual-ported RAM
  genvar bi;
  generate
    // M20K byte width is 8 or 10 bits; if BYTEW>10, use the entire M20K block, otherwise use internal M20K byte enables
    if ( (BYTEW>10) || (MEMD>1024) )
      for (bi=0 ; bi<nBYTE ; bi=bi+1) begin: M20K1Ebi
        tdpram #( .MEMD  ( MEMD                      ), // memory depth
                  .DATAW ( BYTEW                     ), // data width
                  .IZERO ( IZERO                     ), // binary / Initial RAM with zeros (has priority over IFILE)
                  .IFILE ( IFILE                     ))  // initialization hex file (don't pass extension), optional
        tdprami ( .clk   ( clk                       ),  // clock
                  .wEnbA ( wEnbA && bEnbA[bi]        ),  // write enable for port A
                  .wEnbB ( 1'b0                      ),  // write enable for port B
                  .addrA (  addrA                    ),  // write addresses - packed from nWPORTS write ports / [`log2(MEMD)-1:0]
                  .addrB ( rAddrB                    ),  // write addresses - packed from nWPORTS write ports / [`log2(MEMD)-1:0]
                  .wDataA( wDataA                    ),  // write data      - packed from nRPORTS read ports / [DATAW      -1:0]
                  .wDataB( {BYTEW{1'b1}}             ),  // write data      - packed from nRPORTS read ports / [DATAW      -1:0]
                  .rDataA( rDataA[bi*BYTEW +: BYTEW] ),  // read  data      - packed from nRPORTS read ports / [DATAW  -1:0]
                  .rDataB( rDataB[bi*BYTEW +: BYTEW] )); // read  data      - packed from nRPORTS read ports / [DATAW  -1:0]
      end
    else // BYTEW<=10 && MEMD<=1024
      for (bi=0 ; bi<(nBYTE/2) ; bi=bi+1) begin: M20K2Ebi
        altsyncram   #( .address_reg_b                      ( "CLOCK0"               ),
                        .byte_size                          ( 10                     ),
                        .clock_enable_input_a               ( "BYPASS"               ),
                        .clock_enable_input_b               ( "BYPASS"               ),
                        .clock_enable_output_a              ( "BYPASS"               ),
                        .clock_enable_output_b              ( "BYPASS"               ),
                        .indata_reg_b                       ( "CLOCK0"               ),
                        .intended_device_family             ( "Stratix V"            ),
                        .lpm_type                           ( "altsyncram"           ),
                        .numwords_a                         ( 1024                   ),
                        .numwords_b                         ( 1024                   ),
                        .operation_mode                     ( "BIDIR_DUAL_PORT"      ),
                        .outdata_aclr_a                     ( "CLEAR0"               ),
                        .outdata_aclr_b                     ( "CLEAR0"               ),
                        .outdata_reg_a                      ( "UNREGISTERED"         ),
                        .outdata_reg_b                      ( "UNREGISTERED"         ),
                        .power_up_uninitialized             ( "FALSE"                ),
                        .ram_block_type                     ( "M20K"                 ),
                        .read_during_write_mode_mixed_ports ( "OLD_DATA"             ),
                        .read_during_write_mode_port_a      ( "NEW_DATA_NO_NBE_READ" ),
                        .read_during_write_mode_port_b      ( "NEW_DATA_NO_NBE_READ" ),
                        .widthad_a                          ( 10                     ),
                        .widthad_b                          ( 10                     ),
                        .width_a                            ( 20                     ),
                        .width_b                            ( 20                     ),
                        .width_byteena_a                    ( 2                      ),
                        .width_byteena_b                    ( 1                      ),
                        .wrcontrol_wraddress_reg_b          ( "CLOCK0"               ))
        altsyncram_be ( .byteena_a      ( bEnbA[bi*2 +: 2]      ),
                        .clock0         ( clk                   ),
                        .wren_a         ( wEnbA                 ),
                        .address_b      ( `ZPAD(rAddrB,10)      ),
                        .data_b         ( 20'b1                 ),
                        .wren_b         ( 1'b0                  ),
                        .aclr0          ( rst                   ),
                        .address_a      ( `ZPAD(addrA,10)       ),  
                        .data_a         ( {2{`ZPAD(wDataA,10)}} ),
                        .q_a            ( rDataA10[bi*20 +: 20] ),
                        .q_b            ( rDataB10[bi*20 +: 20] ),
                        .aclr1          ( 1'b0                  ),
                        .addressstall_a ( 1'b0                  ),
                        .addressstall_b ( 1'b0                  ),
                        .byteena_b      ( 1'b1                  ),
                        .clock1         ( 1'b1                  ),
                        .clocken0       ( 1'b1                  ),
                        .clocken1       ( 1'b1                  ),
                        .clocken2       ( 1'b1                  ),
                        .clocken3       ( 1'b1                  ),
                        .eccstatus      (                       ),
                        .rden_a         ( 1'b1                  ),
                        .rden_b         ( 1'b1                  ));
        assign rDataA[bi*BYTEW*2+BYTEW +: BYTEW] = rDataA10[bi*20+10 +: BYTEW];
        assign rDataA[bi*BYTEW*2       +: BYTEW] = rDataA10[bi*20    +: BYTEW];
        assign rDataB[bi*BYTEW*2+BYTEW +: BYTEW] = rDataB10[bi*20+10 +: BYTEW];
        assign rDataB[bi*BYTEW*2       +: BYTEW] = rDataB10[bi*20    +: BYTEW];
      end
  endgenerate

endmodule
