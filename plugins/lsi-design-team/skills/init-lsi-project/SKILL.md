---
name: init-lsi-project
description: Creates a new circuit project directory structure with standard subdirectories (rtl, tb, sim, syn, gls, pnr, docs) and Makefiles.
---

# Init LSI Project Skill

## Overview
Use this skill when initializing a new circuit design module or subproject.

## Standard Directory Structure Created
```text
<project_name>/
├── rtl/               # Synthesizable RTL source files (.v, .sv)
├── tb/                # Testbench files
├── sim/               # RTL simulation outputs
├── syn/               # Logic synthesis netlists and SDC constraints
├── gls/               # Gate-level simulation outputs
├── pnr/               # Physical design settings (config.json, SDC, pin_order)
│   └── config.json
├── docs/              # Specifications and reports
└── Makefile           # Standard Makefile targets (lint, rtl_sim, presynth_check, pnr)
```
