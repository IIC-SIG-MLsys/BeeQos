package algproc

import (
	bpf "oncn-bwm/pkg/bpfgo"
	"time"

	log "github.com/sirupsen/logrus"
)

var DaemonProcess *DaemonProc

const (
	MaxObjSize = 5000 // same with MAX_MAP_SIZE
)

const (
	DownReqRate      = 0
	NeedReachLowRate = 1
	ReachedLowRate   = 2

	AllReachedLowRate    = 1
	NotAllReachedLowRate = 0
)

type EdtProcData struct {
	ThrottleCfg  []bpf.TcEdtThrottleCfg
	ThrottleStat []bpf.TcEdtThrottleStat
	IDs          []uint32
	ObjStatus    []uint8
	ValidObjCnt  uint32
	TotalBw      uint64
}

type DaemonProc struct {
	EgressDataEntry  EdtProcData
	IngressDataEntry EdtProcData
	EbpfEdt          *bpf.Tcbpf
	Interval         uint32
}

func NewDaemonProc(egressTotalBw uint64, ingressTotalBw uint64, interval uint32, ebpfEdt *bpf.Tcbpf) *DaemonProc {
	return &DaemonProc{
		EgressDataEntry: EdtProcData{
			ThrottleCfg:  make([]bpf.TcEdtThrottleCfg, MaxObjSize),
			ThrottleStat: make([]bpf.TcEdtThrottleStat, MaxObjSize),
			IDs:          make([]uint32, MaxObjSize),
			ObjStatus:    make([]uint8, MaxObjSize),
			ValidObjCnt:  0,
			TotalBw:      egressTotalBw,
		},
		IngressDataEntry: EdtProcData{
			ThrottleCfg:  make([]bpf.TcEdtThrottleCfg, MaxObjSize),
			ThrottleStat: make([]bpf.TcEdtThrottleStat, MaxObjSize),
			IDs:          make([]uint32, MaxObjSize),
			ObjStatus:    make([]uint8, MaxObjSize),
			ValidObjCnt:  0,
			TotalBw:      ingressTotalBw,
		},

		EbpfEdt:  ebpfEdt,
		Interval: interval,
	}
}

func Clip(val, min, max uint64) uint64 {
	if val < min {
		return min
	} else if val > max {
		return max
	}
	return val
}

func (d *DaemonProc) lookupEdtProcData(direction string) (*EdtProcData, error) {
	var (
		err      error
		stats    []bpf.TcEdtThrottleStat
		cfgs     []bpf.TcEdtThrottleCfg
		procData *EdtProcData
	)

	if direction == "egress" {
		procData = &d.EgressDataEntry
		stats, err = d.EbpfEdt.BatchReadEgressThrottleStat(procData.IDs)
		if err != nil {
			log.Errorf("BatchReadEgressThrottleStat failed, err: %v", err)
			return nil, err
		}

		cfgs, err = d.EbpfEdt.BatchReadEgressThrottleCfg(procData.IDs)
		if err != nil {
			log.Errorf("BatchReadEgressThrottleCfg failed, err: %v", err)
			return nil, err
		}

	} else if direction == "ingress" {
		procData = &d.IngressDataEntry
		stats, err = d.EbpfEdt.BatchReadIngressThrottleStat(procData.IDs)
		if err != nil {
			log.Errorf("BatchReadIngressThrottleStat failed, err: %v", err)
			return nil, err
		}

		cfgs, err = d.EbpfEdt.BatchReadIngressThrottleCfg(procData.IDs)
		if err != nil {
			log.Errorf("BatchReadIngressThrottleCfg failed, err: %v", err)
			return nil, err
		}
	}

	procData.ValidObjCnt = 0
	for index, stat := range stats {
		if stat.T_start != 0 && procData.ThrottleStat[index].T_start == stat.T_start {
			log.Debugf("d.ThrottleStat[%d].T_start: %d, stat.T_start: %d", index, procData.ThrottleStat[index].T_start, stat.T_start)
			stat.Rate = 0
		}

		procData.ThrottleStat[index] = stat
		procData.ThrottleCfg[index] = cfgs[index]
		if stat.Rate > 0 {
			procData.ObjStatus[index] = 1 // 置1表示该对象当前有流量
			procData.ValidObjCnt++
		} else {
			procData.ObjStatus[index] = 0 // 置0表示该对象当前没有流量
		}
	}

	return procData, nil
}

