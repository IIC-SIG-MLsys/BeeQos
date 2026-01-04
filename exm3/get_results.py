import os
import re
import numpy as np
import pandas as pd

BASE_DIR = "logs"  # 你的日志根目录

def parse_iperf_log(path):
    """
    解析 iperf 日志，返回每条流带宽（Mbps）和总带宽（Mbps）。
    自动支持 Kbits/sec, Mbits/sec, Gbits/sec 单位。
    同时兼容 sender/receiver 格式 和 简化 Bandwidth 格式。
    """
    per_flow_bw = []
    total_bw = 0.0

    # 单位换算
    def to_mbps(value, unit):
        unit = unit.lower()
        if unit.startswith("k"):
            return float(value) / 1000
        elif unit.startswith("m"):
            return float(value)
        elif unit.startswith("g"):
            return float(value) * 1000
        else:
            return float(value)  # 默认 Mbps

    with open(path, "r") as f:
        for line in f:
            # ---- 匹配非 SUM 单流 ----
            if "[SUM]" not in line:
                # 兼容 receiver/sender 形式
                m = re.search(r"sec\s+.*?([\d.]+)\s+([KMG]?)bits/sec(?:\s+.*receiver)?", line, re.IGNORECASE)
                if m:
                    bw = to_mbps(m.group(1), m.group(2))
                    per_flow_bw.append(bw)

            # ---- 匹配 SUM 总带宽 ----
            m_sum = re.search(r"\[SUM\].*?([\d.]+)\s+([KMG]?)bits/sec", line, re.IGNORECASE)
            if m_sum:
                total_bw = to_mbps(m_sum.group(1), m_sum.group(2))

    return per_flow_bw, total_bw


def parse_sockperf_log(path):
    """解析 sockperf 日志，返回 P50/P90 延迟 (ms)"""
    p50 = p90 = None
    with open(path, "r") as f:
        for line in f:
            if "percentile 50.000" in line:
                p50 = float(line.split("=")[-1].strip())
            if "percentile 90.000" in line:
                p90 = float(line.split("=")[-1].strip())
    # 转换 usec → ms
    if p50: p50 /= 1000.0
    if p90: p90 /= 1000.0
    return p50, p90


def jain_index(bws):
    """计算 Jain's Fairness Index"""
    if not bws:
        return None
    bws = np.array(bws)
    return (bws.sum() ** 2) / (len(bws) * (bws**2).sum())


def collect_results(base_dir=BASE_DIR):
    results = []
    for exp in os.listdir(base_dir):
        exp_dir = os.path.join(base_dir, exp)
        if not os.path.isdir(exp_dir):
            continue
        for run_id in os.listdir(exp_dir):
            run_dir = os.path.join(exp_dir, run_id)
            for flows in os.listdir(run_dir):
                flow_dir = os.path.join(run_dir, flows)

                # ---- 解析带宽 ----
                all_flows = []
                total_bw_sum = 0.0
                for f in os.listdir(flow_dir):
                    if f.startswith("iperf_") and f.endswith(".log"):
                        per_flow, total_bw = parse_iperf_log(os.path.join(flow_dir, f))
                        all_flows.extend(per_flow)
                        total_bw_sum += total_bw  # 各 iperf 进程的 SUM 相加

                fairness = jain_index(all_flows)

                # ---- 解析延迟 ----
                sockperf_log = os.path.join(flow_dir, "sockperf_single.log")
                p50, p90 = (None, None)
                if os.path.exists(sockperf_log):
                    p50, p90 = parse_sockperf_log(sockperf_log)

                results.append({
                    "experiment": exp,
                    "run_id": int(run_id),
                    "flows": int(flows),
                    "total_bw_mbps": total_bw_sum,
                    "jain_index": fairness,
                    "p50_ms": p50,
                    "p90_ms": p90,
                })

    return pd.DataFrame(results)


if __name__ == "__main__":
    df = collect_results(BASE_DIR)
    df.to_csv("summary.csv", index=False)
    print(df)
