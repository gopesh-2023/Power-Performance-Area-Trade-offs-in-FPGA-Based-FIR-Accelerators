# Chapter 2: Literature Review and Theoretical Background

## 2.1 The Direct-Form MAC Architecture: Foundations and Critical Path Bottlenecks

The Finite Impulse Response (FIR) filter computes the discrete-time convolution:

\[
y[n] = \sum_{k=0}^{N-1} h[k] \cdot x[n-k]
\]

where \(x[n]\) is the input signal, \(h[k]\) are the fixed filter coefficients, \(N\) is the filter order, and \(y[n]\) is the filter output. Each product term \(h[k] \cdot x[n-k]\) is a Multiply-Accumulate (MAC) operation, making the FIR datapath a canonical MAC-array structure and a standard benchmark for hardware accelerator evaluation.

The earliest and most direct hardware realization is the **Direct-Form MAC architecture**, in which a tapped delay line of \(N\) registers holds the \(N\) most recent input samples, each feeding a dedicated parallel hardware multiplier, with all multiplier outputs summed by a multi-operand adder tree. As established in standard FPGA design references [Meyer-Baese, 2014], the critical path of this architecture traverses the multiplier logic and then descends the full depth of the adder tree. For an N-tap parallel implementation, the adder tree requires \(\lceil\log_2 N\rceil\) stages; as N scales, the critical path grows logarithmically, directly limiting the maximum achievable clock frequency (F_max). For the 8-tap design evaluated in this work, this combinational depth is sufficient to cause a Worst Negative Slack (WNS) of −0.23 ns against a 10 ns timing constraint, corresponding to a post-routing F_max of only 97.75 MHz — a failure to achieve even the baseline 100 MHz target.

> **[Figure 2.1 — Direct-Form FIR Datapath Block Diagram]**
> *Draw the following:* Input `x[n]` arriving at a chain of N−1 registers (tapped delay line), each tap feeding into a dedicated multiplier with fixed coefficient `h[k]`. All N multiplier outputs feed into a binary adder tree (log₂N stages deep) producing `y[n]`. Annotate the "Critical Path" as a red arrow spanning the multiplier and full adder tree depth. This figure motivates the entire architectural design space explored in this thesis.

---

## 2.2 Conventional VLSI Optimizations: Pipelining and Coefficient Symmetry

### 2.2.1 Register Pipelining

Register pipelining inserts flip-flop barriers between arithmetic stages — specifically between the multiplier output and each adder tree level — to partition the combinational logic into shorter, time-bounded segments. This structural modification reduces the critical path delay seen within each pipeline stage, enabling timing closure at higher clock frequencies [Proakis and Manolakis, 2006]. The trade-off is a multi-cycle output latency equal to the pipeline depth and an increase in flip-flop (FF) resource consumption, which elevates dynamic power due to additional register toggling at every clock edge. Post-implementation results for the pipelined architecture in this work confirm an F_max of 149.32 MHz, but at the cost of 40 mW dynamic power and aggressive DSP slice consumption (1.081% of device total — an 8× escalation over the unpipelined baseline).

### 2.2.2 Coefficient Symmetry Exploitation

For filters with symmetric coefficients satisfying \(h[k] = h[N-1-k]\), the pre-addition of symmetric input pairs before the multiplier stage reduces the required number of multiplications by half. For an 8-tap symmetric design, this halves the DSP slice requirement from 8 to 4. Despite the area saving, this optimization retains fundamental dependence on hardware multipliers and provides no relief from the power penalties of DSP-slice-based arithmetic. Both pipelining and symmetry remain architecturally bounded by the multiplier: they optimize around it without eliminating it.

> **[Table 2.1 — Limitations of Conventional MAC Optimization Strategies]**

| Technique | Critical Path Effect | DSP Slices | Dynamic Power | Key Limitation |
|---|---|---|---|---|
| Direct-Form Baseline | Deepest — fails timing | 1 | 35 mW | WNS = −0.23 ns; fails 100 MHz |
| Register Pipelining | Severed — high F_max | 8 (8×) | 40 mW (highest) | DSP-intensive; power penalty |
| Coefficient Symmetry | Moderate reduction | 4 (4×) | 34 mW | Still DSP-dependent |
| Time-Multiplexed MAC | Minimal path depth | 1 | 35 mW | Throughput collapses to F_max/N |

---

## 2.3 Multiplier-Less Architectures: Shift-and-Add and Canonical Signed Digit Encoding

### 2.3.1 The Shift-and-Add Principle