func (d *DaemonProc) updateThrottleCfg(procData *EdtProcData, direction string) {
	if direction == "egress" {
		d.EbpfEdt.BatchWriteEgressThrottleCfg(procData.IDs, procData.ThrottleCfg)
	} else if direction == "ingress" {
		d.EbpfEdt.BatchWriteIngressThrottleCfg(procData.IDs, procData.ThrottleCfg)
	}
}

func (d *DaemonProc) Run(direction string, minBandwidth uint64, pace int, ratio float64) error {
	allocMinRate := func(id int, curRate uint64, reqRate uint64, lowRate uint64) (uint64, uint8) {
		var (
			newReqRate uint64 = curRate
			state      uint8  = DownReqRate
		)
		curF := float64(curRate)
		reqF := float64(reqRate)

		if curF < reqF*ratio {
			deltaBw := int64(reqRate) / int64(pace)
			newReqRate = Clip(reqRate-uint64(deltaBw), minBandwidth, reqRate)
		} else {
			deltaBw := int64(reqRate) / int64(pace)
			newReqRate = Clip(reqRate+uint64(deltaBw), minBandwidth, lowRate)
			if newReqRate < lowRate {
				state = NeedReachLowRate
			} else {
				state = ReachedLowRate
			}
		}
		return newReqRate, state
	}

	for {
		procData, err := d.lookupEdtProcData(direction)
		if err != nil {
			log.Errorf("lookupEdtProcData failed: %v", err)
			continue
		}

		remainBw := int64(procData.TotalBw)
		PriorityAllocPercent := []uint16{10, 20, 70}
		priorityCnt := []uint16{0, 0, 0}
		lowRateReachCnt := 0
		DownReqRateCnt := 0
		AllObjStatus := NotAllReachedLowRate

		for id, stats := range procData.ThrottleStat {
			if procData.ObjStatus[id] == 1 {
				procData.ThrottleCfg[id].ReqRate, procData.ObjStatus[id] = allocMinRate(
					id, stats.Rate, procData.ThrottleCfg[id].ReqRate, procData.ThrottleCfg[id].LowRate)
				remainBw -= int64(procData.ThrottleCfg[id].ReqRate)

				switch procData.ObjStatus[id] {
				case NeedReachLowRate:
					priorityCnt[procData.ThrottleCfg[id].Priority]++
				case ReachedLowRate:
					lowRateReachCnt++
					priorityCnt[procData.ThrottleCfg[id].Priority]++
				case DownReqRate:
					DownReqRateCnt++
				}
			}
		}

		if lowRateReachCnt == int(procData.ValidObjCnt) || (lowRateReachCnt+DownReqRateCnt) == int(procData.ValidObjCnt) {
			AllObjStatus = AllReachedLowRate
		}

		var allocDivide int64
		for prio, count := range priorityCnt {
			if count > 0 {
				allocDivide += int64(PriorityAllocPercent[prio])
			}
		}

		remainBwVary := remainBw
		for id := range procData.ThrottleStat {
			if procData.ObjStatus[id] == NeedReachLowRate && procData.ThrottleStat[id].Rate < procData.ThrottleCfg[id].ReqRate*7/10 {
				priorityCnt[procData.ThrottleCfg[id].Priority]--
				lowRateReachCnt++
				if lowRateReachCnt == int(procData.ValidObjCnt) || (lowRateReachCnt+DownReqRateCnt) == int(procData.ValidObjCnt) {
					AllObjStatus = AllReachedLowRate
				}
				continue
			}

			if remainBw > 0 && procData.ObjStatus[id] == NeedReachLowRate && AllObjStatus == NotAllReachedLowRate {
				deltaBw := int64(remainBw)/(int64(procData.ValidObjCnt)-int64(lowRateReachCnt)-int64(DownReqRateCnt)) + 1
				remainBwVary -= deltaBw
				procData.ThrottleCfg[id].ReqRate += uint64(deltaBw)
			}

			if AllObjStatus == AllReachedLowRate && remainBw > 0 && procData.ObjStatus[id] == ReachedLowRate {
				thisPrio := procData.ThrottleCfg[id].Priority
				deltaBw := int64(remainBw*int64(PriorityAllocPercent[thisPrio])/allocDivide)/int64(priorityCnt[thisPrio]) + 1
				remainBwVary -= deltaBw
				procData.ThrottleCfg[id].ReqRate += uint64(deltaBw)
			}

			if remainBwVary <= 0 {
				break
			}
		}

		d.updateThrottleCfg(procData, direction)
		time.Sleep(time.Duration(d.Interval) * time.Millisecond)
	}
}
