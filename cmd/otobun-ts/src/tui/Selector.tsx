import React, {useState} from 'react';
import {Box, Text, useInput} from 'ink';
import type {Component} from '../installer.js';
import {LOGO} from './theme.js';

interface SelectorProps {
  system: string;
  components: Component[];
  onComplete: (selected: Component[]) => void;
  onCancel: () => void;
}

export function Selector({system, components, onComplete, onCancel}: SelectorProps) {
  const [cursor, setCursor] = useState(0);
  const [selected, setSelected] = useState<boolean[]>(components.map(() => true));

  useInput((input, key) => {
    if (key.upArrow || input === 'k') {
      setCursor(prev => Math.max(0, prev - 1));
    } else if (key.downArrow || input === 'j') {
      setCursor(prev => Math.min(components.length - 1, prev + 1));
    } else if (input === ' ' || input === 'x') {
      setSelected(prev => {
        const next = [...prev];
        next[cursor] = !next[cursor];
        return next;
      });
    } else if (input === 'a') {
      setSelected(components.map(() => true));
    } else if (input === 'n') {
      setSelected(components.map(() => false));
    } else if (key.return) {
      const selectedComponents = components.filter((_, i) => selected[i]);
      onComplete(selectedComponents);
    } else if (input === 'q' || key.escape) {
      onCancel();
    }
  });

  const selectedCount = selected.filter(Boolean).length;

  if (components.length === 0) {
    return (
      <Box padding={1} flexDirection="column" gap={1}>
        <Text color="yellow">No components found for system: <Text color="magenta">{system}</Text></Text>
        <Text color="gray">Check that <Text color="white">script/{system}_installation.sh</Text> exists.</Text>
        <Text color="gray">Press <Text color="magenta" bold>q</Text> to quit.</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column" padding={1} gap={1}>
      {/* Logo */}
      <Box flexDirection="column">
        {LOGO.split('\n').map((line, i) => (
          <Text key={i} color="magenta" bold>{line}</Text>
        ))}
      </Box>

      {/* Header */}
      <Box gap={1}>
        <Text color="cyan" bold>Module Selection</Text>
        <Text color="gray">[{selectedCount}/{components.length}]</Text>
        <Text color="magenta">{system}</Text>
      </Box>

      <Box>
        <Text color="gray">{'─'.repeat(50)}</Text>
      </Box>

      {/* Component list */}
      <Box flexDirection="column">
        {components.map((comp, i) => {
          const isSelected = selected[i];
          const isCursor = i === cursor;

          return (
            <Box key={comp.name}>
              {isCursor
                ? <Text color="cyan" bold>❯ </Text>
                : <Text>  </Text>
              }
              {isSelected
                ? <Text color="green" bold>● </Text>
                : <Text color="gray">○ </Text>
              }
              <Text bold={isCursor} color={isCursor ? 'white' : 'gray'}>
                {comp.name}
              </Text>
            </Box>
          );
        })}
      </Box>

      <Box>
        <Text color="gray">{'─'.repeat(50)}</Text>
      </Box>

      {/* Help bar */}
      <Box gap={1}>
        <Text color="magenta" bold>space</Text><Text color="gray">toggle</Text>
        <Text color="gray">·</Text>
        <Text color="magenta" bold>a</Text><Text color="gray">all</Text>
        <Text color="gray">·</Text>
        <Text color="magenta" bold>n</Text><Text color="gray">none</Text>
        <Text color="gray">·</Text>
        <Text color="magenta" bold>j/k</Text><Text color="gray">move</Text>
        <Text color="gray">·</Text>
        <Text color="magenta" bold>↵</Text><Text color="gray">install</Text>
        <Text color="gray">·</Text>
        <Text color="magenta" bold>q</Text><Text color="gray">quit</Text>
      </Box>
    </Box>
  );
}
