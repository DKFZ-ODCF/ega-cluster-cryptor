cat aspera-scp-transfer.*.log | grep -B 25 -E "^.+LOG - Source file transfers skipped.+:.+1$" | grep "LOG FASP Session Stop" | awk '{print $11}' | sed 's/source=//g'
