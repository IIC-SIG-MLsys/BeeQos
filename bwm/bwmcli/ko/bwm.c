/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2020-2022. All rights reserved.
 * Description: Network bandwidth management tool
 */
#include "bwm.h"

static char *envp[] = { "HOME=/", "PATH=/sbin:/usr/sbin:/bin:/usr/bin", NULL };

static ssize_t proc_value_get(const char __user *buffer, unsigned long count, char *value)
{
	if (count == 0 || count >= MAX_BUF_SIZE) {
		return -EINVAL;
	}

	if (copy_from_user(value, buffer, count)) {
		return -EINVAL;
	}

	value[count - 1] = '\0';

	return 0;
}

static int proc_net_qos_enable_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_enable);
	return 0;
}

static int proc_net_qos_enable_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_enable_open, NULL);
}

static int qos_cmd_upcall(char *cmd)
{
	int ret = 0;
	char *argv[] = {
		"/bin/bash",
		"-c",
		cmd,
		NULL,
	};

	ret = call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC);
	if (ret) {
		BWM_LOG_ERR("call_usermodehelper failed, ret = %d", ret);
	}

	return ret;
}

static ssize_t proc_net_qos_enable_write(struct file *file, const char __user *buffer,
										 unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char nspid[MAX_BUF_SIZE] = { 0 };
	char cmd[MAX_CMD_LEN] = { 0 };

	ret = proc_value_get(buffer, count, nspid);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}
	BWM_LOG_DEBUG("get nspid %s", nspid);

	ret = snprintf(cmd, MAX_CMD_LEN, "%s -n -t %s %s -e", NSENTER_PATH, nspid, BWMCLI_PATH);
	if (ret < 0) {
		BWM_LOG_ERR("failed to snprintf enable qos cmd");
		return ret;
	}
	BWM_LOG_DEBUG("enable qos cmd:%s", cmd);

	ret = qos_cmd_upcall(cmd);
	if (ret != 0) {
		BWM_LOG_ERR("qos_enable_upcall failed");
	}

	return count;
}

static int proc_net_qos_disable_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_disable);
	return 0;
}

static int proc_net_qos_disable_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_disable_open, NULL);
}

static ssize_t proc_net_qos_disable_write(struct file *file, const char __user *buffer,
										  unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char nspid[MAX_BUF_SIZE] = { 0 };
	char cmd[MAX_CMD_LEN] = { 0 };

	ret = proc_value_get(buffer, count, nspid);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}
	BWM_LOG_DEBUG("get nspid %s.", nspid);

	ret = snprintf(cmd, MAX_CMD_LEN, "%s -n -t %s %s -d", NSENTER_PATH, nspid, BWMCLI_PATH);
	if (ret < 0) {
		BWM_LOG_ERR("failed to snprintf disable qos cmd");
		return ret;
	}
	BWM_LOG_DEBUG("disable qos cmd:%s", cmd);

	ret = qos_cmd_upcall(cmd);
	if (ret != 0) {
		BWM_LOG_ERR("disable qos failed");
	}

	return count;
}

static int proc_net_qos_bandwidth_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_bandwidth);
	return 0;
}

static int proc_net_qos_bandwidth_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_bandwidth_open, NULL);
}

static ssize_t proc_net_qos_bandwidth_write(struct file *file, const char __user *buffer,
											unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char bandwidth[MAX_BUF_SIZE] = { 0 };
	char cmd[MAX_CMD_LEN] = { 0 };

	ret = proc_value_get(buffer, count, bandwidth);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}
	BWM_LOG_DEBUG("change net_qos_bandwidth to %s.", bandwidth);

	ret = snprintf(cmd, MAX_CMD_LEN, "%s -s bandwidth %s", BWMCLI_PATH, bandwidth);
	if (ret < 0) {
		BWM_LOG_ERR("failed to snprintf bandwidth cmd");
		return ret;
	}
	BWM_LOG_DEBUG("set bandwidth cmd : %s", cmd);

	ret = qos_cmd_upcall(cmd);
	if (ret != 0) {
		BWM_LOG_ERR("set bandwidth failed");
		return ret;
	}

	ret = snprintf(net_qos_bandwidth, MAX_BUF_SIZE, "%s", bandwidth);
	if (ret < 0) {
		BWM_LOG_ERR("failed to write net_qos_bandwidth");
		return ret;
	}

	return count;
}

static int proc_net_qos_waterline_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_waterline);
	return 0;
}

static int proc_net_qos_waterline_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_waterline_open, NULL);
}

