---
layout: home
title: 文档首页
hero:
  name: 通风网络解算系统
  text: VitePress 文档站点
  tagline: 理论 → 算法 → 用法
  image:
    src: /logo.svg
    alt: 通风网络图标
  actions:
    - theme: brand
      text: 开始阅读
      link: /01_简介
features:
  - title: 通用求解器（General Problem Solver）
    details: 支持任意拓扑规模，自动识别基本回路（Hardy Cross）。
  - title: 专用求解器（Solver for fig5.2）
    details: 教材图 5.2 固定拓扑场景，适合教学与参数扫描。
  - title: 可视化与数据 I/O
    details: App Designer UI + CSV 导入/导出 + 拓扑图/柱状图。
---

## 直接看用法

<div style="display:flex; gap:12px; flex-wrap:wrap">
  <a class="VPButton medium brand" href="./05_App使用">App 内使用</a>
  <a class="VPButton medium alt" href="./06_App外用法">App 外使用</a>
</div>

## 本地运行

在仓库根目录执行（或直接进入 `document/` 目录执行）：

```bash
cd document
npm install
npm run docs:dev
```

默认访问：`http://localhost:5173`
