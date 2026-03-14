---
name: nest-mui
description: Use when working with MUI components, sx prop styling, theme tokens, dialogs, snackbars, loading states, or ag-Grid DataGrid wrapper in the Nest monorepo. Triggers on Material-UI, MUI v7, sx prop, theme customization, AppSnackbar, LoadingBackdrop, useDialog, DataGrid, NestMuiTheme.
---

# MUI v7 Patterns — Nest Monorepo

Material-UI v7 (`@mui/material ^7.3.8`) with Emotion styling. Three theme files exist per app context. Primary styling is `sx` prop inline — no CSS modules, no separate style files.

## MUI v7 Breaking Changes (from v6)

- Deep imports removed — use package exports (`import { Button } from '@mui/material'`)
- `onBackdropClick` removed from Modal — use `onClose` with `reason` check
- Standardized `slots` and `slotProps` pattern on all components
- CSS layers support via `enableCssLayer` config

## Project-Specific Architecture

### Theme Files

| App | Path | Extras |
|-----|------|--------|
| Provider Portal | `apps/frontend/provider-portal/src/components/NestMuiTheme.ts` | `nestBrandColors`, `assistantColors`, custom Chip `tertiary` variant |
| Patient Navigator | `apps/frontend/patient-navigator/src/components/NestMuiTheme.ts` | Account-level custom `primaryColor`, `secondaryColor`, `background` |
| Retool | `apps/retool/components/src/NestMuiTheme.ts` | Shared subset |

All themes export `getTheme(mode, options?)`, `mixins`, and `getPreferredThemeMode()`.

### Shared Theme Defaults

```
fontFamily: Inter, "Helvetica Neue", Arial, sans-serif
shape.borderRadius: 6
Button: disableElevation, borderRadius 8, textTransform 'none'
InputLabel: shrink always true, position relative (labels above fields)
OutlinedInput: notched legend width 0 (no notch gap)
```

### Mixins (sx-compatible reusable styles)

```typescript
import { mixins } from '@nest/provider-portal/components/NestMuiTheme'

<Box sx={mixins.scrollVertical} />   // Hidden scrollbar, vertical overflow
<Box sx={mixins.scrollHorizontal} /> // Hidden scrollbar, horizontal overflow
<Box sx={mixins.bgBlur} />           // Frosted glass backdrop
<Box sx={mixins.textOverflowEllipsis} /> // Truncate with ellipsis
```

### Brand Colors (Provider Portal)

```typescript
import { nestBrandColors } from '@nest/provider-portal/components/NestMuiTheme'

// Each color: base, light20, light40, light60, light80
nestBrandColors.orange.base   // '#e65732' (primary)
nestBrandColors.gold.base     // '#e78d32'
nestBrandColors.pink.base     // '#c45567'
nestBrandColors.darkRed.base  // '#a23c23'
nestBrandColors.purple.base   // '#a367c8'
```

---

## Import Patterns

```typescript
// Named imports from barrel (most common)
import { Box, Button, Typography, Stack } from '@mui/material'

// Icons — always individual deep imports
import SearchIcon from '@mui/icons-material/Search'
import EditRoundedIcon from '@mui/icons-material/EditRounded'

// Date pickers
import { DatePicker } from '@mui/x-date-pickers/DatePicker'
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider'
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns'
```

---

## Styling with sx Prop

### Inline Styles (small components)

```typescript
import type { SxProps, Theme } from '@mui/material'

const styles: Record<string, SxProps<Theme>> = {
  container: {
    p: 2,
    display: 'flex',
    flexDirection: 'column',
    gap: 2,
  },
  header: {
    mb: 3,
    fontSize: '1.5rem',
    fontWeight: 600,
  },
}

function MyComponent() {
  return (
    <Paper sx={styles.container}>
      <Typography sx={styles.header}>Title</Typography>
    </Paper>
  )
}
```

### Separate Styles File (100+ lines)

```typescript
// UserProfile.styles.ts
import type { SxProps, Theme } from '@mui/material'

export const userProfileStyles: Record<string, SxProps<Theme>> = {
  container: { p: 3, maxWidth: 800, mx: 'auto' },
  header: { display: 'flex', justifyContent: 'space-between', mb: 3 },
}

// UserProfile.tsx
import { userProfileStyles as styles } from './UserProfile.styles'
```

### Theme Callback in sx

```typescript
<Box
  sx={(theme) => ({
    color: theme.palette.primary.main,
    bgcolor: alpha(theme.palette.background.default, 0.95),
    '&:hover': { color: theme.palette.primary.dark },
  })}
/>
```

### Responsive Values

```typescript
<Box
  sx={{
    width: { xs: '100%', sm: '80%', md: '60%' },
    display: { xs: 'none', md: 'block' },
    fontSize: { xs: '1rem', md: '1.5rem' },
  }}
/>
```

---

## Project Hooks & Components

### useDialog (shared)

```typescript
import { useDialog } from '@nest/shared/hooks'

function MyComponent() {
  const [dialogProps, { setOpen }] = useDialog()

  return (
    <>
      <Button onClick={() => setOpen(true)}>Open</Button>
      <Dialog {...dialogProps}>
        <DialogTitle>Confirm</DialogTitle>
        <DialogContent>Are you sure?</DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Cancel</Button>
          <Button onClick={handleConfirm} variant="contained">Confirm</Button>
        </DialogActions>
      </Dialog>
    </>
  )
}
```

