return {
  {
    "folke/snacks.nvim",
    opts = {
      explorer = {},
      picker = {
        sources = {
          files = {
            hidden = true,
            ignored = true,
            exclude = {
              -- Dependencies & Build artifacts
              "node_modules",
              ".next",
              "dist",
              "build",
              ".nuxt",
              ".output",
              -- Python
              "__pycache__",
              "*.pyc",
              "*.pyo",
              "*.pyd",
              ".pytest_cache",
              ".coverage",
              "htmlcov",
              ".tox",
              -- Django specific
              "staticfiles",
              "media",
              "*.sqlite3",
              "db.sqlite3",
              -- TypeScript/JavaScript
              ".turbo",
              ".swc",
              ".cache",
              "coverage",
              ".nyc_output",
              -- OS & misc
              ".DS_Store",
              "*.log",
              "*.tmp",
              "Thumbs.db",
            },
          },
          grep = {
            hidden = true,
            ignored = true,
            exclude = {
              -- Dependencies & Build artifacts
              "node_modules",
              ".next",
              "dist",
              "build",
              ".nuxt",
              ".output",
              -- Python
              "__pycache__",
              "*.pyc",
              "*.pyo",
              "*.pyd",
              ".pytest_cache",
              ".coverage",
              "htmlcov",
              ".tox",
              -- Django specific
              "staticfiles",
              "media",
              "*.sqlite3",
              "db.sqlite3",
              -- TypeScript/JavaScript
              ".turbo",
              ".swc",
              ".cache",
              "coverage",
              ".nyc_output",
              -- OS & misc
              ".DS_Store",
              "*.log",
              "*.tmp",
              "Thumbs.db",
            },
          },
          explorer = {
            hidden = true,
            ignored = true,
            exclude = {
              -- Dependencies & Build artifacts
              ".nuxt",
              ".output",
              -- Python
              "__pycache__",
              "*.pyc",
              "*.pyo",
              "*.pyd",
              ".pytest_cache",
              ".coverage",
              "htmlcov",
              ".tox",
              -- Django specific
              "staticfiles",
              "media",
              "*.sqlite3",
              "db.sqlite3",
              -- TypeScript/JavaScript
              ".turbo",
              ".swc",
              ".cache",
              "coverage",
              ".nyc_output",
              -- OS & misc
              ".DS_Store",
              "*.log",
              "*.tmp",
              "Thumbs.db",
            },
          },
        },
      },
    },
  },
}
