docker build -t godash-with-tools .

docker images

docker save -o gdash-tools godash-with-tools:latest

sudo ctr -n k8s.io i import gdash-tools

docker.io/library/godash-with-tools:latest
