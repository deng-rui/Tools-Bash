# FRP 管理工具

FRP 服务端/客户端管理脚本

## 快速安装

```bash
# 一键安装
bash <(curl -sSL https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main/Frp/install.sh)

# 或单独安装
bash <(curl -sSL https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main/Frp/frps_manager.sh)  # 服务端
bash <(curl -sSL https://raw.githubusercontent.com/deng-rui/Tools-Bash/refs/heads/main/Frp/frpc_manager.sh)  # 客户端
```

## 配置模板

### 服务端

| 模板 | 说明 |
|------|------|
| 基础 | 纯TCP，适合简单转发 |
| 标准 | 带HTTP/HTTPS和面板，推荐 |
| 高级 | 完整功能 |

### 客户端

| 模板 | 说明 |
|------|------|
| 基础 | SSH端口转发 |
| Web | HTTP/HTTPS穿透 |

## 使用示例

### SSH远程

**服务端**:
```bash
./frps_manager.sh
# 1.安装 -> 2.标准 -> 输入令牌
```

**客户端**:
```bash
./frpc_manager.sh
# 1.安装 -> 1.基础 -> 输入服务器和令牌
```

**连接**:
```bash
ssh -p 6000 user@服务器IP
```

### Web穿透

服务端选标准模板，客户端选Web模板配置域名，然后把域名解析到服务器就行

### 添加代理

```bash
./frpc_manager.sh
# 3.添加代理 -> 选类型 -> 填参数
```

支持: TCP、UDP、HTTP、HTTPS、STCP

## 管理命令

```bash
# 服务
systemctl start/stop/restart frps/frpc
systemctl status frps/frpc

# 日志
journalctl -u frps/frpc -f

# 配置
/usr/local/frp/frps.toml
/usr/local/frp/frpc.toml
```
