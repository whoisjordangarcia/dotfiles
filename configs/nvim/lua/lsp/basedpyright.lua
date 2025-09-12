return {
  enabled = true,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        autoImportCompletions = true,
        useLibraryCodeForTypes = true,
        typeCheckingMode = "recommended",
        diagnosticMode = "openFilesOnly",
        diagnosticSeverityOverrides = {
          reportDuplicateImport = "warning",
          reportMissingTypeStubs = "warning",
          reportUnusedImport = "warning",
          reportUnusedClass = "warning",
          reportUnusedFunction = "warning",
          reportUnusedVariable = "warning",
        },
      },
    },
  },
}