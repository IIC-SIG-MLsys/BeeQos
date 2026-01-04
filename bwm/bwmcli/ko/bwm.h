/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2020-2022. All rights reserved.
 * Description: Network bandwidth management tool
 */
#ifndef NET_BWM_H
#define NET_BWM_H

#include <asm/atomic.h>
#include <linux/delay.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/types.h>
#include <fs/proc/internal.h>

#define BWM_PROC_ROOTDIR		"qos"
#define BWM_CTL_PROC_PERM		0644

#define NSENTER_PATH			"/usr/bin/nsenter"
#define BWMCLI_PATH			"/usr/bin/bwmcli"

#define MAX_BUF_SIZE			128
#define MAX_CMD_LEN			(256 + NAME_MAX)
#define MAX_DATA_SIZE			1024

static char net_qos_disable[] = "please write <nspid> to net_qos_disable to disable qos";
static char net_qos_enable[] = "please write <nspid> to net_qos_enable to enable qos";
static char net_qos_bandwidth[MAX_BUF_SIZE];
static char net_qos_waterline[MAX_BUF_SIZE];
static char net_qos_devs[] = "please write <nspid> to net_qos_devs and read dev status from net_qos_devstatus";
static char net_qos_devstatus[MAX_DATA_SIZE];
static char net_qos_stats[MAX_DATA_SIZE];
static char net_qos_version[] = "1.1";
static unsigned int net_qos_debug = 0;

static struct proc_dir_entry *bwm_proc_root_dir = NULL;

struct bwm_proc {
	const char *proc_name;
	struct proc_dir_entry *entry;
	struct proc_ops *ops;
};

#define PFX "BWM"

#define BWM_LOG_INFO(fmt, ...)																			\
	do {																								\
		printk(KERN_INFO "[" PFX "] INFO:" fmt "[%s():%u]\n", ##__VA_ARGS__, __FUNCTION__, __LINE__); 	\
	} while (0)

#define BWM_LOG_NOTICE(fmt, ...)																		\
	do {																								\
		printk(KERN_NOTICE "[" PFX "] NOTICE:" fmt, ##__VA_ARGS__);										\
	} while (0)

#define BWM_LOG_ERR(fmt, ...)																			\
	do {																								\
		printk(KERN_ERR "[" PFX "] ERROR:" fmt "[%s():%u]\n", ##__VA_ARGS__, __FUNCTION__, __LINE__); 	\
	} while (0)

#define BWM_LOG_DEBUG(fmt, ...)																				\
	do {																									\
		if (net_qos_debug == 1) {																			\
			printk(KERN_DEBUG "[" PFX "] DEBUG:" fmt "[%s():%u]\n", ##__VA_ARGS__, __FUNCTION__, __LINE__); \
		}																									\
	} while (0)

#endif
