# Comparative Assessment of ELCC, ECP, and Firm Capacity Methodologies for Resource Adequacy in Renewable-Dominated Power Systems

MATLAB implementation and input data supporting the paper presented at the **2026 IEEE Eighth Ecuador Technical Chapters Meeting (ETCM 2026)** — Paper ID 119.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2021b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)

---

## Authors

| Author | Affiliation | Contact | ORCID |
|---|---|---|
| **Diego Arias-Cazco**, Senior Member, IEEE | Facultad de Ingeniería en Electricidad y Computación, Escuela Superior Politécnica del Litoral (ESPOL), Guayaquil, Ecuador | diearias@espol.edu.ec |https://orcid.org/0000-0001-5655-4449 |
| **Manuel S. Alvarez-Alvarado**, Senior Member, IEEE | Facultad de Ingeniería en Electricidad y Computación, ESPOL, Guayaquil, Ecuador | mansalva@espol.edu.ec |https://orcid.org/0000-0002-0398-9235 |
| **Deivid Gaona-Ramos**, Member, IEEE | Facultad de Ingeniería en Electricidad y Computación, ESPOL, Guayaquil, Ecuador | deivgaon@espol.edu.ec | |
| **Pablo Arias-Cazco** | Facultad de Ingeniería, Escuela Superior Politécnica de Chimborazo (ESPOCH), Riobamba, Ecuador | pablo.ariasc@espoch.edu.ec |https://orcid.org/0009-0003-4643-3020 |

All four authors are creators and contributors of this software and data repository.

---

## Overview

This repository implements a unified **probabilistic-deterministic framework** for generation adequacy assessment. The framework is *probabilistic* in its treatment of generation availability — built through exact recursive **Capacity Outage Probability Table (COPT) convolution**, yielding analytically exact LOLP and LOLE — and *deterministic* in its treatment of the renewable resource, represented as a known hourly time series incorporated as a net-demand reduction.

Three capacity credit metrics are computed and systematically compared under a common reliability foundation:

| Metric | Definition | Reliability criterion |
|---|---|---|
| **ELCC** — Effective Load Carrying Capability | Maximum load increment that preserves baseline LOLE | Constant LOLE |
| **ECP** — Equivalent Conventional Power | Capacity of a fictitious conventional unit delivering the same reliability benefit | Constant LOLE |
| **Firm Capacity (PEPP)** | Largest available capacity exceeded with probability $1 - \text{LOLP}(h_p)$ at the peak-demand hour | Peak-hour LOLP |

The approach provides a computationally efficient and analytically rigorous alternative to Monte Carlo simulation.

---

## Repository contents

```
├── ECPyELCC_Chile_V6.m                          % 24-hour illustrative case
├── ECPyELCC_FirmC_EcuadorV8_Sensibilidad4PV.m   % 8760-hour Ecuador SNI case
├── data/
│   ├── Demanda_2025_8760.mat                    % Hourly demand, Ecuador SNI 2025 (ARCONEL)
│   └── CF_Ecuador_NSRDB_8760.mat                % Hourly PV capacity factor (NSRDB, 13,017 points)
├── figure/                                      % Generated figures (PDF, vector)
├── CITATION.cff                                 % Machine-readable citation metadata
├── LICENSE
└── README.md
```

### Script description

**`ECPyELCC_Chile_V6.m`** — 24-hour illustrative case. Three thermal units (85, 75, 55 MW) and one 35 MW PV unit, all with FOR = 5%. Builds the state space by explicit enumeration, computes hourly LOLP and daily LOLE, and determines ECP, ELCC, and firm capacity (PEPP criterion).

**`ECPyELCC_FirmC_EcuadorV8_Sensibilidad4PV.m`** — Full 8760-hour chronological simulation of the Ecuador SNI 2025. Builds the COPT once via recursive convolution over 19 disaggregated generation units (8817 MW total), evaluates annual LOLE through indexed lookups, and performs a sensitivity analysis across four aggregated PV penetration levels (500, 800, 1200, 2000 MW).

---

## Input data

