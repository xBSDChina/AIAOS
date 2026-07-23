# AIAOS Enterprise Framework

[English](#aiaos-enterprise-framework) | [中文](#aiaos-企业级框架)

---

## English

**AIAOS** (Autonomous Intelligent Agent Operating System) is an enterprise-grade framework built with Chicken Scheme, designed for autonomous task execution, multi-level orchestration, and real-time monitoring.

### Features

- **Multi-level Task System** (L1-L5) with omniScore priority and autonomous execution
- **G-HICS-AM Compliance** - Enterprise-grade quality gates and audit checkpoints
- **LLM Integration** - Support for OpenRouter, Moonshot, NVIDIA, and local Ollama
- **Real-time Dashboards** - System health, task hierarchy, monitoring on ports 8082, 6666, 8888
- **Chicken Scheme Native** - Compiled to native binaries for maximum performance and reliability
- **FreeBSD Optimized** - Native deployment on FreeBSD with doas privilege management

### Quick Start

```bash
# Clone and setup
git clone https://github.com/xBSDChina/AIAOS.git
cd aiaos

# Install Chicken Scheme 5.4.0+ dependencies
chicken-install srfi-1 srfi-13 srfi-14 srfi-18 srfi-34 srfi-35 srfi-69 json matchable packrat

# Build core components
cd src/core
chicken-csc -o aiaos-core aiaos-core.scm layer0.scm layer1.scm layer2.scm layer3.scm layer4.scm layer5.scm layer6.scm layer7.scm layer8.scm layer9.scm

# Configure LLM provider (edit src/config/aiaos-config.json)
# Then test LLM integration:
./src/llm/aiaos-llm-chicken

# Start dashboard (requires doas on port 80/8888)
doas -n -u freebsd15 ./examples/start-aiaos-dashboard.sh
```

### Project Structure

```
aiaos/
├── src/
│   ├── core/           # Core framework (layers 0-9, objective engine)
│   ├── llm/            # LLM integration and provider abstraction
│   ├── dashboard/      # Web dashboards (8888, 6666)
│   ├── web/            # HTTP handlers and API endpoints
│   ├── tasks/          # Task definitions and hierarchies
│   ├── services/       # Service management and PID files (runtime)
│   └── config/         # Configuration templates
├── examples/           # Bootstrap and startup scripts
├── docs/               # Documentation (to be generated)
├── tests/              # Unit and integration tests
└── LICENSE             # MIT License
```

### Architecture Overview

AIAOS implements a **five-level task hierarchy**:

- **L1 - Iteration**: M2 Milestone, FreeBSD kernel iterations, MCP protocol extensions
- **L2 - Gateway**: Platform entry, module entry, dashboard systems
- **L3 - Adapter/Engine**: FreeBSD adapter, MCP protocol, monitor engine, UTE task engine
- **L4 - Modules**: Pool, auto-enhancement, iterative generation, linkage core
- **L5 - Strategy**: Brains Model

Each task undergoes **four audit checkpoints**: PRE_EXEC, POST_EXEC, AUDIT, FINAL, ensuring G-HICS-AM L5 compliance.

### Configuration

Copy `src/config/aiaos-config.json.example` to `src/config/aiaos-config.json` and set your API keys:

```json
{
  "llm": {
    "default": "nvidia",
    "providers": {
      "nvidia": {
        "api_key": "YOUR_NVIDIA_API_KEY",
        "base_url": "https://integrate.api.nvidia.com/v1"
      },
      "openrouter": {
        "api_key": "YOUR_OPENROUTER_KEY"
      }
    }
  }
}
```

### Dashboard Access

- **Claw2EE API**: http://localhost:8082 (health, task hierarchy)
- **Enterprise Dashboard**: http://localhost:6666
- **System Monitor**: http://localhost:8888
- **Port 80** (requires doas): Enterprise status dashboard

### Development

- **Language**: Chicken Scheme 5.4.0
- **Required eggs**: srfi-1, srfi-13, srfi-14, srfi-18, srfi-34, srfi-35, srfi-69, json, matchable, packrat
- **Target OS**: FreeBSD 15.0 (works on Linux with minor adjustments)

### Testing

```bash
cd tests
chicken-csi -s integration-test.scm
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/foo`)
3. Commit your changes (`git commit -am 'Add foo'`)
4. Push to the branch (`git push origin feature/foo`)
5. Open a Pull Request

All contributions must pass the G-HICS-AM quality gates and maintain backward compatibility with the layer 0-9 contract.

### License

MIT License - see [LICENSE](LICENSE) file.

---

## 中文 / 繁體中文

<a name="aiaos-企业级框架"></a>

