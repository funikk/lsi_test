# Top Integration Layer (`top/`)

This directory contains the top wrapper RTL, system integration testbenches, full-chip synthesis, and PnR flow configs for `VDRV_v1a`.

## Ownership & Workflow
- Managed by System Integrator / `system_architect` / `backend_design`.
- References RTL sources from sub-blocks (`../blocks/*/rtl/*.v`) and top wrapper (`rtl/VDRV_v1a_top.v`).
