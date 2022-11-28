# Repository Structure

`IP/myCPU` contains all sources for 5-stage pipeline CPU, except IP sources

`perf` contains IPC result and timing report for each configuration in `*.txt`

## Branch

`btb32_tlb32_base` has the default sources with its corresponding result and report

e.g. `btb8_tlb8` configures the number of entries as 8 both for `btb` and `tlb`

if you want to make some changes, please checkout and push it with a new branch

easily checkout from the `main` branch with clean `IP/myCPU` and `perf`, then you can add your own