### AppSnackbar (provider-portal)

```typescript
import { useAppSnackbar } from '@nest/provider-portal/components/AppSnackbar'

function MyComponent() {
  const { show } = useAppSnackbar()

  const handleSave = async () => {
    try {
      await saveData()
      show({ severity: 'success', message: 'Saved successfully' })
    } catch {
      show({
        severity: 'error',
        message: 'Failed to save',
        action: { label: 'Retry', onClick: handleSave },
      })
    }
  }
}
```

Options: `severity` (`'success' | 'error' | 'warning' | 'info'`), `message` (ReactNode), `action` (`{ label, onClick }`), `autoHideDuration` (default 8000ms).

### LoadingBackdrop (provider-portal)

```typescript
import LoadingBackdrop from '@nest/provider-portal/components/LoadingBackdrop'

// Simple loading
<LoadingBackdrop open={isLoading} />

// With upload progress (shows percentage)
<LoadingBackdrop open={isUploading} progress={uploadPercent} />
```

### Shared TextField (libs/shared)

```typescript
import { TextField } from '@nest/shared/components'

// Standard — defaults to size="small", variant="outlined"
<TextField label="Name" value={name} onChange={handleChange} />

// As select with options
<TextField label="Status" options={[
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
]} />

// Read-only display mode
<TextField label="Email" value={email} asDisplay />

// Loading skeleton
<TextField label="Name" loading />
```

### SubmitButton (provider-portal)

```typescript
import SubmitButton from '@nest/provider-portal/components/SubmitButton'

<SubmitButton loading={isSaving}>Save Changes</SubmitButton>
// Shows CircularProgress overlay when loading, disables button
```

---

## DataGrid (ag-Grid Wrapper, Provider Portal)

The provider portal uses **ag-Grid**, NOT `@mui/x-data-grid`. The custom wrapper applies MUI theme tokens.

```typescript
import { DataGrid, DataGridContainer } from '@nest/provider-portal/components/DataGrid'

<DataGridContainer>
  <DataGrid
    gridId="patients-grid"
    storePreferences          // Persists column widths/order to localStorage
    columnDefs={columnDefs}
    rowData={patients}
    totalRowCount={patients.length}
    noRowsOverlayComponentParams={{
      title: 'No patients found',
      body: 'Try adjusting your filters',
    }}
  />
</DataGridContainer>
```

Key props: `gridId` + `storePreferences` for localStorage persistence, `totalRowCount` drives empty state, `footerContent` for custom footer.

---

## Common Patterns

### Card

```typescript
<Card>
  <CardContent>
    <Typography variant="h5" component="div">Title</Typography>
    <Typography variant="body2" color="text.secondary">Description</Typography>
  </CardContent>
  <CardActions>
    <Button size="small">Learn More</Button>
  </CardActions>
</Card>
```

### Loading States

```typescript
// Full-page backdrop
<LoadingBackdrop open={loading} />

// Inline spinner
<Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
  <CircularProgress />
</Box>

// Content skeletons
<Stack spacing={1}>
  <Skeleton variant="text" width="60%" />
  <Skeleton variant="rectangular" height={200} />
</Stack>

// Button with loading
<SubmitButton loading={saving}>Save</SubmitButton>
```

### Form Layout

```typescript
<Box component="form" onSubmit={handleSubmit}>
  <Stack spacing={2}>
    <TextField
      label="Email"
      type="email"
      value={email}
      onChange={(e) => setEmail(e.target.value)}
      fullWidth
      required
      error={!!errors.email}
      helperText={errors.email}
    />
    <SubmitButton loading={submitting}>Submit</SubmitButton>
  </Stack>
</Box>
```

---

## Best Practices

### Always type sx props
```typescript
// Good
const styles: Record<string, SxProps<Theme>> = { container: { p: 2 } }

// Bad — no type safety
const styles = { container: { p: 2 } }
```

### Use theme tokens, not hardcoded values
```typescript
// Good
<Box sx={{ color: 'primary.main', p: 2 }} />

// Bad
<Box sx={{ color: '#E75732', padding: '16px' }} />
```

### Use spacing scale consistently
```typescript
// Good — spacing units (1 = 8px)
<Box sx={{ p: 2, mb: 3, gap: 1.5 }} />

// Bad — arbitrary pixels
<Box sx={{ padding: '17px', marginBottom: '25px' }} />
```

### Use project wrappers over raw MUI
- `useDialog` over manual open/close state
- `useAppSnackbar` over custom Snackbar setup
- Shared `TextField` over raw MUI `TextField`
- `SubmitButton` over Button + CircularProgress
- `LoadingBackdrop` over Backdrop + CircularProgress

### Use data-testid for test selectors
```typescript
<Button data-testid="submit-btn" variant="contained">Submit</Button>
```

### styled() is rare — only for non-MUI elements needing theme access
```typescript
// Only when wrapping third-party components that can't use sx
import { styled } from '@mui/material'
const StyledCalendar = styled(Calendar)(({ theme }) => ({
  color: theme.palette.text.primary,
}))
```
