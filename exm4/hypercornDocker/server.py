from functools import partial
import trio
from hypercorn.trio import serve
from hypercorn.config import Config
from quart import send_from_directory
from quart_trio import QuartTrio
from os import path

# 你的 DASH 内容目录（挂载 PVC）
dash_content_path = '/var/www/html/'

# Hypercorn 配置（只启用 TCP 80/443，不跑 QUIC）
config = Config()
config.bind = ["0.0.0.0:80"]   # HTTP
# config.bind += ["0.0.0.0:443"] # HTTPS
# config.certfile = "/app/certs/tls.crt"
# config.keyfile = "/app/certs/tls.key"
config.workers = 8

# App
app = QuartTrio(__name__, root_path=dash_content_path)

@app.errorhandler(404)
async def page_not_found(error):
    return 'File not found', 404

@app.route('/')
async def root():
    return await send_from_directory(dash_content_path, 'index.html'), 200

@app.route('/<path:path_to_DASH_files>')
async def index(path_to_DASH_files=dash_content_path):
    path_to_file = path.join(dash_content_path, path_to_DASH_files)
    if not path.isfile(path_to_file):
        return path_to_file + ' : File not found', 404
    return await send_from_directory(dash_content_path, path_to_DASH_files), 200

# 启动
trio.run(partial(serve, app, config))
