#!/usr/bin/env python3
import pandas as pd
import re
from pathlib import Path

LOG_BASE_DIR = Path("./logs/bw")
OUTPUT_DIR = Path("./logs/excel")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def extract_bandwidth(log_file: Path):
    """提取iperf每秒带宽"""
    bw_list = []
    with log_file.open() as f:
        for line in f:
            m = re.search(r'\[\s*\d+\]\s*(\d+\.\d+)-(\d+\.\d+)\s+sec.*?(\d+\.?\d*)\s+Mbits/sec', line)
            if m:
                start, _, bw = float(m.group(1)), float(m.group(2)), float(m.group(3))
                bw_list.append((start, bw))
    return bw_list

def process_subexperiment(subexp_dir: Path):
    """处理单个子实验，返回DataFrame"""
    high_logs = sorted(subexp_dir.glob("high*.log"))
    low_logs = sorted(subexp_dir.glob("low*.log"))

    high_series_dict = {}
    low_series_dict = {}

    for f in high_logs:
        m = re.match(r".*_(\d+)_(\d+)\.log", f.name)
        if not m:
            continue
        start_offset = int(m.group(1))
        for t, bw in extract_bandwidth(f):
            global_sec = int(start_offset + t)
            high_series_dict[global_sec] = bw

    for f in low_logs:
        for t, bw in extract_bandwidth(f):
            low_series_dict[int(t)] = bw

    max_time = max(max(high_series_dict.keys(), default=0),
                   max(low_series_dict.keys(), default=0),
                   49)  # 至少50行

    df = pd.DataFrame({
        "Index": list(range(1, max_time+2)),
        "High": [high_series_dict.get(i, None) for i in range(max_time+1)],
        "Low": [low_series_dict.get(i, None) for i in range(max_time+1)]
    })

    return df

def process_experiment(exp_dir: Path, output_dir: Path):
    """处理实验名目录，汇总所有子实验到一个 Excel，每个子实验一张 sheet"""
    excel_file = output_dir / f"{exp_dir.name}_bw.xlsx"
    with pd.ExcelWriter(excel_file) as writer:
        for subexp_dir in sorted(exp_dir.iterdir()):
            if subexp_dir.is_dir():
                df = process_subexperiment(subexp_dir)
                sheet_name = subexp_dir.name
                df.to_excel(writer, sheet_name=sheet_name, index=False)
    print(f"[INFO] 导出完成: {excel_file}")

def main():
    for exp_dir in sorted(LOG_BASE_DIR.iterdir()):
        if exp_dir.is_dir():
            process_experiment(exp_dir, OUTPUT_DIR)

if __name__ == "__main__":
    main()
