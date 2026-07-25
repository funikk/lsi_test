# Subproject Documentation & Specification Guidelines (`VDRV_v1/docs`)

This directory contains technical specifications, architectural designs, verification plans, and backend constraint documentation created by specialized subagents and domain engineers.

---

## 1. Directory & Role Mapping

```text
VDRV_v1/docs/
├── AGENTS.md                        # Documentation rules & guidelines
├── system_architecture/             # Managed by: system_architect
│   └── spec_top_architecture.md     # Top system specification, bus interconnect, & memory map
├── logic_design/                    # Managed by: logic_design
│   └── spec_module_interfaces.md    # Inter-module protocol & signaling specifications
├── verification/                    # Managed by: logic_verification
│   └── spec_verification_plan.md    # Top & block verification plans, coverage metrics
├── backend/                         # Managed by: backend_design
│   └── spec_pnr_constraints.md      # Clock targets, SDC constraints, power grid & floorplan specs
└── firmware/                        # Managed by: firmware_design
    └── spec_firmware_api.md         # MMIO register definitions & software driver APIs
```

---

## 2. Language & Formatting Rules
- **User-Facing Specs (Japanese)**: Technical specs, setup guides, and architectural designs written for human engineers must be in Japanese.
- **Agent Guidelines (English)**: Orchestration rules and subagent instructions must be in English.
- **Markdown standard**: Use standard markdown table formats, mermaid diagrams, and signal list tables.