The fundamental insight underlying multiplier-less design is that **multiplication by a fixed constant decomposes into a sequence of binary left-shifts and additions**. A left-shift by \(k\) bit positions is mathematically equivalent to multiplication by \(2^k\), and in digital hardware this operation requires no active logic gates — it is realized entirely through hard wire routing. Consequently, for any coefficient whose binary representation contains only a small number of non-zero bits, the hardware multiplier can be entirely replaced by a network of wire shifts and adders, eliminating all DSP slice dependency at the cost of some LUT-based adder logic.

For the 8-tap uniform datapath evaluated in this thesis, the fixed-point coefficient is `8'b00010000` (decimal 16 = \(2^4\)). Multiplication by this coefficient reduces to a single 4-bit left-shift: `y = x << 4`. This hardwired shift requires zero LUTs, zero DSPs, and zero switching power — confirming the architectural validity of multiplier-less design for power-of-two coefficients.

### 2.3.2 Canonical Signed Digit Encoding

For arbitrary non-power-of-two coefficients, **Canonical Signed Digit (CSD) encoding** [Samueli, 1989] provides the minimum-non-zero-digit binary representation. CSD extends the digit alphabet from \(\{0, 1\}\) to \(\{0, 1, \bar{1}\}\) (where \(\bar{1}\) denotes −1). The defining property of CSD is that **no two consecutive digits are non-zero**, which is mathematically guaranteed to minimize the number of non-zero digits in any integer's representation. Since each non-zero digit corresponds to one addition or subtraction operation in the shift-and-add tree, CSD encoding directly minimizes the number of adder stages required to compute the multiplication.

> **[Figure 2.2 — Standard Binary vs. CSD Representation and Hardware Comparison]**
> *Draw two side-by-side panels:*
> **Left panel:** Standard binary representation of a sample coefficient (e.g., decimal 23 = `10111₂`, 4 non-zero bits → 3 adders needed). Below it, draw a hardware tree with 3 add/shift nodes.
> **Right panel:** CSD representation of the same coefficient (e.g., `100̄1̄00̄1` in CSD notation, 2 non-zero digits → 1 adder needed). Below it, draw the collapsed hardware tree with 1 add/shift node. Label the "Area Reduction" arrow between panels. This figure visually proves why CSD is preferred for non-power-of-two coefficients.

### 2.3.3 Reconfigurability Constraint

While shift-and-add and CSD architectures successfully eliminate DSP slice consumption, they introduce a critical constraint for adaptive systems: **the coefficients are hardwired into the FPGA routing fabric at synthesis time**. The specific shift amounts and adder connections are encoded as fixed wire routes in the placed-and-routed bitstream. Changing the filter's frequency response requires a complete re-synthesis and device reprogramming. This renders pure multiplier-less architectures unsuitable for applications requiring runtime coefficient update — such as Least Mean Squares (LMS) adaptive filtering, adaptive beam steering, or dynamic channel equalization. This limitation is the direct motivation for the Distributed Arithmetic framework described in Section 2.4.

---

## 2.4 Distributed Arithmetic: Multiplier-Free Inner Products

**Distributed Arithmetic (DA)** is a computation paradigm that restructures the weighted inner product operation to avoid explicit multiplication entirely [White, 1989]. For an \(M\)-dimensional inner product \(z = \sum_{i=0}^{M-1} x_i y_i\), DA exploits the bit-plane decomposition of the weight \(y_i\) in two's complement:

\[
z = -2^{m-1}\sum_{i=0}^{M-1} x_i y_{m-1,i} + \sum_{j=0}^{m-2} 2^j \sum_{i=0}^{M-1} x_i y_{j,i}
\]

where \(y_{j,i}\) is the \(j\)-th bit of \(y_i\) and \(m\) is the coefficient word width. For each bit-plane \(j\), the binary address vector \([y_{j,0}, y_{j,1}, \ldots, y_{j,M-1}]\) selects a precomputed partial sum from a Look-Up Table (LUT) of \(2^M\) entries. A shift-accumulator then combines the LUT outputs to produce the final inner product — without a single explicit multiplier.

The critical scalability limitation of LUT-based DA is that the LUT size grows exponentially with \(M\): a full \(M\)-input LUT requires \(2^M\) words. For \(M = 8\) this yields 256 entries; for \(M = 64\) (a common adaptive filter order) the LUT requirement becomes computationally infeasible. This exponential scaling motivates decomposition techniques [Meher et al., 2008] and, more critically, the shift to **LUT-free online partial product generation** via Radix-8 Booth encoding as proposed by Jiang et al. [2018].

