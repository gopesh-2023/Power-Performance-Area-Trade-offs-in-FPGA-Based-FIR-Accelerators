# Power-Performance-Area-Trade-offs-in-FPGA-Based-FIR-Accelerators
The deployment of computationally intensive workloads in edge computing and high-speed
communication systems is severely bottlenecked by the reliance on hardware multipliers. On
Field Programmable Gate Arrays (FPGAs), conventional Multiply-Accumulate (MAC) arrays
rapidly exhaust dedicated Digital Signal Processing (DSP) slices, introduce deep critical path
delays, and consume prohibitive amounts of dynamic power. This thesis presents a
comprehensive Design Space Exploration (DSE) of multiplier-free datapath architectures to
systematically optimize the Power-Performance-Area (PPA) envelope. Six distinct hardware
models, spanning conventional pipelined MACs to Canonical Signed Digit (CSD) shift-andadd
structures, were designed at the Register Transfer Level (RTL) and post-route verified on
the AMD Xilinx Artix-7 FPGA.
As a primary contribution, this work provides the FPGA post-routing validation of an advanced
Approximate Distributed Arithmetic (DA) architecture. By unifying input truncation, Radix-8
Booth Encoding, and an Approximate Wallace Tree constructed from Lower-part OR Adders
(LOA), the carry-propagation chains in the Least Significant Bits (LSBs) are structurally
eliminated. Post-implementation results demonstrate that this approximate architecture
consumes zero DSP slices and requires only 0.078% of available Look-Up Tables (LUTs).
Furthermore, a throughput-aware evaluation exposes the performance illusion of conventional
time-multiplexed MAC designs: while a folded MAC achieves a 207.9 MHz raw frequency,
its multi-cycle nature throttles effective throughput to just 25.99 Mega-Samples Per Second
(MSPS). In contrast, the fully parallel Approximate DA datapath achieves a maximum
operating frequency of 166.0 MHz and delivers a true single-cycle throughput of 166.0 MSPS,
while minimizing dynamic logic power to under 1 milliwatt. Ultimately, this research proves
that strategically trading exact mathematical precision for approximate logic yields highly
scalable, energy-efficient, and DSP-free datapath accelerators ideal for resource-constrained
edge environments.
