import { defineConfig } from 'vitepress'


export default defineConfig({
  title: "Jolt",
  description: "Lightweight reactive state management library for Dart and Flutter",

  head: [
    ['meta', { name: 'keywords', content: 'jolt, reactive, state management, dart, flutter, signals' }],
    ['meta', { name: 'author', content: 'vowdemon' }],
  ],

  markdown: {
    lineNumbers: false,
  },

  base: '/',
  lang: 'en-US',

  locales: {
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      link: '/zh/',
      description: '轻量级响应式状态管理库',
      themeConfig: {
        siteTitle: 'Jolt',

        nav: [
          { text: '首页', link: '/zh/' },
          { text: '指南', link: '/zh/jolt/what-is-jolt', activeMatch: '/zh/jolt/' },
        ],


        lastUpdated: {
          text: '最后更新',
          formatOptions: {
            dateStyle: 'short',
            timeStyle: 'medium'
          }
        },


        footer: {
          message: '基于 MIT 许可证发布',
          copyright: 'Copyright © 2025-present vowdemon'
        },


        search: {
          provider: 'local',
          options: {
            locales: {
              zh: {
                translations: {
                  button: {
                    buttonText: '搜索文档',
                    buttonAriaLabel: '搜索文档'
                  },
                  modal: {
                    noResultsText: '无法找到相关结果',
                    resetButtonTitle: '清除查询条件',
                    footer: {
                      selectText: '选择',
                      navigateText: '切换',
                      closeText: '关闭'
                    }
                  }
                }
              }
            }
          }
        },

        socialLinks: [
          { icon: 'github', link: 'https://github.com/vowdemon/jolt' }
        ],

        returnToTopLabel: '返回顶部',

        docFooter: {
          prev: '上一页',
          next: '下一页'
        },

        sidebarMenuLabel: '菜单',
        darkModeSwitchLabel: '主题',
        langMenuLabel: '切换语言',

        sidebar: [
          {
            text: 'Jolt 文档',
            items: [
              {
                text: '介绍',
                items: [
                  { text: '什么是Jolt', link: '/zh/jolt/what-is-jolt' },
                  { text: '快速开始', link: '/zh/jolt/getting-started' },
                ]
              },
              {
                text: '核心概念',
                items: [
                  { text: 'Signal', link: '/zh/jolt/core/signal' },
                  { text: 'Computed', link: '/zh/jolt/core/computed' },
                  { text: 'Effect', link: '/zh/jolt/core/effect' },
                  { text: 'Watcher', link: '/zh/jolt/core/watcher' },
                  { text: 'EffectScope', link: '/zh/jolt/core/effect-scope' },
                  { text: 'Batch', link: '/zh/jolt/core/batch' },
                  { text: 'Untracked', link: '/zh/jolt/core/untracked' }
                ]
              },
              {
                text: '高级',
                items: [
                  { text: '异步信号', link: '/zh/jolt/advanced/async-signal' },
                  { text: '合集信号', link: '/zh/jolt/advanced/collection-signal' },
                  { text: '转换信号', link: '/zh/jolt/advanced/convert-computed' },
                  { text: '持久信号', link: '/zh/jolt/advanced/persist-signal' },
                  { text: '信号转流', link: '/zh/jolt/advanced/stream' },
                  { text: '自定义系统', link: '/zh/jolt/advanced/custom-system' }
                ]
              },
              {
                text: 'Flutter',
                items: [
                  { text: 'Widgets', link: '/zh/jolt/flutter/widgets' },
                  { text: 'Hooks', link: '/zh/jolt/flutter/hooks' },
                  { text: 'Surge', link: '/zh/jolt/flutter/surge' }
                ]
              }
            ]
          }
        ],
      }
    },
    root: {
      label: 'English',
      lang: 'en-US',
      link: '/',
      description: 'Lightweight reactive state management library',
      themeConfig: {

        siteTitle: 'Jolt',

        nav: [
          { text: 'Home', link: '/' },
          { text: 'Guide', link: '/jolt/what-is-jolt', activeMatch: '/jolt/' },
        ],

        lastUpdated: {
          text: 'Last updated',
          formatOptions: {
            dateStyle: 'short',
            timeStyle: 'medium'
          }
        },

        footer: {
          message: 'Released under the MIT License',
          copyright: 'Copyright © 2025-present vowdemon'
        },

        search: {
          provider: 'local',
          options: {
            translations: {
              button: {
                buttonText: 'Search docs',
                buttonAriaLabel: 'Search documentation'
              },
              modal: {
                noResultsText: 'No results found',
                resetButtonTitle: 'Reset search',
                footer: {
                  selectText: 'to select',
                  navigateText: 'to navigate',
                  closeText: 'to close'
                }
              }
            }
          }
        },

        returnToTopLabel: 'Back to top',

        docFooter: {
          prev: 'Previous page',
          next: 'Next page'
        },

        sidebarMenuLabel: 'Menu',
        darkModeSwitchLabel: 'Theme',
        langMenuLabel: 'Change language',

        sidebar: [
          {
            text: 'Jolt Documentation',
            items: [
              {
                text: 'Introduction',
                items: [
                  { text: 'What is Jolt', link: '/jolt/what-is-jolt' },
                  { text: 'Getting Started', link: '/jolt/getting-started' },
                ]
              },
              {
                text: 'Core Concepts',
                items: [
                  { text: 'Signal', link: '/jolt/core/signal' },
                  { text: 'Computed', link: '/jolt/core/computed' },
                  { text: 'Effect', link: '/jolt/core/effect' },
                  { text: 'Watcher', link: '/jolt/core/watcher' },
                  { text: 'EffectScope', link: '/jolt/core/effect-scope' },
                  { text: 'Batch', link: '/jolt/core/batch' },
                  { text: 'Untracked', link: '/jolt/core/untracked' }
                ]
              },
              {
                text: 'Advanced',
                items: [
                  { text: 'Async Signal', link: '/jolt/advanced/async-signal' },
                  { text: 'Collection Signal', link: '/jolt/advanced/collection-signal' },
                  { text: 'Convert Signal', link: '/jolt/advanced/convert-computed' },
                  { text: 'Persist Signal', link: '/jolt/advanced/persist-signal' },
                  { text: 'Signal to Stream', link: '/jolt/advanced/stream' },
                  { text: 'Custom System', link: '/jolt/advanced/custom-system' }
                ]
              },
              {
                text: 'Flutter',
                items: [
                  { text: 'Widgets', link: '/jolt/flutter/widgets' },
                  { text: 'Hooks', link: '/jolt/flutter/hooks' },
                  { text: 'Surge', link: '/jolt/flutter/surge' }
                ]
              }
            ]
          }
        ],
      }
    }
  },
  themeConfig: {
    socialLinks: [
      { icon: 'github', link: 'https://github.com/vowdemon/jolt' }
    ],
    outline: {
      level: [2, 3],
    },
  },

})
