import os
import pandas as pd

# 根目录
BASE_DIR = "logs/dash_exm"

# 输出目录
OUTPUT_DIR = "./logs/excel"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def extract_p1203_from_log(filepath):
    """从单个日志文件中提取 P.1203 列"""
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # 找到标题行
    header_line = None
    for i, line in enumerate(lines):
        if "Seg_#" in line and "P.1203" in line:
            header_line = i
            break

    if header_line is None:
        print(f"文件 {filepath} 未找到标题行，跳过")
        return None

    # 用 pandas 读表格（以空格分隔）
    df = pd.read_csv(
        filepath,
        delim_whitespace=True,
        skiprows=header_line,
    )

    if "P.1203" not in df.columns:
        print(f"文件 {filepath} 没有 P.1203 列，跳过")
        return None

    return df["P.1203"].reset_index(drop=True)


def main():
    # 保存不同算法的结果
    grouped_results = {
        "beeqos": [],
        "htb": [],
        "no-shaper": [],
        "cilium": [],
        "ideal": []
    }

    for root, dirs, files in os.walk(BASE_DIR):
        for file in files:
            if file.endswith(".log"):
                filepath = os.path.join(root, file)
                p1203 = extract_p1203_from_log(filepath)
                if p1203 is not None:
                    # 识别算法目录（beeqos/htb/no-shaper）
                    algo = None
                    for key in grouped_results.keys():
                        if key in filepath:
                            algo = key
                            break
                    if algo:
                        grouped_results[algo].append(pd.DataFrame({
                            "file": file,
                            "path": filepath,
                            "p1203": p1203
                        }))

    # 写入 Excel 文件 & 统计均值方差
    for algo, dfs in grouped_results.items():
        if dfs:
            final_df = pd.concat(dfs, ignore_index=True)
            output_file = os.path.join(OUTPUT_DIR, f"{algo}.xlsx")
            final_df.to_excel(output_file, index=False, sheet_name="p1203")
            print(f"{algo} 数据已保存到 {output_file}")

            # 计算均值和方差
            mean_val = final_df["p1203"].mean()
            var_val = final_df["p1203"].var()
            print(f"📊 {algo} 的 P.1203: 均值={mean_val:.4f}, 方差={var_val:.4f}")
        else:
            print(f"没有找到 {algo} 的数据")


if __name__ == "__main__":
    main()