---

## 2.5 Radix-8 Booth Encoding: Compressing the Partial Product Array

Standard binary multiplication of an \(m\)-bit coefficient generates \(m\) partial products — one per coefficient bit. Radix-4 Booth encoding (grouping 3 bits with 1-bit overlap) reduces this to \(\lceil m/2 \rceil\) partial products. **Radix-8 Booth encoding** extends the grouping to 4 bits with 1-bit overlap, reducing the partial product count to \(\lceil m/3 \rceil\) — a **66.7% reduction** relative to standard binary multiplication [Jiang et al., 2016].

The encoding maps each 4-bit window \([c_{3j+2}, c_{3j+1}, c_{3j}, c_{3j-1}]\) of the coefficient to a signed digit \(d_j \in \{0, \pm1, \pm2, \pm3, \pm4\}\):

> **[Table 2.2 — Radix-8 Booth Encoding Truth Table]**

| Bit Window `[c₃ⱼ₊₂ c₃ⱼ₊₁ c₃ⱼ c₃ⱼ₋₁]` | Booth Digit `dⱼ` | Hardware Operation on Input `x[n]` |
|---|---|---|
| `0000`, `1111` | 0 | Zero — no operation |
| `0001`, `0010` | +1 | Pass `x[n]` directly |
| `0011`, `0100` | +2 | `x[n] << 1` (left-shift by 1) |
| `0101`, `0110` | +3 | Approximate recoding adder: `x[n] + (x[n] << 1)` |
| `0111` | +4 | `x[n] << 2` (left-shift by 2) |
| `1000` | −4 | Two's complement of `x[n] << 2` |
| `1001`, `1010` | −3 | Two's complement of recoding adder result |
| `1011`, `1100` | −2 | Two's complement of `x[n] << 1` |
| `1101`, `1110` | −1 | Two's complement of `x[n]` |

For the 8-bit coefficient used in this thesis (\(m = 8\)), Radix-8 encoding yields exactly \(\lceil 8/3 \rceil = 3\) partial product rows per tap — reducing the Wallace tree height from 8 rows to 3 rows. This compresses adder tree depth, reduces LUT area, and shortens the critical path through the accumulation stage. The only non-trivial operation in the truth table is the \(\pm3\) case, which requires an approximate recoding adder generating \(3 \cdot x[n]\). In this work, this is implemented as an LOA-based adder (Section 2.6.1), consistent with the approximate DA framework of Jiang et al. [2018].

---

## 2.6 Approximate Computing: The LOA Adder and Approximate Wallace Trees

### 2.6.1 The Lower-Part OR Adder (LOA)

The **Lower-part OR Adder (LOA)** was introduced by Mahdiani et al. [2010] as an approximate arithmetic structure that eliminates carry propagation from the least-significant portion of a binary adder. For two operands \(A\) and \(B\) of width \(W\), with approximation applied to the lower \(k\) bits, the LOA computes:

\[
\text{LOA}(A, B)_{[W-1:k]} = A_{[W-1:k]} + B_{[W-1:k]} + c_{in}
\]

\[
\text{LOA}(A, B)_{[k-1:0]} = A_{[k-1:0]} \text{ OR } B_{[k-1:0]}
\]

where \(c_{in} = A_{[k-1]} \text{ AND } B_{[k-1]}\) is a single-gate carry estimate into the MSB zone. The OR operation on the lower \(k\) bits requires exactly **one gate level with zero carry propagation**, fundamentally eliminating the carry chain from the LSB portion of the datapath. The MSB zone retains exact carry-propagate addition to preserve dynamic range and sign correctness. Jiang et al. demonstrated empirically that LOA with \(k = 4\) approximate LSBs achieves greater than **43% reduction in Area-Delay Product (ADP)** and approximately **30% reduction in Power-Delay Product (PDP)** versus conventional adder trees, with average errors well within the noise floor of practical DSP applications [Jiang et al., 2018].

> **[Figure 2.3 — LOA Adder Structure vs. Standard Carry-Propagate Adder]**
> *Draw two side-by-side circuit diagrams:*
> **Left (Standard Full-Adder Chain):** Show 8 full-adder cells in a ripple chain, with a red carry-propagation arrow threading through all 8 cells from LSB to MSB. Label "Critical Path = 8 × t_FA".
> **Right (LOA):** Show the lower k=4 bits replaced by OR gates (green, labeled "Approx Zone: OR logic, 1 gate level"), and the upper 4 bits using standard exact adder cells. The carry-in to the MSB zone comes from a single AND gate. Label "Critical Path = 4 × t_FA + t_AND". Annotate the eliminated carry chain with "Carry Chain Eliminated Here".
> *This is the single most important figure in Chapter 2 — it visually captures the fundamental mechanism behind the proposed architecture's timing improvement.*

