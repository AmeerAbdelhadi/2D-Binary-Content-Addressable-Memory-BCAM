## Modular SRAM-based 2D  Hierarchical-Search ##
## Binary Content Addressable Memory (BCAM) ##
---
## Ameer  M. S.  Abdelhadi and Guy  G. F.  Lemieux ##
## The University of British Columbia (UBC)  2014 ##
## { ameer.abdelhadi; guy.lemieux } @ gmail.com ##
---

A fully parameterized and generic Verilog implementation of the suggested modular SRAM-based 2D hierarchical-search Binary Content Addressable Memory (BCAM), together with other approaches are provided as open source hardware. A run-in-batch flow manager to simulate and synthesize various designs with various parameters in batch using Altera's ModelSim and Quartus is also provided.

**LICENSE:** BSD 3-Clause ("BSD New" or "BSD Simplified") license.

Please refer to the full paper for more information:

**A. M.S. Abdelhadi and G. G.F. Lemieux, "Deep and Narrow Binary Content-Addressable Memories using FPGA-based BRAMs," International Conference on Field-Programmable Technology (FPT), December, 2014.**
* **DOI:** http://dx.doi.org/10.1109/FPT.2014.7082808
* **Paper** https://www.ece.mcmaster.ca/~ameer/publications/Abdelhadi-Conference-2014Dec-FPT2014-DeepandNarrowBCAMs-full.pdf


---


## CAD Tools Requirements ##
This project has been tested intensively using Altera's Design Suite version 14.0 Specifically:
  1. Quartus II version 14.0 has been used to synthesize the Verilog implementation
  2. ModelSim Altera Edition version 10.0d (modelsim\_ase) has been used to simulate the Verilog implementation.

Furthermore, the run-in-batch synthesis and simulation flow managers have been implemented using C-Shell, hence a /bin/csh should be available in the machine


---


## Files and directories in this package ##

  * **README:** This file!
  * **LICENSE:** BSD 3-Clause ("BSD New" or "BSD Simplified") license
  * **fpt2014-paper.pdf:** The 2014 Int'l Conf. on Field-Programmable Tech. (ICFPT) paper
  * **fpt2014-slides.pdf:** The 2014 Int'l Conf. on Field-Programmable Tech. (ICFPT) slides
  * **sim:** C-shell script: A run-in-batch simulation flow manager
  * **syn:** C-shell script: A run-in-batch synthesis  flow manager
  * **mux:** C-shell script: Wide pipelined multiplexer generator
  * **pe:** C-shell script: Priority-encoder recursive generator
  * **reduction:**C-shell script: Wide pipelined reduction function generator
  * **bcam.qpf:**Quartus II project file
  * **bcam.qsf:**Quartus II settings file
  * **bcam.sdc:**Synopsys design constraints file; Design constraints and timing assignments
  * **config.vh:**Verilog: Generated by 'syn', contains design parameters
  * **utils.vh:** Verilog: Design pre-compile utilities
  * **bcam_reg.v:** Verilog: Register-based BCAM
  * **bcam_bhv.v:** Verilog: Behavioral description of BCAM
  * **bcam_str.v:** Verilog: Segmented Transposed-RAM BCAM
  * **bcam_tb.v:** Verilog: A Test-bench for BCAM
  * **bcam_trc.v:** Verilog: Brute-force/Transposed-RAM BCAM cascade
  * **bcam_trs.v:** Verilog: Brute-force/Transposed-RAM BCAM stage
  * **bcam.v:** Verilog: Binary Content Addressable Memory (BCAM) wrapper for: Behavioral (BHV), reg-based (REG), transposed-RAM stage (TRS), transposed-RAM cascade (TRC) & segmented transposed-RAM (STR)
  * **dpram_be.v:** Verilog: Dual-ported RAM with byte-enable
  * **mwram_gen.v:** Verilog: Generic mixed width RAM; not synthesizable with Altera's devices. May not be synthesizable with other vendors; Check your vendor's recommended HDL coding style
  * **mwram_m20k.v:** Verilog: Altera's M20K mixed width RAM
  * **sbram_m20k.v:** Verilog: Single-bit width RAM using Altera's M20K
  * **spram.v:** Verilog: Generic single port RAM
  * **tdpram.v:** Verilog: Generic true dual-ported RAM with data flow-through
  * **trcam.v:** Verilog: Transposed-RAM Stage CAM Core 
  * **sim.res:** A list of simulation results, each run in a separate line, including all architectures
  * **syn.res:** A list of synthesis results, each run in a separate line, including: frequency, resources usage, and runtime
  * **log/:** A directory containing Altera's logs and reports


