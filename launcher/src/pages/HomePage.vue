<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import type { DownloadProgress } from "@/entities/launcher/model";
import {
  getDistributionStatus,
  openGameFolder,
  playGame,
} from "@/shared/api/launcher";
import AppIcon from "@/shared/ui/AppIcon.vue";
import PlayerAvatar from "@/shared/ui/PlayerAvatar.vue";

const props = defineProps<{ nickname: string; authorized: boolean }>();
defineEmits<{ logout: []; settings: [] }>();

const busy = ref(false);
const needsDownload = ref(false);
const remoteVersion = ref<string | null>(null);
const progress = ref<DownloadProgress | null>(null);
const error = ref<string | null>(null);
const notice = ref<string | null>(null);

let unlisten: UnlistenFn | null = null;

const playLabel = computed(() => {
  if (busy.value && progress.value) {
    if (progress.value.total > 0) {
      const percent = Math.min(
        99,
        Math.round((progress.value.received / progress.value.total) * 100),
      );
      return `${percent}%`;
    }
    return progress.value.label;
  }
  if (busy.value) return "Подготовка…";
  if (needsDownload.value) {
    return remoteVersion.value
      ? `Загрузить ${remoteVersion.value}`
      : "Загрузить";
  }
  return "Играть";
});

const percent = computed(() => {
  if (!progress.value || progress.value.total <= 0) return 0;
  return Math.min(
    100,
    Math.round((progress.value.received / progress.value.total) * 100),
  );
});

onMounted(async () => {
  await refreshStatus();
  try {
    unlisten = await listen<DownloadProgress>("download-progress", (event) => {
      progress.value = event.payload;
    });
  } catch {
    // Browser-only preview has no Tauri event bus.
  }
});

onUnmounted(() => {
  void unlisten?.();
});

async function refreshStatus(): Promise<void> {
  try {
    const status = await getDistributionStatus();
    needsDownload.value = status.needsDownload;
    remoteVersion.value = status.remoteVersion;
    if (status.error && !status.remoteVersion) {
      error.value = status.error;
    }
  } catch {
    // Preview without IPC.
  }
}

async function play(): Promise<void> {
  if (busy.value) return;
  busy.value = true;
  error.value = null;
  notice.value = null;
  progress.value = {
    phase: "manifest",
    label: "Подключение к серверу…",
    received: 0,
    total: 0,
  };

  try {
    const result = await playGame(props.nickname);
    needsDownload.value = false;
    remoteVersion.value = result.installedVersion;
    notice.value = result.launched ? "Игра запущена" : "Сборка установлена";
  } catch (caught) {
    error.value =
      typeof caught === "string" ? caught : "Не удалось подготовить игру";
  } finally {
    busy.value = false;
    progress.value = null;
  }
}

async function openFolder(): Promise<void> {
  try {
    await openGameFolder();
  } catch (caught) {
    error.value =
      typeof caught === "string" ? caught : "Не удалось открыть папку";
  }
}
</script>

<template>
  <section class="home-page">
    <div class="profile">
      <PlayerAvatar :nickname="nickname" />
      <div class="profile-copy">
        <strong>{{ nickname }}</strong>
        <span>{{ authorized ? "Авторизован" : "Не авторизован" }}</span>
      </div>
      <button
        class="logout-button"
        type="button"
        aria-label="Выйти из аккаунта"
        @click="$emit('logout')"
      >
        <AppIcon name="logout" :size="24" />
      </button>
    </div>

    <button
      class="play-button"
      type="button"
      :disabled="busy"
      @click="play"
    >
      {{ playLabel }}
    </button>
    <div v-if="busy" class="progress-track" aria-hidden="true">
      <span :style="{ width: `${percent}%` }" />
    </div>
    <p v-if="error" class="status-copy error">{{ error }}</p>
    <p v-else-if="notice" class="status-copy">{{ notice }}</p>
    <p v-else-if="progress" class="status-copy">{{ progress.label }}</p>

    <div class="quick-actions">
      <button type="button" @click="openFolder">
        <AppIcon name="folder" :size="24" />
        <span>Папка</span>
      </button>
      <button type="button" @click="$emit('settings')">
        <AppIcon name="settings" :size="24" />
        <span>Настройки</span>
      </button>
    </div>
  </section>
</template>

<style scoped>
.home-page {
  width: 376px;
  margin: 0 auto;
  padding-top: 64px;
}

.profile {
  display: flex;
  align-items: center;
  height: 64px;
}

.profile-copy {
  display: flex;
  min-width: 0;
  margin-left: 16px;
  flex-direction: column;
  gap: 4px;
}

.profile-copy strong {
  overflow: hidden;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  line-height: 22px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.profile-copy span {
  color: #a3a3a3;
  font-size: 14px;
  font-weight: 700;
  line-height: 18px;
}

.logout-button {
  display: grid;
  width: 52px;
  height: 52px;
  margin-left: auto;
  padding: 0;
  color: #a3a3a3;
  border: 2px solid #525252;
  border-radius: 9px;
  background: #404040;
  place-items: center;
}

.logout-button:hover,
.quick-actions button:hover {
  background: #4a4a4a;
}

.play-button {
  width: 376px;
  height: 64px;
  margin-top: 24px;
  padding: 0;
  color: #fff;
  border: 0;
  border-radius: 9px;
  background: var(--accent);
  font-size: 16px;
  font-weight: 600;
}

.play-button:hover:not(:disabled) {
  background: var(--accent-hover);
}

.play-button:disabled {
  cursor: wait;
  opacity: 0.86;
}

.progress-track {
  width: 376px;
  height: 4px;
  margin-top: 8px;
  overflow: hidden;
  border-radius: 2px;
  background: #2b2b2b;
}

.progress-track span {
  display: block;
  height: 100%;
  background: var(--accent);
}

.status-copy {
  margin: 10px 0 0;
  color: #a3a3a3;
  font-size: 13px;
  font-weight: 500;
  line-height: 18px;
}

.status-copy.error {
  color: #f0b4b4;
}

.quick-actions {
  display: grid;
  margin-top: 12px;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.quick-actions button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  height: 64px;
  padding: 0;
  color: #fff;
  border: 2px solid #555;
  border-radius: 8px;
  background: #404040;
  font-size: 16px;
  font-weight: 700;
}

.quick-actions svg {
  color: #a3a3a3;
}
</style>
