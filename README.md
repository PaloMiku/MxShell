# MixSpace 的前后端一键安装脚本 

<img src="https://cdn.jsdelivr.net/gh/mx-space/.github@main/uwu.png" />

## 食用

### 海外服务器

```bash
curl -sSL https://raw.githubusercontent.com/PaloMiku/MxShell/refs/heads/main/install.sh -o install.sh && bash install.sh
```

### 国内服务器

使用 Moeyy 的Github加速源。

```bash
curl -sSL https://github.moeyy.xyz/https://raw.githubusercontent.com/PaloMiku/MxShell/refs/heads/main/install.sh -o install.sh && bash install.sh
```

目前它能做到的：

- 自动切换 Docker 安装源和镜像源
- 交互式安装 MixSpace 前后端（Docker）
- 无人值守（预配置）安装 MixSpace 前后端

## 无人值守（预配置）

参考[官方文档](https://mx-space.js.org)和内标注释修改本仓库的`mxconfig.yml`文件，并将其放置在与脚本同一目录后执行脚本。

## Todo

[ ] 交互式生成无人值守的配置文件，让部署更简单！

[ ] 实现更多部署方式，未来可能性可选的反代协助配置。

[ ] 支持更多系统架构。

## 注意

- 目前仅对运行着Debian，Ubuntu，CentOS服务器提供支持
- 这个脚本目前经历的使用测试依旧较少（2025.03.26），如有问题请及时反馈（issue），如果你能解决建议直接 Pull（）
- 本脚本目前仅提供通过 Docker 部署的 MixSpace 前后端容器程序，不提供反代和进阶部署配置。
---

This uwu logo was created by [Arthals](https://github.com/zhuozhiyongde) and all rights reserved.