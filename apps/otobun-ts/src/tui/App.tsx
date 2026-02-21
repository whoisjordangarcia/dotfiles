import React, {useState, useEffect} from 'react';
import {Box, Text, useApp} from 'ink';
import {configExists, loadConfig, saveConfig} from '../config.js';
import {detectSystem} from '../detector.js';
import {parseComponents} from '../installer.js';
import type {DotConfig} from '../config.js';
import type {Component} from '../installer.js';
import {Wizard} from './Wizard.js';
import {Selector} from './Selector.js';
import {Runner} from './Runner.js';

type Phase = 'checking' | 'wizard' | 'selector' | 'runner';

interface AppProps {
  dotfilesDir: string;
  forceSetup: boolean;
}

export function App({dotfilesDir, forceSetup}: AppProps) {
  const {exit} = useApp();
  const [phase, setPhase] = useState<Phase>('checking');
  const [config, setConfig] = useState<DotConfig | null>(null);
  const [components, setComponents] = useState<Component[]>([]);
  const [selectedComponents, setSelectedComponents] = useState<Component[]>([]);
  const [error, setError] = useState<string | null>(null);

  const detected = detectSystem();

  useEffect(() => {
    try {
      if (!configExists(dotfilesDir) || forceSetup) {
        setPhase('wizard');
        return;
      }

      const cfg = loadConfig(dotfilesDir);
      setConfig(cfg);
      const comps = parseComponents(dotfilesDir, cfg.system);
      setComponents(comps);
      setPhase('selector');
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }, []);

  if (error) {
    return (
      <Box padding={1}>
        <Text color="red" bold>Error: {error}</Text>
      </Box>
    );
  }

  if (phase === 'checking') {
    return (
      <Box padding={1}>
        <Text color="gray">Initializing...</Text>
      </Box>
    );
  }

  if (phase === 'wizard') {
    return (
      <Wizard
        detected={detected}
        onComplete={cfg => {
          saveConfig(dotfilesDir, cfg);
          setConfig(cfg);
          const comps = parseComponents(dotfilesDir, cfg.system);
          setComponents(comps);
          setPhase('selector');
        }}
      />
    );
  }

  if (phase === 'selector') {
    return (
      <Selector
        system={config?.system ?? detected.system}
        components={components}
        onComplete={selected => {
          setSelectedComponents(selected);
          setPhase('runner');
        }}
        onCancel={() => exit()}
      />
    );
  }

  if (phase === 'runner') {
    return (
      <Runner
        components={selectedComponents}
        dotfilesDir={dotfilesDir}
        config={config!}
      />
    );
  }

  return null;
}
