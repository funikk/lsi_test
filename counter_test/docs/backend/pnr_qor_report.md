# counter PnR & QoR Signoff Trial Report

## 1. DoE Optimization Trial Matrix

| Trial ID (Tag) | Description / Key Overrides | Inst Count | Area (µm²) | Max Cap Vio | Max Slew Vio | Hold WNS (ns) | Typical Setup WNS | Worst SS Setup WNS | DRC Errors | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `trial01_base` | ベースライン (HDセル, Util 40%, Density 45%, Typical Corner) | 147 | 651.88 | 0 | 0 | +0.13 | +6.59 | +5.57 | 0 | PASS ✅ |
| `trial02_hs_library` | 高速セルライブラリ適用 (sky130_fd_sc_hs) | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | - | Unrun |
| `trial03_fanout10` | ファンアウト制限強化 (Fanout 10) | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | - | Unrun |
| `trial04_dense60` | 配置高密度化 (Density 60%) | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | - | Unrun |
| `trial05_ss_corner` | 最悪条件プライマリ (nom_ss_100C_1v60) + Hold Slack Margin 0.3ns | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | *Pending* | - | Unrun |

---
## 2. Trial Parameter Details

### `trial01_base`
- **Description**: ベースライン (HDセル, Util 40%, Density 45%, Typical Corner)
```json
{
  "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "MAX_FANOUT_CONSTRAINT": 20
  }
}
```

### `trial02_hs_library`
- **Description**: 高速セルライブラリ適用 (sky130_fd_sc_hs)
```json
{
  "STD_CELL_LIBRARY": "sky130_fd_sc_hs",
  "STD_CELL_LIBRARY_OPT": "sky130_fd_sc_hs",
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "MAX_FANOUT_CONSTRAINT": 20
  }
}
```

### `trial03_fanout10`
- **Description**: ファンアウト制限強化 (Fanout 10)
```json
{
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "MAX_FANOUT_CONSTRAINT": 10
  }
}
```

### `trial04_dense60`
- **Description**: 配置高密度化 (Density 60%)
```json
{
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 60,
    "MAX_FANOUT_CONSTRAINT": 20
  }
}
```

### `trial05_ss_corner`
- **Description**: 最悪条件プライマリ (nom_ss_100C_1v60) + Hold Slack Margin 0.3ns
```json
{
  "PRIMARY_CORNER": "nom_ss_100C_1v60",
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "PL_RESIZER_HOLD_SLACK_MARGIN": 0.3,
    "GLB_RESIZER_HOLD_SLACK_MARGIN": 0.3
  }
}
```
