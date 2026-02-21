import React, {useState} from 'react';
import {Box, Text} from 'ink';
import TextInput from 'ink-text-input';
import SelectInput from 'ink-select-input';
import type {DotConfig} from '../config.js';
import type {DetectedSystem} from '../detector.js';
import {LOGO, colors} from './theme.js';

type Step = 'name' | 'env' | 'email' | 'yubikey';

interface WizardProps {
  detected: DetectedSystem;
  onComplete: (config: DotConfig) => void;
}

const ENV_ITEMS = [
  {label: '  Personal', value: 'personal'},
  {label: '  Work', value: 'work'},
];

export function Wizard({detected, onComplete}: WizardProps) {
  const [step, setStep] = useState<Step>('name');
  const [name, setName] = useState('');
  const [environment, setEnvironment] = useState<'personal' | 'work'>('personal');
  const [email, setEmail] = useState('');
  const [yubikey, setYubikey] = useState('');

  const handleNameSubmit = (value: string) => {
    const finalName = value.trim() || 'Jordan Garcia';
    setName(finalName);
    setStep('env');
  };

  const handleEnvSelect = (item: {label: string; value: string}) => {
    const env = item.value as 'personal' | 'work';
    setEnvironment(env);
    setStep('email');
  };

  const handleEmailSubmit = (value: string) => {
    const defaultEmail =
      environment === 'work'
        ? 'jordan.arickhogarcia@nestgenomics.com'
        : 'arickho@gmail.com';
    const finalEmail = value.trim() || defaultEmail;
    setEmail(finalEmail);
    setStep('yubikey');
  };

  const handleYubiKeySubmit = (value: string) => {
    onComplete({
      name,
      email,
      environment,
      system: detected.system,
      yubiKey: value.trim(),
    });
  };

  const stepLabels: Record<Step, string> = {
    name:    '1/4  Full Name',
    env:     '2/4  Environment',
    email:   '3/4  Email',
    yubikey: '4/4  YubiKey ID',
  };

  return (
    <Box flexDirection="column" padding={1} gap={1}>
      {/* Logo */}
      <Box flexDirection="column">
        {LOGO.split('\n').map((line, i) => (
          <Text key={i} color="magenta" bold>{line}</Text>
        ))}
      </Box>

      {/* Step label */}
      <Box>
        <Text color="cyan" bold>{stepLabels[step]}</Text>
        {step !== 'yubikey' && <Text color="red" bold>  *required</Text>}
        {step === 'yubikey' && <Text color="gray">  (optional — press Enter to skip)</Text>}
      </Box>

      <Box>
        <Text color="gray">{'─'.repeat(50)}</Text>
      </Box>

      {/* Step: Name */}
      {step === 'name' && (
        <Box gap={1}>
          <Text color="cyan" bold>› </Text>
          <TextInput
            value={name}
            onChange={setName}
            onSubmit={handleNameSubmit}
            placeholder="Jordan Garcia"
          />
        </Box>
      )}

      {/* Step: Environment */}
      {step === 'env' && (
        <SelectInput items={ENV_ITEMS} onSelect={handleEnvSelect} />
      )}

      {/* Step: Email */}
      {step === 'email' && (
        <Box gap={1}>
          <Text color="cyan" bold>› </Text>
          <TextInput
            value={email}
            onChange={setEmail}
            onSubmit={handleEmailSubmit}
            placeholder={
              environment === 'work' ? 'user@company.com' : 'user@gmail.com'
            }
          />
        </Box>
      )}

      {/* Step: YubiKey */}
      {step === 'yubikey' && (
        <Box gap={1}>
          <Text color="cyan" bold>› </Text>
          <TextInput
            value={yubikey}
            onChange={setYubikey}
            onSubmit={handleYubiKeySubmit}
            placeholder="ABC123... (Enter to skip)"
          />
        </Box>
      )}

      {/* Detected system hint */}
      <Box marginTop={1}>
        <Text color="gray">Detected system: </Text>
        <Text color="magenta">{detected.system}</Text>
      </Box>
    </Box>
  );
}