---


## 2D BCAM module instantiation ##
All **.v &**.vh files in this package should be copied into your work directory. Copy the following instantiation into your Verilog design, change parameters and connectivity to fit your design.

```
  // instantiate a 2D BCAM
  bcam #( 
    // parameters
    .CAMD ( CAMD ), // CAM depth
    .CAMW ( CAMW ), // CAM/pattern width
    .SEGW ( SEGW ), // Segment width
    .INOM ( INOM ), // binary / Initial CAM with no match (has priority over IFILE)
    .REGW ( REGW ), // binary / register write inputs wEnb, wAddr, & wPatt?
    .REGM ( REGM ), // binary / register match input mPatt?
    .REGO ( REGO ), // binary / register outputs match & mAddr?
    .BRAM ( BRAM ), // BRAM type- "M20K":Altera's M20K; "GEN":generic
    .TYPE ( TYPE )  // implementation type: BHV, REG, TRAM, STRAM
  ) bcam_inst (
    // ports
    .clk  ( clk    ), // clock                  / in
    .rst  ( rst    ), // global registers reset / in
    .wEnb ( wEnb   ), // write enable           / in
    .wAddr( wAddr  ), // write address          / in: [`log2(CAMD)-1:0]
    .wPatt( wPatt  ), // write pattern          / in : [      CAMW -1:0]
    .mPatt( mPatt  ), // patern to match        / in : [      CAMW -1:0]
    .match( match  ), // match indicator        / out:
    .mAddr( mAddr  )  // matched address        / out: [`log2(CAMD)-1:0]
  );
```


---


## `sim`: A Run-in-batch Simulation Flow Manager ##

### USAGE: ###

    `./sim <CAM Depth List> <Pattern Width List> <Segment Width List> <#Cycles>`

  * Use a comma delimited list; no space; can be surrounded by brackets (), [], {}, <>
  * CAM depth, pattern width, segment width and cycles are positive integers

### EXAMPLES: ###

  * `./sim 8192 9 8 1000000`
    * Simulate 1M cycles of a 8K lines CAM, 9 bits pattern width, 8 bits segments
  * `./sim 2048,4096 8,9,10 8,16 1000000`
    * Simulate 1M cycles of CAMs with 2k or 4k lines, 8, 9, or 10 bits pattern, 8 or 16 bits segment. Total of 12 CAM combinations

The following files and directories will be created after simulation :
  * sim.res : A list of simulation results, each run in a separate line, including all design styles.


---


## `syn`: A Run-in-batch Synthesis Flow Manager ##

### USAGE: ###

    `./syn <Architecture List> <Depth List> <Pattern Width List> <Segment Width List> <Bypassed? List> <Pipelined? List>`

  * Use a comma delimited list; no space; can be surrounded by brackets (), [], {}, <>
  * CAM depth, pattern width and segment width are positive integers
  * Segments width list will be igonred for all architictures except of STR
  * Architecture is one of: REG, TRS, TRC, or STR
    * REG: Register-based Binary Content Addressable Memory
    * TRS: Transposed-RAM Binary Content Addressable Memory
    * TRC: Transposed-RAM Binary Content Addressable Memory
    * STR: Segmented Transposed-RAM Binary Content Addressable Memory
    * Bypassed?  bypassed write to achieve match in the next cycle (Binary; 0/1)
    * Pipelined? bypassed BCAM version (Binary; 0/1)

### EXAMPLES: ###

  * `./syn STR 8192 9 8 0 0`
    * Synthesis an unpipelined/unbypassed STR BCAM with 8K lines, 9 bits pattern width, and 8 bits segments width.
  * `./syn REG,TRC 2048,4096 8,9,10 8 1 1`
    * Synthesis a pipelined/bypassed reg-based/TRC BCAM with 2k or 4k lines, 8, 9 or 10 bits pattern. Segment width is ignored. Total of 6 CAM combinations.

The following files and directories will be created after compilation:
  * syn.res : A list of results, each run in a separate line, including: frequency, resources usage, and runtime
  * log/    : Altera's logs and reports
