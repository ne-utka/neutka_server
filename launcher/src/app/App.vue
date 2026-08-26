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
  signOutMicrosoft,
} from "@/shared/api/launcher";
import {
  fitWindowToScreen,
  type AppScreen,
} from "@/shared/lib/window";
import AppHeader from "@/widgets/AppHeader.vue";

const screen = ref<AppScreen>("auth");
const nickname = ref("");
const authorized = ref(false);
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
  void restoreAuthentication();
  void initializeLaunchTracking();
});

onUnmounted(() => {
  void unlistenProgress?.();
  void unlistenLaunchState?.();
});

async function restoreAuthentication(): Promise<void> {
  try {
    const profile = await getAuthenticatedProfile();
    if (profile) {
      nickname.value = profile.name;
      authorized.value = true;
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
      ? await reinstallGame(nickname.value)
      : await playGame(nickname.value);
    needsDownload.value = false;
    remoteVersion.value = result.installedVersion;
  } catch (caught) {
    launchError.value =
      typeof caught === "string" ? caught : "Не удалось подготовить игру";
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

function completeAuthorization(value: string, isAuthorized: boolean): void {
  nickname.value = value;
  authorized.value = isAuthorized;
  screen.value = "home";
}

async function logout(): Promise<void> {
  if (authorized.value) {
    try {
      await signOutMicrosoft();
    } catch {
      // Clear the local UI state even if the backend session is already gone.
    }
  }
  authorized.value = false;
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
        v-if="screen === 'home'"
        :nickname="nickname"
        :authorized="authorized"
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
        v-else-if="screen === 'auth'"
        @complete="completeAuthorization"
      />
      <SettingsPage
        v-else
        :busy="launchBusy"
        :game-running="gameRunning"
        @reinstall="reinstallClient"
      />
    </main>
  </div>
</template>
