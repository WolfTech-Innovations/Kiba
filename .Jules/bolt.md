## 2026-06-19 - [Performance] Optimized OTA manifest parsing and kernel check
**Learning:** Using PCRE lookarounds in `grep -oP` and Bash parameter expansion for string manipulation significantly reduces sub-process overhead in tight loops compared to piping to `awk` or `sed`.
**Action:** Prioritize Bash built-ins and advanced regex features for all high-performance scripting tasks.
