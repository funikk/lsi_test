# Top Integration Layer (`top/`)

This directory contains the top wrapper RTL, system integration testbenches, full-chip synthesis, and PnR flow configs for `__PROJECT_NAME__`.

## Ownership & Workflow
- Managed by System Integrator / `system_architect` / `backend_design`.
- References RTL sources from sub-blocks (`../blocks/*/rtl/*.v`) and top wrapper (`rtl/__PROJECT_NAME___top.v`).
