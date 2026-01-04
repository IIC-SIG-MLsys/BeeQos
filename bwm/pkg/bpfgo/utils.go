package bpf

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/pkg/errors"

	netns "github.com/containernetworking/plugins/pkg/ns"
	log "github.com/sirupsen/logrus"
)

func isPathValid(p string) (bool, error) {
	_, err := os.Stat(p)
	if err == nil {
		return true, nil
	}

	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

func getFileName(path string) (string, error) {
	fileName := filepath.Base(path)
	return fileName, nil
}

func executeCommands(commands []string, variables map[string]string, checkRet []bool) error {
	for index, cmd := range commands {
		for key, value := range variables {
			cmd = strings.ReplaceAll(cmd, "{"+key+"}", value)
		}
		// fmt.Println("Executing command:", cmd)
		command := exec.Command("bash", "-c", cmd)
		stdout, err := command.CombinedOutput()
		// err := command.Run()
		if checkRet[index] && err != nil {
			fmt.Printf("[ERRMSG]: %s", stdout)
			return err
		}
	}
	return nil
}

func checkPathValid(path string) error {
	info, err := os.Stat(path)
	if err != nil || info.Mode()&os.ModeType != os.ModePerm {
		return fmt.Errorf("CgrpV1Prio get realPath failed. err: %v", err)
	}

	return nil
}

// 低16位存放优先级，高16位存放Pod ID（生成的）
func GenerateClassId(priority uint32, podId uint16) uint32 {
	classId := (uint32(podId) << 16) | priority
	return classId
}

func SetEgressClassid(classidPath string, classid uint32) error {
	file, err := os.OpenFile(classidPath, os.O_RDWR|os.O_APPEND, 0)
	if err != nil {
		fmt.Println("failed to open classid file path: %v, %v", classidPath, err)
		return err
	}
	defer file.Close()

	str := strconv.FormatUint(uint64(classid), 10)
	if err := ExecuteWithRedirect("echo", []string{str}, file); err != nil {
		fmt.Println("failed to exec cmd with redirect: %v", err)
		return err
	}

	return nil
}

func executeCore(cmd string, args []string, stdout, stderr io.Writer) error {
	var err error

	cmdPath, err := exec.LookPath(cmd)
	if err != nil {
		fmt.Println("command failed to get path")
		return err
	}

	args = append([]string{cmd}, args...)
	if stdout == nil {
		stdout = &bytes.Buffer{}
	}

	command := exec.Cmd{
		Path:   cmdPath,
		Args:   args,
		Stdout: stdout,
		Stderr: stderr,
	}

	command.Run()
	return nil
}

func ExecuteWithRedirect(cmd string, args []string, stdout io.Writer) error {
	if stdout == nil {
		return fmt.Errorf("stdout can not be null in output redirect mode!")
	}
	stderr := &bytes.Buffer{}
	err := executeCore(cmd, args, stdout, stderr)
	if len(stderr.String()) != 0 {
		err = fmt.Errorf("command error output: %s", stderr.String())
		return err
	}
	return nil
}

type tcCommand struct {
	cmdStr    string
	verifyRet bool
}

func doCmdExecute(cmds []tcCommand, interfaceName string) error {
	var err error

	for _, value := range cmds {
		cmd := fmt.Sprintf(value.cmdStr, interfaceName)
		command := exec.Command("bash", "-c", cmd)
		stdout, err := command.CombinedOutput()
		if value.verifyRet && err != nil {
			log.Errorf("cmd run failed, command output: %s", string(stdout))
			return err
		}

		log.Debugf("command output: %s", string(stdout))
	}

	return err
}

func doCmd(commands []tcCommand, interfaceName string, namespace string) error {
	var err error
	execFunc := func(netns.NetNS) error {
		err := doCmdExecute(commands, interfaceName)
		return err
	}

	if namespace != "" {
		err = netns.WithNetNSPath(namespace, execFunc)
	} else {
		err = doCmdExecute(commands, interfaceName)
	}

	if err != nil {
		err = fmt.Errorf("cmd execute failed, namespace: %s, dev: %s, err: %v", namespace, interfaceName, err)
		return err
	}

	return err
}

func checkQosEnabled(cmd string) error {
	output, err := exec.Command("bash", "-c", cmd).CombinedOutput()

	if err != nil {
		// 如果执行出错，说明没有挂载对应的 eBPF 程序
		return fmt.Errorf("without ebpf loaded")
	}

	if len(output) == 0 {
		// 如果命令执行成功且没有输出，说明挂载了相应的 eBPF 程序
		return nil
	}

	// 如果有输出，说明没有挂载对应的 eBPF 程序
	return fmt.Errorf("without ebpf loaded")
}

func IsDevQosEnabled(interfaceName string, namespace string) (bool, error) {
	cmd := fmt.Sprintf("tc filter show dev %s egress | grep -E %s >/dev/null 2>&1", interfaceName, "'bpfel.o|bpfeb.o'") // 小端问题
	execFunc := func(netns.NetNS) error {
		log.Debugf("Running check cmd in namespace: %s", namespace)
		return checkQosEnabled(cmd)
	}

	if namespace != "" {
		err := netns.WithNetNSPath(namespace, execFunc)
		if err != nil {
			return false, fmt.Errorf("%v", err)
		}
	} else {
		err := checkQosEnabled(cmd)
		if err != nil {
			log.Errorf("doCmdExecute failed: %v", err)
			return false, fmt.Errorf("%v", err)
		}
	}

	return true, nil
}

func EnableDevQos(interfaceName string, namespace string, section string) error {
	log.Debugf("enable dev: %s qos in namespace: %s", interfaceName, namespace)
	commands := []tcCommand{
		// {"tc qdisc replace dev %s root mq", true},
		{"tc qdisc replace dev %s root fq", true},
		{"tc qdisc replace dev %s clsact", true},
		{"tc filter replace dev %s egress pref 2 handle 1 bpf da obj " + EdtBpfProgPath + " sec " + section, true},
	}

	err := doCmd(commands, interfaceName, namespace)
	if err != nil {
		return errors.Errorf("doCmd failed, err: %v", err)
	}

	return nil
}

func DisableDevQos(interfaceName string, namespace string) error {
	mounted, err := IsDevQosEnabled(interfaceName, namespace)
	if err != nil { // 检查挂载出错，也按出错处理
		log.Errorf("IsDevQosEnabled run failed, err: %v", err)
		return err
	}
	if !mounted { // 之前没有挂载，直接跳过
		log.Infof("dev: %s qos already disable", interfaceName)
		return nil
	}

	commands := []tcCommand{
		{"tc filter del dev %s egress pref 2", false},
		//{"tc filter del dev %s ingress pref 1", false},
	}

	err = doCmd(commands, interfaceName, namespace)
	if err != nil {
		log.Errorf("doCmd failed, err: %v", err)
		return err
	}

	return nil
}
