# MixSpace 后端一键安装脚本

<img src="https://cdn.jsdelivr.net/gh/mx-space/.github@main/uwu.png" />

## 使用说明

### 海外服务器

```bash
curl -sSL https://raw.githubusercontent.com/PaloMiku/MxShell/refs/heads/main/install/core.sh -o core.sh && bash core.sh
```

### 国内服务器

使用 Moeyy 的 GitHub 加速源。

```bash
curl -sSL https://github.moeyy.xyz/https://raw.githubusercontent.com/PaloMiku/MxShell/refs/heads/main/install/core.sh -o core.sh && bash core.sh
```

当前脚本功能包括：

- 自动切换 Docker 安装源及镜像源（使用 linuxmirrors.cn 的脚本实现）
- 提供交互式安装 MixSpace 后端（基于 Docker）
- 支持无人值守（预配置）安装 MixSpace 后端

## 无人值守（预配置）

请参考[官方文档](https://mx-space.js.org)以及脚本内的注释，修改本仓库中的 `mxshell.env` 文件，并将其与脚本置于同一目录后运行脚本，脚本会根据配置文件内容自动完成后端部署。

## 待办事项

- [ ] 支持更多部署方式，并可能增加反向代理配置的选项
- [ ] 扩展对更多系统架构的支持

## 注意事项

- 截至 2025 年 3 月 26 日，脚本的使用测试仍较为有限，如遇问题请及时通过 Issue 反馈；若您有解决方案，欢迎直接提交 Pull Request
- 本脚本目前仅支持通过 Docker 部署 MixSpace 后端容器程序，不包含反向代理及高级部署配置

---

此 uwu 标志由 [Arthals](https://github.com/zhuozhiyongde) 设计和版权所有。