static ssize_t proc_net_qos_waterline_write(struct file *file, const char __user *buffer,
											unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char waterline[MAX_BUF_SIZE] = { 0 };
	char cmd[MAX_CMD_LEN] = { 0 };

	ret = proc_value_get(buffer, count, waterline);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}
	BWM_LOG_DEBUG("change net_qos_waterline to %s.", waterline);

	ret = snprintf(cmd, MAX_CMD_LEN, "%s -s waterline %s", BWMCLI_PATH, waterline);
	if (ret < 0) {
		BWM_LOG_ERR("failed to snprintf waterline cmd");
		return ret;
	}
	BWM_LOG_DEBUG("set waterline cmd : %s", cmd);

	ret = qos_cmd_upcall(cmd);
	if (ret != 0) {
		BWM_LOG_ERR("set waterline failed");
		return ret;
	}

	ret = snprintf(net_qos_waterline, MAX_BUF_SIZE, "%s", waterline);
	if (ret < 0) {
		BWM_LOG_ERR("failed to write net_qos_waterline");
		return ret;
	}

	return count;
}

static int proc_net_qos_devs_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_devs);
	return 0;
}

static int proc_net_qos_devs_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_devs_open, NULL);
}

static ssize_t proc_net_qos_devs_write(struct file *file, const char __user *buffer,
									   unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char nspid[MAX_BUF_SIZE] = { 0 };
	char cmd[MAX_CMD_LEN] = { 0 };

	ret = proc_value_get(buffer, count, nspid);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}
	BWM_LOG_DEBUG("write nspid:%s to net_qos_devs", nspid);

	ret = snprintf(cmd, MAX_CMD_LEN, "%s -n -t %s %s -p devs > /proc/qos/net_qos_devstatus",
				   NSENTER_PATH, nspid, BWMCLI_PATH);
	if (ret < 0) {
		BWM_LOG_ERR("failed to snprintf devs status cmd");
		return ret;
	}
	BWM_LOG_DEBUG("get devs status cmd:%s", cmd);

	ret = qos_cmd_upcall(cmd);
	if (ret != 0) {
		BWM_LOG_ERR("write net_qos_devs failed");
	}

	return count;
}

static int proc_net_qos_devstatus_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_devstatus);
	return 0;
}

static int proc_net_qos_devstatus_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_devstatus_open, NULL);
}

static ssize_t proc_net_qos_devstatus_write(struct file *file, const char __user *buffer,
											unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char data[MAX_BUF_SIZE] = { 0 };

	ret = proc_value_get(buffer, count, data);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}

	ret = snprintf(net_qos_devstatus, MAX_DATA_SIZE, "%s", data);
	if (ret < 0) {
		BWM_LOG_ERR("write net_qos_devstatus failed");
	}

	return count;
}

static atomic_t stats_flag = ATOMIC_INIT(0);

static int proc_net_qos_stats_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%s\n", net_qos_stats);
	return 0;
}

static int proc_net_qos_stats_single_open(struct inode *inode, struct file *file)
{
	int ret = 0;
	char cmd[MAX_CMD_LEN] = { 0 };

	if (atomic_read(&stats_flag) == 0) {
		ret = snprintf(cmd, MAX_CMD_LEN, "%s -p stats > /proc/qos/net_qos_stats", BWMCLI_PATH);
		if (ret < 0) {
			BWM_LOG_ERR("failed to snprintf stats cmd");
			return ret;
		}
		BWM_LOG_DEBUG("stats cmd:%s", cmd);

		atomic_xchg(&stats_flag, 1);
		ret = qos_cmd_upcall(cmd);
		if (ret != 0) {
			BWM_LOG_ERR("read net_qos_stats failed");
		}
	}
	atomic_xchg(&stats_flag, 0);
	return single_open(file, proc_net_qos_stats_open, NULL);
}

static ssize_t proc_net_qos_stats_write(struct file *file, const char __user *buffer,
										unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char stats[MAX_BUF_SIZE] = { 0 };

	ret = proc_value_get(buffer, count, stats);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}

	ret = snprintf(net_qos_stats, MAX_DATA_SIZE, "%s", stats);
	if (ret < 0) {
		BWM_LOG_ERR("write net_qos_stats failed");
	}

	return count;
}

static int proc_net_qos_version_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "version:%s\n", net_qos_version);
	return 0;
}

static int proc_net_qos_version_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_version_open, NULL);
}

static int proc_net_qos_debug_open(struct seq_file *seq, void *offset)
{
	seq_printf(seq, "%u\n", net_qos_debug);
	return 0;
}

static int proc_net_qos_debug_single_open(struct inode *inode, struct file *file)
{
	return single_open(file, proc_net_qos_debug_open, NULL);
}

static ssize_t proc_net_qos_debug_write(struct file *file, const char __user *buffer,
										unsigned long count, loff_t *ppos)
{
	int ret = 0;
	char debug_mode[MAX_BUF_SIZE] = { 0 };
	unsigned int net_qos_debug_new = net_qos_debug;

	ret = proc_value_get(buffer, count, debug_mode);
	if (ret != 0) {
		BWM_LOG_ERR("proc_value_get failed");
		return count;
	}

	net_qos_debug_new = simple_strtoul(debug_mode, NULL, 0);
	if (net_qos_debug_new != 0 && net_qos_debug_new != 1) {
		BWM_LOG_ERR("invalid input of debug mode(%d), valid input: 0 or 1.", net_qos_debug_new);
		return count;
	}

	BWM_LOG_INFO("change debug mode, old is %u, new is %u.", net_qos_debug, net_qos_debug_new);
	net_qos_debug = net_qos_debug_new;

	return count;
}

