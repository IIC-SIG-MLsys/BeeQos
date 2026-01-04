import re
import numpy as np

# ---------- 测试日志路径 ----------
IPERF_LOG = "logs/beeqos/0/512/iperf_5201.log"
SOCKPERF_LOG = "logs/beeqos/0/8/sockperf_single.log"

# ---------- 解析 iperf ----------
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


# ---------- 解析 sockperf ----------
def parse_sockperf_log(path):
    p50 = p90 = None
    with open(path, "r") as f:
        for line in f:
            if "percentile 50.000" in line:
                p50 = float(line.split("=")[-1].strip())
            if "percentile 90.000" in line:
                p90 = float(line.split("=")[-1].strip())
    if p50: p50 /= 1000.0  # usec -> ms
    if p90: p90 /= 1000.0
    return p50, p90

# ---------- Jain Index ----------
def jain_index(bws):
    if not bws:
        return None
    bws = np.array(bws)
    return (bws.sum() ** 2) / (len(bws) * (bws**2).sum())

# ---------- 测试 ----------
per_flow, total = parse_iperf_log(IPERF_LOG)
p50, p90 = parse_sockperf_log(SOCKPERF_LOG)
fairness = jain_index(per_flow)

print("单流带宽 (Mbps):", per_flow)
print("总带宽 (Mbps):", total)
print("Jain Index:", fairness)
print("P50 延迟 (ms):", p50)
print("P90 延迟 (ms):", p90)
