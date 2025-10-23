# Custom Man Pages for Dotfiles

This directory contains custom man pages that document all aliases and functions defined in your zsh configuration.

## Usage

After sourcing your `.zshrc`, you can access the documentation in several ways:

### Full Man Page
```bash
dotman      # Opens the full man page
dothelp     # Alias for dotman
man dotfiles # Also works after setting MANPATH
```

The full man page provides detailed documentation including:
- Command descriptions
- Usage examples
- Syntax and parameters
- Related commands

### Quick Reference
```bash
dotref      # Shows a colorful quick reference guide
```

The quick reference provides a compact, categorized overview perfect for quick lookups.

## Structure

```
configs/man/
├── README.md           # This file
└── man1/
    └── dotfiles.1      # Man page in groff format
```

## Man Page Format

The man page is written in groff format, the standard format for Unix man pages. This ensures:
- Proper rendering with the `man` command
- Standard formatting and navigation
- Searchable with `/` in the man viewer
- Professional appearance

## Maintenance

### Adding New Commands

When you add new aliases or functions to your zsh configuration:

1. **Edit the man page**: Update `configs/man/man1/dotfiles.1`
   - Add entries in the appropriate section
   - Follow the existing groff formatting
   - Include usage examples

2. **Update quick reference**: Edit `configs/zshrc/.zshrc-modules/scripts/dotfiles-quick-ref`
   - Add the command to the relevant category
   - Keep descriptions concise (one line)

### Man Page Sections

The man page is organized into these sections:
- **NAME**: Brief description
- **SYNOPSIS**: Overview
- **DESCRIPTION**: Detailed information
- **[Category]**: Grouped commands (Shell Management, Git, etc.)
- **FILES**: Related configuration files
- **EXAMPLES**: Usage examples
- **AUTHOR**: Your information
- **SEE ALSO**: Related commands

### Groff Formatting Quick Reference

Common formatting commands used in the man page:

```groff
.TH TITLE SECTION DATE VERSION DESCRIPTION    # Title header
.SH SECTION_NAME                               # Section header
.TP                                            # Tagged paragraph
.B text                                        # Bold text
.I text                                        # Italic text
.br                                            # Line break
.RS                                            # Begin indented block
.RE                                            # End indented block
.nf                                            # No fill (preserve formatting)
.fi                                            # Fill (normal formatting)
```

## Integration

The man page system is integrated into your zsh configuration automatically:

1. **MANPATH setup** in `.zshrc`:
   ```bash
   export MANPATH="$HOME/dev/dotfiles/configs/man:$MANPATH"
   ```

2. **Helper functions** in `.zshrc.functions`:
   - `dotman()`: Opens the man page
   - `dotref()`: Shows quick reference

3. **Aliases**:
   - `dothelp`: Alias for `dotman`

## Benefits

✅ **Searchable Documentation**: Use `/` to search within the man page
✅ **Professional Format**: Standard Unix man page appearance
✅ **Always Available**: Accessible from anywhere in the terminal
✅ **Version Controlled**: Documentation lives with your dotfiles
✅ **Quick Reference**: Fast lookup without full man page navigation
✅ **Consistent**: Follows Unix documentation conventions
✅ **Syntax Highlighted**: Beautiful colored output using bat

## Colored Output

Man pages are automatically displayed with syntax highlighting using `bat`. This is configured in `.zshrc.envvars`:

```bash
export MANPAGER="sh -c 'col -bx | bat -l man --paging=always'"
export MANROFFOPT="-c"
```

**Note**: The `--paging=always` flag is required to override the `--paging=never` setting in your bat config file, ensuring you can scroll through man pages.

This provides:
- **Syntax highlighting** for man page sections
- **Line numbers** and git integration (bat features)
- **Smooth scrolling** with keyboard navigation
- **Search highlighting** when using `/` to search

### Navigation in bat-powered man pages:
- `↑/↓` or `j/k` - Scroll up/down
- `Space` - Page down
- `b` - Page up
- `/pattern` - Search forward
- `?pattern` - Search backward
- `n/N` - Next/previous search result
- `q` - Quit

## Examples

```bash
# View full documentation
dotman

# Quick lookup
dotref

# Search for specific command in man page
dotman
# Then press '/' and type search term

# View specific section
man dotfiles | grep -A 5 "GIT WORKTREE"
```

## See Also

- [groff man page format guide](https://man7.org/linux/man-pages/man7/groff_man.7.html)
- [Writing man pages tutorial](https://liw.fi/manpages/)