### 2.6.2 The Approximate Wallace Tree (AWT)

A standard Wallace Tree (WT) reduces an array of \(M\) partial product rows to two rows in \(\lceil\log_{1.5} M\rceil\) carry-save stages using 3:2 full-adder compressors, followed by a final carry-propagate adder. The circuit area and critical path delay of a WT are:

\[
C_{WT} = (M-2) \cdot m \cdot C_{FA} + C_{m,A}, \quad t_{WT} = \lceil\log_{1.5} M\rceil \cdot t_{FA} + t_{m,A}
\]

where \(C_{FA}\) and \(t_{FA}\) are the full-adder area and delay, and \(C_{m,A}\) and \(t_{m,A}\) are the area and delay of the final \(m\)-bit carry-propagate adder [Jiang et al., 2018].

An **Approximate Wallace Tree (AWT)** replaces the full-adder cells in the lower \(k\) bit positions of each carry-save stage with 3-input OR gates, while the upper \((m-k)\) bit positions retain exact full-adder logic. The OR gates evaluate in a single gate level with no carry dependency, structurally fracturing the critical path at the LSB boundary. As the number of `1`s in intermediate results tends to increase through the OR stages, Jiang et al. recommend using exact full-adders in the final two carry-save stages to contain error accumulation — a strategy adopted in the implementation of this thesis.

> **[Figure 2.4 — Standard Wallace Tree vs. Approximate Wallace Tree (AWT)]**
> *Draw two accumulation tree diagrams for M=4 inputs:*
> **Left (Standard WT):** 4 input rows, 2 carry-save stages of full-adder cells, then a final CPA adder. All cells are standard full adders (grey boxes).
> **Right (AWT):** Same structure, but the lower k=3 bit columns in the carry-save stages have OR gate cells (green) instead of full adders. Label "Approx LSB Zone (OR gates)" and "Exact MSB Zone (Full Adders)". Annotate the shortened critical path in the AWT. This directly motivates the use of AWT in the proposed Approximate DA architecture.

---

## 2.7 Error Analysis of Input Truncation

A central design question in approximate computing is: *how much error does the approximation introduce, and is it bounded?* For the input truncation scheme used in the proposed architecture, Jiang et al. [2018] provide a rigorous probabilistic analysis. An \(m\)-bit input \(A\) truncated by retaining only the upper \((m-k)\) bits has a truncation error:

\[
E[A_L] = p \sum_{i=0}^{k-1} 2^i \approx p \cdot 2^k
\]

where \(p\) is the probability of a bit being `1` and \(A_L = \sum_{i=0}^{k-1} a_i 2^i\) is the truncated portion. To compensate this average error, a constant bias \(2^{k-1}\) (half the maximum truncation error) is added to the truncated operand, yielding a compensated value:

\[
\hat{A} = A_H + 2^{k-1}
\]

where \(A_H\) is the truncated high-part. This reduces the average residual error to \(E[A - \hat{A}] \approx 0\) for uniformly distributed inputs, and bounds the maximum error distance at \(2^{k-1}\) rather than \(2^k - 1\). For \(k=4\), the maximum absolute truncation error per input sample is bounded at 8 out of a 16-bit dynamic range of 32,768 — a relative error below 0.025%. Jiang et al. verified through 5 million Monte Carlo input combinations that 99.79% of inner product errors fall within ±400 LSBs of the 32-bit output [2018] — confirming the bounded, application-tolerable nature of the approximation.

---

## 2.8 Literature Gap and Research Positioning

The trajectory of prior work reviewed above — from direct-form MAC architectures through pipelining, CSD encoding, LUT-based DA, Radix-8 Booth encoding, and approximate Wallace trees — converges on the Approximate DA architecture of Jiang et al. [2018] as the current state of the art for energy-efficient FIR datapath design. However, a critical gap exists: **all prior validation of this architecture was conducted through ASIC synthesis** using Synopsys Design Compiler on ST 28nm CMOS technology. The FPGA implementation context is fundamentally different: LUT-based logic mapping, FPGA carry-chain primitives, and physical placement-and-routing on reconfigurable fabric introduce timing, area, and power characteristics that cannot be inferred from standard-cell ASIC results.

> **[Table 2.3 — State-of-the-Art Comparison and Research Positioning]**

