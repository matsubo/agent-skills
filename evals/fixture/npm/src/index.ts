import yaml from 'js-yaml';
import { z } from 'zod';

const Config = z.object({ name: z.string(), replicas: z.number().int().min(1) });

export function loadConfig(raw: string) {
  return Config.parse(yaml.load(raw));
}
