import { LogicalSize } from "@tauri-apps/api/dpi";
import { getCurrentWindow } from "@tauri-apps/api/window";

export type AppScreen = "home" | "auth" | "settings";

const SCREEN_SIZES: Record<AppScreen, readonly [number, number]> = {
  home: [456, 430],
  auth: [456, 547],
  settings: [528, 679],
};

function isTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

export async function fitWindowToScreen(screen: AppScreen): Promise<void> {
  if (!isTauri()) return;

  const [width, height] = SCREEN_SIZES[screen];
  const appWindow = getCurrentWindow();
  await appWindow.setSize(new LogicalSize(width, height));
  await appWindow.center();
}

export async function minimizeWindow(): Promise<void> {
  if (isTauri()) await getCurrentWindow().minimize();
}

export async function closeWindow(): Promise<void> {
  if (isTauri()) await getCurrentWindow().close();
}
