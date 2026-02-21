import React, {useState, useEffect, useRef, useCallback} from 'react';
import {Box, Text, useInput, useApp, useStdout} from 'ink';
import Spinner from 'ink-spinner';
import type {Component} from '../installer.js';
import type {DotConfig} from '../config.js';
import {runComponent} from '../installer.js';
import {progressBar} from './theme.js';

interface ComponentResult {
  done: boolean;
  success: boolean;
  error?: string;
}

interface RunnerProps {
  components: Component[];
  dotfilesDir: string;
  config: DotConfig;
}

const MAX_OUTPUT_LINES = 200;

export function Runner({components, dotfilesDir, config}: RunnerProps) {
  const {exit} = useApp();
  const {stdout} = useStdout();
  const [currentIndex, setCurrentIndex] = useState(0);
  const [results, setResults] = useState<ComponentResult[]>(
    components.map(() => ({done: false, success: false})),
  );
  const [outputLines, setOutputLines] = useState<string[]>([]);
  const [done, setDone] = useState(false);
  const installingRef = useRef(false);
  const outputRef = useRef('');

  const addOutput = useCallback((text: string) => {
    outputRef.current += text;
    const allLines = outputRef.current.split('\n');
    setOutputLines(allLines.slice(-MAX_OUTPUT_LINES));
  }, []);

  useEffect(() => {
    if (installingRef.current) return;

    if (components.length === 0) {
      setDone(true);
      return;
    }

    installingRef.current = true;

    (async () => {
      for (let i = 0; i < components.length; i++) {
        setCurrentIndex(i);
        addOutput(`\n─── ${components[i].name} ───\n`);

        const result = await runComponent(dotfilesDir, components[i], config, addOutput);

        setResults(prev => {
          const next = [...prev];
          next[i] = {done: true, success: result.success, error: result.error};
          return next;
        });
      }

      setCurrentIndex(components.length);
      setDone(true);
    })();
  }, []);

  useInput((input, key) => {
    if (input === 'q' || (key.ctrl && input === 'c')) {
      exit();
    }
  });

  const termWidth  = stdout?.columns ?? 80;
  const termHeight = stdout?.rows    ?? 24;
  const leftWidth  = 26;
  const rightWidth = Math.max(20, termWidth - leftWidth - 5);
  const outputHeight = Math.max(5, termHeight - 8);

  const completedCount = results.filter(r => r.done).length;
  const successCount   = results.filter(r => r.done && r.success).length;
  const failCount      = results.filter(r => r.done && !r.success).length;
  const visibleLines   = outputLines.slice(-outputHeight);

  return (
    <Box flexDirection="column" padding={1} gap={1}>
      {/* Header */}
      <Box>
        <Text color="yellow" bold>⚡ Installing dotfiles</Text>
      </Box>

      {/* Two-panel layout */}
      <Box flexDirection="row" gap={1}>
        {/* Left panel: module list */}
        <Box
          flexDirection="column"
          width={leftWidth}
          borderStyle="round"
          borderColor="gray"
          paddingX={1}
        >
          <Text color="gray" dimColor italic> modules </Text>
          {components.map((comp, i) => {
            const result = results[i];
            const isCurrent = i === currentIndex && !done;
            const shortName = comp.name.split('/')[0];

            return (
              <Box key={comp.name}>
                {result?.done ? (
                  result.success
                    ? <Text color="green">✓ </Text>
                    : <Text color="red">✗ </Text>
                ) : isCurrent ? (
                  <Text color="magenta"><Spinner type="dots" />  </Text>
                ) : (
                  <Text color="gray" dimColor>· </Text>
                )}
                <Text
                  color={
                    result?.done
                      ? result.success ? 'green' : 'red'
                      : isCurrent ? 'white' : 'gray'
                  }
                  bold={isCurrent}
                  dimColor={!result?.done && !isCurrent}
                  wrap="truncate"
                >
                  {shortName}
                </Text>
              </Box>
            );
          })}
        </Box>

        {/* Right panel: script output */}
        <Box
          flexDirection="column"
          width={rightWidth}
          borderStyle="round"
          borderColor="gray"
          paddingX={1}
        >
          <Text color="gray" dimColor italic> output </Text>
          <Box flexDirection="column">
            {visibleLines.map((line, i) => (
              <Text key={i} wrap="truncate" dimColor>
                {line}
              </Text>
            ))}
          </Box>
        </Box>
      </Box>

      {/* Footer */}
      {done ? (
        <Box gap={2}>
          <Text color="yellow" bold>⚡ Done!</Text>
          <Text color="green" bold>✓ {successCount} succeeded</Text>
          {failCount > 0 && <Text color="red" bold>✗ {failCount} failed</Text>}
          <Text color="gray" dimColor>  q quit</Text>
        </Box>
      ) : (
        <Box gap={2}>
          <Text>{progressBar(completedCount, components.length, 20)}</Text>
          <Text color="gray">{completedCount}/{components.length}</Text>
          <Text color="gray" dimColor>  q quit</Text>
        </Box>
      )}
    </Box>
  );
}