## AIAOS 企业级框架

**AIAOS** (Autonomous Intelligent Agent Operating System) 是基于 Chicken Scheme 构建的企业级自主任务执行框架，支持多级编排、实时监控和 G-HICS-AM L5 审计合规。

### 核心特性

- **多级任务系统** (L1-L5) 配 omniScore 优先级和自主执行
- **G-HICS-AM 合规** - 企业级质量门禁与审计检查点
- **LLM 集成** - 支持 OpenRouter、Moonshot、NVIDIA、本地 Ollama
- **实时大屏** - 系统健康、任务层级、监控 (端口 8082, 6666, 8888)
- **Chicken Scheme 原生** - 编译为原生二进制，高性能高可靠
- **FreeBSD 优化** - 原生 doas 权限管理，生产环境 64 天无中断

### 快速开始

```bash
# 克隆并配置
git clone https://github.com/xBSDChina/AIAOS.git
cd aiaos

# 安装 Chicken Scheme 依赖 (5.4.0+)
chicken-install srfi-1 srfi-13 srfi-14 srfi-18 srfi-34 srfi-35 srfi-69 json matchable packrat

# 编译核心组件
cd src/core
chicken-csc -o aiaos-core aiaos-core.scm layer0.scm layer1.scm layer2.scm layer3.scm layer4.scm layer5.scm layer6.scm layer7.scm layer8.scm layer9.scm

# 配置 LLM 提供商 (编辑 src/config/aiaos-config.json)
# 测试 LLM 集成:
./src/llm/aiaos-llm-chicken

# 启动大屏 (需要 doas 权限绑定 80/8888 端口)
doas -n -u freebsd15 ./examples/start-aiaos-dashboard.sh
```

### 项目结构

```
aiaos/
├── src/
│   ├── core/           # 核心框架 (0-9 层, 目标引擎)
│   ├── llm/            # LLM 集成与提供商抽象
│   ├── dashboard/      # Web 大屏 (8888, 6666)
│   ├── web/            # HTTP 处理器与 API 端点
│   ├── tasks/          # 任务定义与层级
│   ├── services/       # 服务管理与 PID 文件 (运行时)
│   └── config/         # 配置模板
├── examples/           # 启动脚本与引导程序
├── docs/               # 文档 (待生成)
├── tests/              # 单元与集成测试
└── LICENSE             # MIT 许可证
```

### 架构总览

AIAOS 采用 **五级任务层级**：

- **L1 - 迭代层**: M2 里程碑、FreeBSD 内核迭代、MCP 协议扩展
- **L2 - 网关层**: 平台入口、模块入口、大屏系统
- **L3 - 适配/引擎层**: FreeBSD 适配器、MCP 协议、监控引擎、UTE 任务引擎
- **L4 - 模块层**: 任务池、自增强、迭代生成、联动核心
- **L5 - 战略层**: 智库模块

每个任务执行 **四个审计检查点**: PRE_EXEC、POST_EXEC、AUDIT、FINAL，确保 G-HICS-AM L5 合规。

### 配置说明

复制 `src/config/aiaos-config.json.example` 为 `src/config/aiaos-config.json` 并设置 API 密钥：

```json
{
  "llm": {
    "default": "nvidia",
    "providers": {
      "nvidia": {
        "api_key": "YOUR_NVIDIA_API_KEY",
        "base_url": "https://integrate.api.nvidia.com/v1"
      },
      "openrouter": {
        "api_key": "YOUR_OPENROUTER_KEY"
      }
    }
  }
}
```

### 大屏访问

- **Claw2EE API**: http://localhost:8082 (健康检查、任务层级)
- **企业级大屏**: http://localhost:6666
- **系统监控**: http://localhost:8888
- **80 端口** (需 doas): 企业状态总览大屏

### 开发指南

- **语言**: Chicken Scheme 5.4.0
- **依赖 eggs**: srfi-1, srfi-13, srfi-14, srfi-18, srfi-34, srfi-35, srfi-69, json, matchable, packrat
- **目标平台**: FreeBSD 15.0 (Linux 可轻微调整)

### 测试

```bash
cd tests
chicken-csi -s integration-test.scm
```

### 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/foo`)
3. 提交更改 (`git commit -am 'Add foo'`)
4. 推送到分支 (`git push origin feature/foo`)
5. 开启 Pull Request

所有贡献必须通过 G-HICS-AM 质量门禁，并保持与 layer 0-9 契约的向后兼容性。

### 许可证

MIT License - 见 [LICENSE](LICENSE) 文件。

---

*Last updated: 2025-07-21 by Dieken (AIAOS Framework Maintainer)*
