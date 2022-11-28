# Repository Structure

`IP/myCPU` contains all sources for 5-stage pipeline CPU, except IP sources

`perf` contains IPC result and timing report for each configuration in `*.txt`

## Branch

`btb32_tlb32_base` has the default sources with its corresponding result and report

e.g. `btb8_tlb8` configures the number of entries as 8 both for `btb` and `tlb`

if you want to make some changes, please checkout and push it with a new branch

easily checkout from the `main` branch with clean `IP/myCPU` and `perf`, then you can add your own

## Timing

| Conf.(BTB/TLB) | Frequency/MHz | WNS/ns | WHS/ns |   IPC    | Acc.  |
| -------------: | :-----------: | :----: | :----: | :------: | ----- |
|          32/32 |      61       |  0.41  | 0.049  | 0.565166 | 1.00x |
|           32/4 |      66       | 0.272  | 0.052  | 0.565166 | 1.08x |
|           4/32 |      65       | 0.114  | 0.054  | 0.558985 | 1.08x |
|            4/4 |      66       | 0.238  | 0.055  | 0.558985 | 1.09x |
|            8/8 |      68       | 0.228  | 0.052  | 0.562701 | 1.12x |

以默认配置（32/32）作为基准，加速比计算公式为：`$Acc=\frac{IPC_{base}/Frequency_{base}}{IPC/Frequency}$`







