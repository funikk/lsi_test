# VDRV_v1_core PnR & QoR Signoff Trial Report

## 1. DoE Optimization Trial Matrix

| Trial ID (Tag) | Description / Key Overrides | Inst Count | Area (µm²) | Max Cap Vio | Max Slew Vio | Hold WNS (ns) | Typical Setup WNS | Worst SS Setup WNS | DRC Errors | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `trial01_base` | ベースライン (Util 40%, Density 45%, Typical Primary) | 103028 | 474,792.00 | 210 | 4845 | +0.09 | +2.95 | -2.00 | 0 | Violating |
| `trial02_fanout15` | ファンアウト制限強化 (Fanout 15) | 103028 | 474,792.00 | 210 | 4845 | +0.09 | +2.95 | -2.00 | 0 | Violating |
| `trial03_fanout10` | ファンアウト制限強力強化 (Fanout 10): バッファリング加速検証 | 103028 | 474,792.00 | 210 | 4845 | +0.09 | +2.95 | -2.00 | 0 | Violating |
| `trial04_dense55_fanout15` | 配置密度引き上げ (Density 55%) + Fanout 15: 配線長短縮相乗効果 | 101694 | 474,255.00 | 194 | 4472 | +0.11 | +3.05 | -1.94 | 0 | Violating |
| `trial07_ss_density45` | SSLT最悪条件プライマリ化 (nom_ss_100C_1v60) + WhiteSpace確保(Density 45%) + Hold Margin 0.3ns | 103433 | 525,579.00 | 234 | 4999 | +0.31 | +2.02 | -1.98 | 0 | Violating |

---
## 2. Trial Parameter Details

### `trial01_base`
- **Description**: ベースライン (Util 40%, Density 45%, Typical Primary)
```json
{
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "MAX_FANOUT_CONSTRAINT": 20
  }
}
```

### `trial02_fanout15`
- **Description**: ファンアウト制限強化 (Fanout 15)
```json
{
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "MAX_FANOUT_CONSTRAINT": 15
  }
}
```

### `trial03_fanout10`
- **Description**: ファンアウト制限強力強化 (Fanout 10): バッファリング加速検証
```json
{
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 45,
    "MAX_FANOUT_CONSTRAINT": 10
  }
}
```

### `trial04_dense55_fanout15`
- **Description**: 配置密度引き上げ (Density 55%) + Fanout 15: 配線長短縮相乗効果
```json
{
  "pdk::sky130*": {
    "FP_CORE_UTIL": 40,
    "PL_TARGET_DENSITY_PCT": 55,
    "MAX_FANOUT_CONSTRAINT": 15
  }
}
```

### `trial07_ss_density45`
- **Description**: SSLT最悪条件プライマリ化 (nom_ss_100C_1v60) + WhiteSpace確保(Density 45%) + Hold Margin 0.3ns
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