| Architecture | Key Reference | DSP Usage | Reconfigurable? | Approximate? | Validation Platform | Gap |
|---|---|---|---|---|---|---|
| Direct-Form MAC | Meyer-Baese (2014) | N DSPs | Yes | No | FPGA / ASIC | Critical path scales with N |
| Pipelined MAC | Standard VLSI practice | N DSPs | Yes | No | FPGA | Highest dynamic power |
| CSD Shift-and-Add | Samueli (1989) | Zero | **No** | No | ASIC | Hardwired; no runtime update |
| LUT-based DA | White (1989); Guo & DeBrunner (2011) | Zero | Partial | No | FPGA | LUT size ∝ 2^M; not scalable |
| Approx DA + Radix-8 + AWT | **Jiang et al. (2018)** | Zero | Yes | Yes | **ASIC only (28nm)** | **No FPGA post-routing validation** |
| **This Work** | **Proposed** | **Zero** | **Yes** | **Yes** | **FPGA (Artix-7, post-routing)** | **Fills the gap above** |

This thesis fills this gap by implementing and post-route verifying all six architectural variants — including the proposed Approximate DA design — on the AMD Xilinx Artix-7 XC7A200T using Vivado's full placement-and-routing flow with standardized timing constraints (10 ns clock period, identical for all six designs). The implementation results are extracted post-routing, meaning all wire delays, LUT placement, and carry-chain topology are fully accounted for in the reported PPA metrics.

---

## 2.9 Chapter Summary

This chapter established the theoretical and literature foundations for all six hardware architectures evaluated in this thesis. Section 2.1 characterized the direct-form MAC bottleneck. Sections 2.2 and 2.3 reviewed the standard optimization strategies of pipelining, symmetry exploitation, and multiplier-less shift-and-add design, along with their respective limitations. Section 2.4 introduced the Distributed Arithmetic framework and its LUT scalability constraint. Section 2.5 derived the Radix-8 Booth encoding scheme and quantified its 66.7% partial product reduction. Sections 2.6 and 2.7 presented the LOA adder and Approximate Wallace Tree mechanisms alongside their probabilistic error bounds. Table 2.3 positioned this thesis as the first FPGA post-routing validation of the Approximate DA architecture. Chapter 3 details the RTL Verilog implementation of each of the six architectures evaluated in this Design Space Exploration.

---

## References (Chapter 2)

[1] J. G. Proakis and D. G. Manolakis, *Digital Signal Processing: Principles, Algorithms, and Applications*, 4th ed. Pearson, 2006.

[2] U. Meyer-Baese, *Digital Signal Processing with Field Programmable Gate Arrays*, 4th ed. Springer, 2014.

[3] H. Samueli, "An improved search algorithm for the design of multiplierless FIR filters with powers-of-two coefficients," *IEEE Trans. Circuits Syst.*, vol. 36, no. 7, pp. 1044–1047, 1989.

[4] S. A. White, "Applications of distributed arithmetic to digital signal processing: A tutorial review," *IEEE ASSP Mag.*, vol. 6, no. 3, pp. 4–19, Jul. 1989.

[5] P. K. Meher, S. Chandrasekaran, and A. Amira, "FPGA realization of FIR filters by efficient and flexible systolization using distributed arithmetic," *IEEE Trans. Signal Process.*, vol. 56, no. 7, pp. 3009–3017, Jul. 2008.

[6] R. Guo and L. S. DeBrunner, "Two high-performance adaptive filter implementation schemes using distributed arithmetic," *IEEE Trans. Circuits Syst. II*, vol. 58, no. 9, pp. 600–604, Sep. 2011.

[7] H. R. Mahdiani, A. Ahmadi, S. M. Fakhraie, and C. Lucas, "Bio-inspired imprecise computational blocks for efficient VLSI implementation of soft-computing applications," *IEEE Trans. Circuits Syst. I*, vol. 57, no. 4, pp. 850–862, Apr. 2010.

[8] H. Jiang, J. Han, F. Qiao, and F. Lombardi, "Approximate Radix-8 Booth multipliers for low-power and high-performance operation," *IEEE Trans. Comput.*, vol. 65, no. 8, pp. 2638–2644, Aug. 2016.

[9] H. Jiang, L. Liu, P. P. Jonker, D. G. Elliott, F. Lombardi, and J. Han, "A high-performance and energy-efficient FIR adaptive filter using approximate distributed arithmetic circuits," *IEEE Trans. Circuits Syst. I*, vol. 65, no. 12, pp. 4221–4232, 2018.
