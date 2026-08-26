export interface ArchitectureStatus {
  backend: "ready";
  helper: "not-configured" | "available";
  configStorage: "app-data";
}

export interface LaunchRequest {
  profileId: string;
  javaPath?: string;
}

export interface LaunchReceipt {
  processId: number;
  startedAt: string;
}

export interface OptionalMod {
  id: string;
  name: string;
  file: string;
  sha256: string;
  size: number;
  defaultEnabled: boolean;
}

export interface DistributionStatus {
  baseUrl: string;
  remoteVersion: string | null;
  installedVersion: string | null;
  needsDownload: boolean;
  optionalMods: OptionalMod[];
  enabledOptionalModIds: string[];
  memoryGb: number;
  memoryOptions: number[];
  totalMemoryGb: number;
  recommendedMemoryGb: number;
  error: string | null;
}

export interface DownloadProgress {
  phase: string;
  label: string;
  received: number;
  total: number;
}

export interface LaunchStatus {
  busy: boolean;
  gameRunning: boolean;
}

export interface PlayResult {
  installedVersion: string;
  launched: boolean;
}
