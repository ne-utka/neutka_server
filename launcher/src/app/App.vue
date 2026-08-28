<script setup lang="ts">
import { onMounted, onUnmounted, ref, watch } from "vue";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import AuthPage from "@/pages/AuthPage.vue";
import HomePage from "@/pages/HomePage.vue";
import SettingsPage from "@/pages/SettingsPage.vue";
import type {
  DownloadProgress,
  LaunchStatus,
} from "@/entities/launcher/model";
import {
  getDistributionStatus,
  getAuthenticatedProfile,
  getLaunchStatus,
  playGame,
  reinstallGame,
  signOut,
  type AuthenticatedProfile,
} from "@/shared/api/launcher";
import {
  fitWindowToScreen,
  type AppScreen,
} from "@/shared/lib/window";
import AppHeader from "@/widgets/AppHeader.vue";

const screen = ref<AppScreen>("auth");
const nickname = ref("");
const authorized = ref(false);
const authKind = ref<AuthenticatedProfile["kind"] | null>(null);
const booting = ref(true);
const launchBusy = ref(false);
const gameRunning = ref(false);
const launchProgress = ref<DownloadProgress | null>(null);
const launchError = ref<string | null>(null);
const launchNotice = ref<string | null>(null);
const needsDownload = ref(false);
const remoteVersion = ref<string | null>(null);

let unlistenProgress: UnlistenFn | null = null;
let unlistenLaunchState: UnlistenFn | null = null;

watch(
  screen,
  (nextScreen) => {
    void fitWindowToScreen(nextScreen).catch((error) => {
      console.error("Unable to resize launcher window", error);
    });
  },
  { immediate: true },
);

onMounted(() => {
  void boot();
});

onUnmounted(() => {
  void unlistenProgress?.();
  void unlistenLaunchState?.();
});

async function boot(): Promise<void> {
  await restoreAuthentication();
  booting.value = false;
  await initializeLaunchTracking();
}

async function restoreAuthentication(): Promise<void> {
  try {
    const profile = await getAuthenticatedProfile();
    if (profile) {
      applyProfile(profile);
    }
  } catch {
    // Browser-only preview has no Tauri IPC bridge.
  }
}

async function initializeLaunchTracking(): Promise<void> {
  try {
    unlistenProgress = await listen<DownloadProgress>(
      "download-progress",
      (event) => {
        launchProgress.value = event.payload;
      },
    );
    unlistenLaunchState = await listen<LaunchStatus>(
      "launch-state",
      (event) => {
        applyLaunchStatus(event.payload);
      },
    );
  } catch {
    // Browser-only preview has no Tauri event bus.
  }

  try {
    const status = await getLaunchStatus();
    applyLaunchStatus(status);
  } catch {
    // Browser-only preview has no Tauri IPC bridge.
  }

  await refreshDistributionStatus();
}

async function refreshDistributionStatus(): Promise<void> {
  try {
    const status = await getDistributionStatus();
    needsDownload.value = status.needsDownload;
    remoteVersion.value = status.remoteVersion;
    if (status.error && !status.remoteVersion) {
      launchError.value = status.error;
    }
  } catch {
    // Browser-only preview has no Tauri IPC bridge.
  }
}

async function startGame(options: { reinstall?: boolean } = {}): Promise<void> {
  if (launchBusy.value) return;

  launchBusy.value = true;
  launchError.value = null;
  launchNotice.value = null;
  launchProgress.value = {
    phase: options.reinstall ? "extract" : "manifest",
    label: options.reinstall
      ? "Удаление текущей сборки…"
      : "Подключение к серверу…",
    received: 0,
    total: 0,
  };

  try {
    const result = options.reinstall
      ? await reinstallGame()
      : await playGame();
    needsDownload.value = false;
    remoteVersion.value = result.installedVersion;
  } catch (caught) {
    const message =
      typeof caught === "string"
        ? caught
        : caught && typeof caught === "object" && "message" in caught
          ? String((caught as { message: unknown }).message)
          : "Не удалось подготовить игру";
    if (message === "Сначала авторизуйтесь") {
      await logout();
      return;
    }
    launchError.value = message;
  } finally {
    try {
      applyLaunchStatus(await getLaunchStatus());
    } catch {
      launchBusy.value = false;
      gameRunning.value = false;
    }
    if (!launchBusy.value) launchProgress.value = null;
  }
}

function applyLaunchStatus(status: LaunchStatus): void {
  const wasRunning = gameRunning.value;
  launchBusy.value = status.busy;
  gameRunning.value = status.gameRunning;

  if (status.gameRunning) {
    launchProgress.value = null;
    launchError.value = null;
    launchNotice.value = "Игра запущена";
  } else if (!status.busy) {
    launchProgress.value = null;
    if (wasRunning) launchNotice.value = null;
  }
}

function applyProfile(profile: AuthenticatedProfile): void {
  nickname.value = profile.name;
  authorized.value = true;
  authKind.value = profile.kind;
  screen.value = "home";
}

function completeAuthorization(profile: AuthenticatedProfile): void {
  applyProfile(profile);
}

async function logout(): Promise<void> {
  try {
    await signOut();
  } catch {
    // Clear the local UI state even if the backend session is already gone.
  }
  nickname.value = "";
  authorized.value = false;
  authKind.value = null;
  screen.value = "auth";
}

function reinstallClient(): void {
  if (launchBusy.value) return;
  screen.value = "home";
  void startGame({ reinstall: true });
}
</script>

<template>
  <div class="app-shell">
    <AppHeader :screen="screen" @back="screen = 'home'" />
    <main class="app-content">
      <HomePage
        v-if="!booting && screen === 'home'"
        :nickname="nickname"
        :authorized="authorized"
        :auth-kind="authKind"
        :busy="launchBusy"
        :game-running="gameRunning"
        :needs-download="needsDownload"
        :remote-version="remoteVersion"
        :progress="launchProgress"
        :error="launchError"
        :notice="launchNotice"
        @play="startGame()"
        @logout="logout"
        @settings="screen = 'settings'"
      />
      <AuthPage
        v-else-if="!booting && screen === 'auth'"
        @complete="completeAuthorization"
      />
      <SettingsPage
        v-else-if="!booting"
        :busy="launchBusy"
        :game-running="gameRunning"
        @reinstall="reinstallClient"
      />
    </main>
  </div>
</template>
