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
