import os
import re
import csv

LOG_ROOT = "logs"
experiments = ["beeqos", "htb", "no-shaper", "cilium"]
rounds = range(10)
clients = ["c1", "c2", "c3"]

# 去掉 ANSI 颜色码
ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

# 带宽正则
bw_pattern = re.compile(r'BandWidth is .* \(([\d.]+) Mbps\)')

# 延迟正则
lat_pattern = re.compile(r'percentile\s*([\d.]+)\s*=\s*([\d.]+)')

output_file = "experiment_results.csv"

with open(output_file, 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["experiment", "round", "client", "bandwidth_mbps", "lat_p50_usec", "lat_p90_usec", "lat_p99_usec"])

    for exp in experiments:
        for rnd in rounds:
            for client in clients:
                bw_log_path = os.path.join(LOG_ROOT, exp, str(rnd), client, "bw.log")
                lat_log_path = os.path.join(LOG_ROOT, exp, str(rnd), client, "lat.log")

                bandwidth = None
                lat_p50 = None
                lat_p90 = None
                lat_p99 = None

                # 提取带宽
                if os.path.exists(bw_log_path):
                    with open(bw_log_path, 'r', encoding='utf-8', errors='ignore') as f:
                        for line in f:
                            line = ansi_escape.sub('', line)  # 去掉颜色码
                            match = bw_pattern.search(line)
                            if match:
                                bandwidth = float(match.group(1))
                                break

                # 提取延迟
                if os.path.exists(lat_log_path):
                    with open(lat_log_path, 'r', encoding='utf-8', errors='ignore') as f:
                        for line in f:
                            line = ansi_escape.sub('', line)  # 去掉颜色码
                            match = lat_pattern.search(line)
                            if match:
                                perc = float(match.group(1))
                                value = float(match.group(2))
                                if perc == 50.0:
                                    lat_p50 = value
                                elif perc == 90.0:
                                    lat_p90 = value
                                elif perc == 99.0:
                                    lat_p99 = value

                writer.writerow([exp, rnd, client, bandwidth, lat_p50, lat_p90, lat_p99])

print(f"数据提取完成，结果已保存到 {output_file}")
