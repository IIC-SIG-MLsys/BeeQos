# case
web视频应用+web下载服务容器
通过测量视频的Qoe来反映下载业务对视频的影响
通过iperf模拟下载服务

# 视频容器
```
# 构建hypercorn的dash server镜像
docker build --network=host --add-host pypi.tuna.tsinghua.edu.cn:101.6.15.130 \
    -t beeqos/dash-server-hypercorn:latest .

# 构建nginx的dash server
docker build --network=host \
    -t beeqos/dash-server-nginx:latest .
```
```
# 准备、分发容器
bash preapre_images_distribute.sh root 10.102.0.235 /beeqos/k8s
```

视频服务：
## 自己处理视频样本
https://github.com/chthomos/video-media-samples
big-buck-bunny-1080p-60fps-30sec.mp4
```
# 处理生成三种清晰度的视频，30s视频转为10分钟播放
cd video && mkdir -p dash_content && \
ffmpeg -stream_loop 19 -i big-buck-bunny-1080p-60fps-30sec.mp4 \
  -map 0:v -map 0:a \
  -c:v libx264 -c:a aac -ar 48000 \
  -b:v:0 800k  -s:v:0 640x360   \
  -b:v:1 1600k -s:v:1 1280x720  \
  -b:v:2 3000k -s:v:2 1920x1080 \
  -use_template 1 -use_timeline 1 \
  -adaptation_sets "id=0,streams=v id=1,streams=a" \
  -f dash dash_content/manifest.mpd && cd -
```
```
# 分发视频文件
ssh root@10.102.0.235 "mkdir -p /beeqos/video"
scp -r video/dash_content root@10.102.0.235:/beeqos/video/
ssh root@10.102.0.235 "chmod 755 /beeqos/video/dash_content/"
```

## 直接下载
```
ssh root@10.102.0.235 "mkdir -p /beeqos/video/hypercorn_dash_content"
ssh root@10.102.0.235 'cd /beeqos/video/hypercorn_dash_content && bash -s' < ./hypercornDocker/get_movies.sh
ssh root@10.102.0.235 "chmod 755 /beeqos/video/hypercorn_dash_content/"
```

```
# 启动视频容器
kubectl apply -f yamls/dash_server_hypercorn.yaml
# kubectl delete -f yamls/dash_server_hypercorn.yaml

## 启动了一个nodePort，用于查看状态
kubectl get svc dash-service
NAME           TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
dash-service   NodePort   10.98.48.21   <none>        8080:32232/TCP   3m14s
访问 http://10.102.0.235:31080
```

# 测试
```
# 在本地启动一个 godash 容器测试
mkdir -p /home/liujinyao/k8s/BeeQos/exm6/logs && sudo chmod 755 /home/liujinyao/k8s/BeeQos/exm6/logs
kubectl apply -f yamls/godash.yaml
# kubectl delete -f yamls/godash.yaml
```

```
kubectl get pods -o wide
kubectl describe pod godash-job-vzbfh 
kubectl logs godash-job-9429l
kubectl exec -it godash-job-d59bk -- curl -v http://10.255.24.10:80/dash/manifest.mpd

cat > configure.json << 'EOF'
{
        "adapt" : "arbiter",
        "codec" : "h264",
        "debug" : "on",
        "initBuffer" : 2,
        "maxBuffer" : 60,
        "maxHeight" : 1080,
        "streamDuration" : 40,
        "storeDash" : "off",
        "outputFolder" : "123456",
        "logFile" : "log_file_2",
        "getHeaders" : "off",
        "terminalPrint" : "on",
        "expRatio": 0.2,
        "quic" : "off",
        "useTestbed" : "off",
        "url" : "[http://10.255.24.10/dash/manifest.mpd]",
        "QoE" : "on",
        "serveraddr" : "off"
}
EOF

chmod 755 configure.json 
```

```
cd godash
./godash -config /logs/configure_beeqos.conf
```


# 跑试验
```
bash run.sh
```