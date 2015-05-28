#!/bin/csh -f

####################################################################################
## Copyright (c) 2014, University of British Columbia (UBC)  All rights reserved. ##
##                                                                                ##
## Redistribution  and  use  in  source   and  binary  forms,   with  or  without ##
## modification,  are permitted  provided that  the following conditions are met: ##
##   * Redistributions   of  source   code  must  retain   the   above  copyright ##
##     notice,  this   list   of   conditions   and   the  following  disclaimer. ##
##   * Redistributions  in  binary  form  must  reproduce  the  above   copyright ##
##     notice, this  list  of  conditions  and the  following  disclaimer in  the ##
##     documentation and/or  other  materials  provided  with  the  distribution. ##
##   * Neither the name of the University of British Columbia (UBC) nor the names ##
##     of   its   contributors  may  be  used  to  endorse  or   promote products ##
##     derived from  this  software without  specific  prior  written permission. ##
##                                                                                ##
## THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ##
## AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE ##
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE ##
## DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE ##
## FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL ##
## DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR ##
## SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER ##
## CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, ##
## OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE ##
## OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. ##
####################################################################################

####################################################################################
##                   bcam.sdc: Synopsys design constraints file                   ##
##                   Design constraints and  timing assignments                   ##
##                                                                                ##
##   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   ##
##    SRAM-based 2D BCAM; The University of British Columbia (UBC), April 2014    ##
####################################################################################

# Clock constraints
create_clock -name "clk" -period 1.000ns [get_ports {clk}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# tsu/th constraints
#set_input_delay -clock "clk" -max 0.8ns [get_ports {wAddr}] 
#set_input_delay -clock "clk" -min 0.100ns [get_ports {wAddr}] 


# tco constraints
#set_output_delay -clock "clk" -max 0.8ns [get_ports {mAddr}] 
#set_output_delay -clock "clk" -min -0.100ns [get_ports {mAddr}] 

# disable input/output combinatorial timing (all ports are registered)
set_disable_timing -from [all_inputs]  *
set_disable_timing -to   [all_outputs] *
