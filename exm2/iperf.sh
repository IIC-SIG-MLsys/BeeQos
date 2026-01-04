#!/bin/bash
#
# iperf3 高低优先级分开测试脚本
#

usage() {
    echo "Usage: $0 <mode> [options]"
    echo "Modes:"
    echo "  genconf     - 生成配置文件"
    echo "  low-server  - 启动低优先级服务端"
    echo "  high-server - 启动高优先级服务端"
    echo "  low-client  - 启动低优先级客户端"
    echo "  high-client - 启动高优先级客户端"
    echo "  extract     - 提取结果到 Excel"
    echo ""
    echo "Options:"
    echo "  -h <host>   服务端地址 (client 模式必填)"
    echo "  -f <file>   配置文件 (默认 exm2.conf)"
    echo "  -o <dir>    输出目录 (默认 results)"
    exit 1
}

mode=$1
shift || true

host=""
out_dir="results"
conf_file="$out_dir/exm2.conf"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h) host="$2"; shift 2 ;;
        -f) conf_file="$2"; shift 2 ;;
        -o) out_dir="$2"; shift 2 ;;
        *) usage ;;
    esac
done

mkdir -p "$out_dir"

case "$mode" in

genconf)
    cat > "$conf_file" <<EOF
# priority,start_time,duration,port,bandwidth,parallel
low,0,60,5201,0,4
high,10,40,5202,200M,2
high,40,20,5203,200M,2
EOF
    echo "生成配置文件: $conf_file"
    ;;

low-server)
    echo "启动低优先级服务端..."
    while IFS=, read -r prio start dur port bw par; do
        [[ "$prio" =~ ^# ]] && continue
        if [[ "$prio" == "low" ]]; then
            echo "启动 iperf3 server on port $port"
            iperf3 -s -p "$port" &
        fi
    done < "$conf_file"
    wait
    ;;

high-server)
    echo "启动高优先级服务端..."
    while IFS=, read -r prio start dur port bw par; do
        [[ "$prio" =~ ^# ]] && continue
        if [[ "$prio" == "high" ]]; then
            echo "启动 iperf3 server on port $port"
            iperf3 -s -p "$port" &
        fi
    done < "$conf_file"
    wait
    ;;

low-client)
    if [ -z "$host" ]; then echo "请指定 -h <host>"; exit 1; fi
    echo "启动低优先级客户端..."
    while IFS=, read -r prio start dur port bw par; do
        [[ "$prio" =~ ^# ]] && continue
        if [[ "$prio" == "low" ]]; then
            logfile="$out_dir/client_low_${port}.log"
            echo "低优任务: port=$port P=$par start=$start dur=$dur"
            if [[ "$bw" == "0" ]]; then
                iperf3 -c "$host" -p "$port" -P "$par" -t "$dur" > "$logfile" 2>&1 &
            else
                iperf3 -c "$host" -p "$port" -P "$par" -t "$dur" -b "$bw" > "$logfile" 2>&1 &
            fi
        fi
    done < "$conf_file"
    wait
    ;;

high-client)
    if [ -z "$host" ]; then echo "请指定 -h <host>"; exit 1; fi
    echo "启动高优先级客户端..."
    while IFS=, read -r prio start dur port bw par; do
        [[ "$prio" =~ ^# ]] && continue
        if [[ "$prio" == "high" ]]; then
            logfile="$out_dir/client_high_${port}.log"
            echo "等待 $start 秒后启动高优任务: port=$port bw=$bw P=$par"
            (sleep "$start";
             if [[ "$bw" == "0" ]]; then
                 iperf3 -c "$host" -p "$port" -P "$par" -t "$dur" > "$logfile" 2>&1
             else
                 iperf3 -c "$host" -p "$port" -P "$par" -t "$dur" -b "$bw" > "$logfile" 2>&1
             fi) &
        fi
    done < "$conf_file"
    wait
    ;;

extract)
    echo "提取随时间变化的带宽到 Excel..."
    python3 <<EOF
import os, re, openpyxl

out_dir = "$out_dir"
xlsx_file = os.path.join(out_dir, "iperf_results.xlsx")
wb = openpyxl.Workbook()

pattern_sum = re.compile(
    r"\[SUM\]\s+(\d+\.\d+)-(\d+\.\d+)\s+sec\s+.+?\s+([\d\.]+)\s+([MG]bits/sec)"
)

for fname in os.listdir(out_dir):
    if not fname.startswith("client_"): 
        continue

    filepath = os.path.join(out_dir, fname)
    with open(filepath) as f:
        text = f.read()

    # 根据文件名判断优先级
    prio = "HIGH" if "high" in fname else "LOW"
    sheet = wb[prio] if prio in wb.sheetnames else wb.create_sheet(prio)
    if sheet.max_row == 1:  # 表头只写一次
        sheet.append(["开始(s)", "结束(s)", "带宽(Mbps)"])

    for m in pattern_sum.finditer(text):
        start, end, bw, unit = m.groups()
        bw = float(bw)
        if unit.startswith("G"):
            bw *= 1000  # 转成 Mbps
        sheet.append([float(start), float(end), bw])

# 删除默认 sheet (如果空)
if "Sheet" in wb.sheetnames and len(wb.sheetnames) > 1:
    wb.remove(wb["Sheet"])

wb.save(xlsx_file)
print(f"结果已保存到 {xlsx_file}")
EOF
    ;;

*)
    usage
    ;;
esac
