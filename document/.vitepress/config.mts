import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: '通风网络解算系统',
  description: 'wangluojiesuan 项目文档（理论 → 算法 → 用法）',
  // 部署到子路径（GitHub Pages / GitLab Pages）时需要设置 base，例如：
  // - GitHub Pages: /<repo>/
  // - GitLab Pages: /<project>/
  base: process.env.VITEPRESS_BASE ?? '/',
  cleanUrls: true,
  lastUpdated: true,
  markdown: {
    math: true
  },
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: '文档', link: '/' },
      { text: '通用求解器', link: '/gps/README' },
      { text: '图5.2专用求解器', link: '/fig5.2/README' }
    ],
    sidebar: [
      {
        text: '总览',
        items: [
          { text: '文档首页', link: '/' },
          { text: '简介', link: '/01_简介' },
          { text: '项目目录', link: '/02_项目目录' }
        ]
      },
      {
        text: '理论与算法',
        items: [
          { text: '数学物理', link: '/03_数学物理' },
          { text: '算法实现', link: '/04_算法实现' }
        ]
      },
      {
        text: '使用',
        items: [
          { text: 'App 使用', link: '/05_App使用' },
          { text: 'App 外用法', link: '/06_App外用法' }
        ]
      },
      {
        text: '附录',
        items: [
          { text: '其他', link: '/07_其他' },
          { text: '许可证（GPL-3.0）', link: '/许可证' }
        ]
      },
      {
        text: '通用求解器（镜像）',
        items: [
          { text: 'README', link: '/gps/README' },
          { text: 'Functions', link: '/gps/Functions' },
          { text: 'OutAppUse', link: '/gps/OutAppUse' }
        ]
      },
      {
        text: '图5.2专用求解器（镜像）',
        items: [{ text: 'README', link: '/fig5.2/README' }]
      },
      {
        text: '仓库（镜像）',
        items: [{ text: '根目录 README', link: '/repo/README' }]
      }
    ],
    search: { provider: 'local' },
    outline: { level: [2, 3] },
    footer: {
      message: '本文档站点用于阅读与二次开发参考',
      copyright: 'GPL-3.0'
    }
  }
})
