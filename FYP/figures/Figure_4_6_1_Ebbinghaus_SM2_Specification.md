# Figure 4.6.1: Ebbinghaus Forgetting Curve and Modified SM-2 Memory Retention Trajectory - Specifications & Context

This document explains the origins, mathematical formulation, and generation details for **Figure 4.6.1: Ebbinghaus Forgetting Curve and Modified SM-2 Memory Retention Trajectory** in Chapter 4, Section 4.6.1 of the FYP2 report.

---

## 1. Is this generated yourself or sourced from Google?

### 💡 Answer: **It MUST be generated yourself (Self-Generated Scientific Plot via Python)!**

#### Why you should NOT copy a generic curve from Google:
1. **Academic Integrity & Turnitin Plagiarism Avoidance**:
   - Google Images only contain generic historical Ebbinghaus curves (1885) or standard SuperMemo SM-2 illustrations.
   - External images do not match your exact mathematical implementation in Note2Quiz.
2. **100% Mathematical Alignment with Section 4.6.1**:
   - Your thesis Section 4.6.1 explicitly introduces two customized formulas:
     $$\text{Stability Formula (Eq. 4.1): } S = 1.0 + 0.65 \cdot (n - 1)$$
     $$\text{Exponential Retention Decay (Eq. 4.2): } R(t) = R_0 \cdot e^{-\frac{t}{7.0 \cdot S}}$$
   - Your system categorizes retention into **3 distinct color-coded thresholds**:
     - **$\ge 80\%$ (Green)**: Fresh / Mastered
     - **$50\% \le R < 80\%$ (Yellow)**: Fading / Review Soon
     - **$< 50\%$ (Red)**: Critical / Review Needed
   - A self-generated plot proves to your examiner and supervisor that you **mathematically modeled and visualized your actual software engine**.

---

## 2. Generated Plot Artifact

- **300 DPI High-Resolution Image**: [`figures/figure_4_6_1_ebbinghaus_sm2_trajectory.png`](file:///c:/src/FYP/figures/figure_4_6_1_ebbinghaus_sm2_trajectory.png)
- **Generator Script**: [`generate_figure_4_6_1.py`](file:///c:/src/FYP/generate_figure_4_6_1.py)

---

## 3. Pure Content-Focused AI Generation Prompt (If feeding into external AI)

```text
Create a scientific 2D coordinate plot for a computer science university thesis.
Title: Figure 4.6.1: Ebbinghaus Forgetting Curve and Modified SM-2 Memory Retention Trajectory

X-Axis: Elapsed Time Since Initial Learning (Days) from 0 to 30 days
Y-Axis: Estimated Memory Retention Score R(t) (%) from 0% to 100%

Background Mastery Zones:
1. Top Zone (80% to 100%): Soft Green background (#DCFCE7) labelled "Fresh / Mastered Zone (R >= 80%)"
2. Middle Zone (50% to 80%): Soft Yellow background (#FEF9C3) labelled "Fading / Review Soon Zone (50% <= R < 80%)"
3. Bottom Zone (0% to 50%): Soft Red background (#FEE2E2) labelled "Critical / Review Needed Zone (R < 50%)"

Key Plot Curves:
1. Baseline Curve (Red, Without Revision): Exponential decay R(t) = 100 * exp(-t / 7.0) dropping from 100% to < 5% by Day 30.
2. Spaced Repetition Trajectory (Active Recall Spikes):
   - Day 0 to 3 (Session 1, S=1.00): Decays to ~65%.
   - Day 3 (Review #2): Jumps back to 100% (S=1.65), decays to ~65% at Day 8.
   - Day 8 (Review #3): Jumps back to 100% (S=2.30), decays to ~61% at Day 16.
   - Day 16 (Review #4): Jumps back to 100% (S=2.95), decays much more slowly, staying above 50% through Day 30.

Annotation Box:
"Mathematical Model (Thesis Eq. 4.1 & 4.2):
• Stability: S = 1.0 + 0.65 * (n - 1)
• Retention: R(t) = R_0 * exp(-t / (7.0 * S))"

Style: Clean academic formatting, high-contrast labels, dashed threshold lines at 80% and 50%.
```

---

## 4. Formal Thesis Caption (Chapter 4, Section 4.6.1)
**Figure 4.6.1: Ebbinghaus Forgetting Curve and Modified SM-2 Memory Retention Trajectory**  
*Figure 4.6.1 visualizes the dynamic cognitive decay model implemented in the Note2Quiz engine. The red downward trajectory illustrates rapid exponential forgetting without active intervention ($S=1.0$). In contrast, spaced review sessions at days 3, 8, and 16 successively expand the memory stability factor $S$ (from 1.00 to 2.95), flattening the retention decay curve and keeping the topic inside the green Mastered ($\ge 80\%$) and yellow Fading ($50\% \le R < 80\%$) zones over a standard academic month.*
