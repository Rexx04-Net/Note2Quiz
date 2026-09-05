# Chapter 6: System Evaluation & Performance Benchmarking Figures - Specifications

This document outlines the data sources, academic significance, and generation details for the **5 empirical evaluation figures** in Chapter 6 of the Note2Quiz FYP2 thesis.

---

## 💡 Are these Figures Screenshots or Generated?

### Answer: **They MUST be Generated Charts (Code-Generated Scientific Visualizations via Python / Matplotlib)**!

**Why they cannot be screenshots:**
1. **No UI to screenshot**: Latency distributions (P95, Std Dev, TTFT) and document throughput are benchmark measurements recorded from backend logs and performance profiling scripts, not visual app screens.
2. **Standard Academic Formats**: User study demographics, System Usability Scale (SUS) 10-item breakdowns, and SUS bell curves are statistical research charts derived from Likert questionnaires (Table 6.1 and Table 6.6).
3. **Publication Quality (300 DPI)**: Code-generated vector plots guarantee crisp fonts, exact alignment with thesis tables, and 0% chance of Turnitin plagiarism or low-resolution examiner complaints.

---

## 📊 Summary of the 5 Chapter 6 Figures

| Figure ID | Title | Data Source in Thesis | Chart Type | Output File |
| :--- | :--- | :--- | :--- | :--- |
| **Figure 6.1.1** | **API Response Latency Distribution across AI Generative Endpoints** | Section 6.1, Table 6.1 (10 endpoints: Cached, Sync, Auth, SSE TTFT, Gemini Flash, OCR) | Horizontal Dual Bar Chart (Mean ± Std Dev vs P95) with 1.0s & 3.0s Thresholds | [`figure_6_1_1_latency_distribution.png`](file:///c:/src/FYP/figures/figure_6_1_1_latency_distribution.png) |
| **Figure 6.1.2** | **RAG Document Chunk Processing Throughput vs File Size** | Section 6.1 (1MB to 50MB PDF & PPTX file scaling) | Dual Y-Axis Line & Scatter Graph (Processing Time vs. Throughput MB/s) | [`figure_6_1_2_rag_throughput.png`](file:///c:/src/FYP/figures/figure_6_1_2_rag_throughput.png) |
| **Figure 6.3.1** | **Participant Demographic Distribution across Academic Programs** | Section 6.3.1 (N=30 UTAR students: CS, CN, IA/IB, Eng/BizTech) | Modern Donut Chart with Headcount & Percentage Callouts | [`figure_6_3_1_participant_demographics.png`](file:///c:/src/FYP/figures/figure_6_3_1_participant_demographics.png) |
| **Figure 6.3.2** | **System Usability Scale (SUS) 10-Item Mean Score Breakdown** | Section 6.3.2, Table 6.6 (Q1 to Q10 item-level Likert responses) | Positive (Green) vs. Negative (Red) Horizontal Bar Chart with Error Bars | [`figure_6_3_2_sus_score_breakdown.png`](file:///c:/src/FYP/figures/figure_6_3_2_sus_score_breakdown.png) |
| **Figure 6.3.3** | **SUS Percentile Rank and Academic Usability Grade Distribution** | Section 6.3.2 (Composite Score 84.25 ± 5.8 vs Bangor et al. Bell Curve) | Standard SUS Normal Distribution Bell Curve with Note2Quiz Grade A Pin | [`figure_6_3_3_sus_grade_distribution.png`](file:///c:/src/FYP/figures/figure_6_3_3_sus_grade_distribution.png) |

---

## 🛠️ Generator Script
All 5 figures can be regenerated at any time with:
```bash
python generate_chapter6_figures.py
```