static struct proc_ops bwm_proc_net_qos_enable_ops = {
    .proc_open = proc_net_qos_enable_single_open,
    .proc_write = proc_net_qos_enable_write,
    .proc_read = seq_read,
    .proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_disable_ops = {
    .proc_open = proc_net_qos_disable_single_open,
    .proc_write = proc_net_qos_disable_write,
    .proc_read = seq_read,
    .proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_bandwidth_ops = {
	.proc_open = proc_net_qos_bandwidth_single_open,
	.proc_write = proc_net_qos_bandwidth_write,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_waterline_ops = {
	.proc_open = proc_net_qos_waterline_single_open,
	.proc_write = proc_net_qos_waterline_write,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_devs_ops = {
	.proc_open = proc_net_qos_devs_single_open,
	.proc_write = proc_net_qos_devs_write,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_devstatus_ops = {
	.proc_open = proc_net_qos_devstatus_single_open,
	.proc_write = proc_net_qos_devstatus_write,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_stats_ops = {
	.proc_open = proc_net_qos_stats_single_open,
	.proc_write = proc_net_qos_stats_write,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_version_ops = {
	.proc_open = proc_net_qos_version_single_open,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct proc_ops bwm_proc_net_qos_debug_ops = {
	.proc_open = proc_net_qos_debug_single_open,
	.proc_write = proc_net_qos_debug_write,
	.proc_read = seq_read,
	.proc_release = single_release,
};

static struct bwm_proc g_proc_table[] = {
	{
		.proc_name = "net_qos_enable",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_enable_ops,
	},
	{
		.proc_name = "net_qos_disable",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_disable_ops,
	},
	{
		.proc_name = "net_qos_bandwidth",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_bandwidth_ops,
	},
	{
		.proc_name = "net_qos_waterline",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_waterline_ops,
	},
	{
		.proc_name = "net_qos_devs",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_devs_ops,
	},
	{
		.proc_name = "net_qos_devstatus",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_devstatus_ops,
	},
	{
		.proc_name = "net_qos_stats",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_stats_ops,
	},
	{
		.proc_name = "net_qos_version",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_version_ops,
	},
	{
		.proc_name = "net_qos_debug",
		.entry = NULL,
		.ops = &bwm_proc_net_qos_debug_ops,
	},
};

static int bwm_proc_init(void)
{
	unsigned int i;
	int ret = 0;

	bwm_proc_root_dir = proc_mkdir(BWM_PROC_ROOTDIR, NULL);
	if (!bwm_proc_root_dir) {
		BWM_LOG_ERR("can't create /proc/%s.", BWM_PROC_ROOTDIR);
		return -EFAULT;
	}

	for (i = 0; i < sizeof(g_proc_table) / sizeof(struct bwm_proc); i++) {
		g_proc_table[i].entry = proc_create_seq_data(g_proc_table[i].proc_name, BWM_CTL_PROC_PERM,
													 bwm_proc_root_dir, NULL, NULL);
		if (!g_proc_table[i].entry) {
			BWM_LOG_ERR("can't create file(%s).", g_proc_table[i].proc_name);
			ret = -EFAULT;
			break;
		}
		g_proc_table[i].entry->proc_ops = g_proc_table[i].ops;
	}

	if (ret != 0) {
		BWM_LOG_ERR("bwm_proc_init failed");
	}

	return ret;
}

static void bwm_proc_clean(void)
{
	unsigned int i;

	if (bwm_proc_root_dir) {
		for (i = 0; i < sizeof(g_proc_table) / sizeof(struct bwm_proc); i++) {
			if (g_proc_table[i].entry) {
				remove_proc_entry(g_proc_table[i].proc_name, bwm_proc_root_dir);
				g_proc_table[i].entry = NULL;
			}
		}
		remove_proc_entry(BWM_PROC_ROOTDIR, NULL);
		bwm_proc_root_dir = NULL;
	}
}

static int __init bwm_init(void)
{
	int ret = 0;

	ret = bwm_proc_init();
	if (ret != 0) {
		bwm_proc_clean();
		return ret;
	}

	BWM_LOG_INFO("bwm loaded");
	return ret;
}

static void __exit bwm_exit(void)
{
	bwm_proc_clean();
	BWM_LOG_INFO("bwm unloaded");
}

module_init(bwm_init);
module_exit(bwm_exit);
MODULE_LICENSE("GPL");