| Dataset | Source | Description |
|---|---|---|
| Hourly demand 2025 | ARCONEL (Agency for Regulation and Control of Energy and Non-Renewable Natural Resources, Ecuador) | 8760 hourly values. Peak: 4864.2 MW · Minimum: 2245.6 MW |
| Solar capacity factor | [NSRDB](https://nsrdb.nrel.gov) — National Renewable Energy Laboratory | Spatial average of 13,017 distributed measurement points across Ecuador. Annual average CF = 18.0% |
| Generation fleet | ARCONEL official 2025 statistics | 19 disaggregated units: hydroelectric, thermal, biomass/biogas. Total 8817 MW |

---

## Requirements

- MATLAB R2021b or newer
- Statistics and Machine Learning Toolbox (optional, only for auxiliary plots)

No third-party toolboxes are required for the core COPT convolution and LOLE computation.

---

## How to run

```matlab
% 24-hour illustrative case
>> ECPyELCC_Chile_V6

% 8760-hour Ecuador SNI case with PV sensitivity analysis
>> ECPyELCC_FirmC_EcuadorV8_Sensibilidad4PV
```

Both scripts print the results table to the console and generate the figures reported in the paper. To export the figures as vector PDF, uncomment the `exportgraphics` calls at the end of each figure block.

---

## Key results

**24-hour illustrative case** (35 MW PV unit)

| Metric | Value [MW] | % of installed capacity |
|---|---|---|
| Firm Capacity | 0.00 | 0.0% |
| ELCC | 8.24 | 25.7% |
| ECP | 10.58 | 30.0% |

**8760-hour Ecuador SNI 2025** — baseline $LOLE_{base}$ = 44.79 h/yr

| PV block [MW] | LOLE_solar [h/yr] | ECP [MW] | ECP % | ELCC [MW] | ELCC % |
|---|---|---|---|---|---|
| 500 | 37.80 | 96.9 | 19.4% | 96.6 | 19.3% |
| 800 | 34.71 | 143.9 | 18.0% | 145.5 | 18.2% |
| 1200 | 31.69 | 193.5 | 16.1% | 200.0 | 16.7% |
| 2000 | 28.16 | 256.7 | 12.8% | 278.2 | 13.9% |

Firm capacity yields **0 MW in all scenarios**, since the Ecuador SNI peak demand occurs during evening hours (19:00–22:00) when solar generation is unavailable. The resulting gap reaches **278 MW** at 2000 MW of installed PV.

---

## Scope and limitations

This framework constitutes a **methodological foundation rather than a complete regulatory methodology**. The hydro-dominated Ecuadorian fleet is represented through fixed forced outage rates, without hydrological uncertainty, storage, or network modeling. A comprehensive regulatory assessment would additionally require:

- Stochastic hydrological modeling of reservoir inflows
- Critical dry-year scenario analysis
- Transmission network constraints
- Battery and pumped-hydro storage dispatch
- International exchange capacity with neighboring systems

---

## How to cite

If you use this software or data, please cite **both** the repository and the associated paper.

### Repository

```bibtex
@misc{AriasCazco2026repo,
  author       = {Arias-Cazco, Diego and Alvarez-Alvarado, Manuel S. and
                  Gaona-Ramos, Deivid and Arias-Cazco, Pablo},
  title        = {{MATLAB} Implementation and Input Data for the Comparative
                  Assessment of {ELCC}, {ECP}, and Firm Capacity Methodologies},
  year         = {2026},
  version      = {1.0.0},
  howpublished = {Software and data repository, GitHub},
  note         = {[Online]. Available:
                  \url{https://github.com/DiegoAriasCazco/ETCM_2026_PaperID119_ELCCandECP}}
}
```

### Paper

```bibtex
@inproceedings{AriasCazco2026ETCM,
  author    = {Arias-Cazco, Diego and Alvarez-Alvarado, Manuel S. and
               Gaona-Ramos, Deivid and Arias-Cazco, Pablo},
  title     = {Comparative Assessment of {ELCC}, {ECP}, and Firm Capacity
               Methodologies for Resource Adequacy in Renewable-Dominated
               Power Systems},
  booktitle = {2026 IEEE Eighth Ecuador Technical Chapters Meeting (ETCM)},
  year      = {2026},
  publisher = {IEEE}
}
```

GitHub also renders a **"Cite this repository"** button from the [`CITATION.cff`](CITATION.cff) file in this repository.

---

## Acknowledgment

This work has been supported by the Escuela Superior Politécnica del Litoral (ESPOL) and the Escuela Superior Politécnica de Chimborazo (ESPOCH), Ecuador.

---

## License

Released under the [MIT License](LICENSE). The demand and solar resource datasets are derived from publicly available sources (ARCONEL and NSRDB) and remain subject to their respective terms of use.
