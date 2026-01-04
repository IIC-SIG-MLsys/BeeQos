FROM nginx:alpine

# 拷贝自定义配置
COPY nginx.conf /etc/nginx/nginx.conf

# 默认工作目录，挂载PVC的时候直接挂这里
WORKDIR /var/www/html
