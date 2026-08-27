<script setup lang="ts">
import { computed, ref } from "vue";
import type { DownloadProgress } from "@/entities/launcher/model";
import { openGameFolder } from "@/shared/api/launcher";
import AppIcon from "@/shared/ui/AppIcon.vue";
import PlayerAvatar from "@/shared/ui/PlayerAvatar.vue";

const props = defineProps<{
  nickname: string;
  authorized: boolean;
  authKind: "microsoft" | "telegram" | null;
  busy: boolean;
  gameRunning: boolean;
  needsDownload: boolean;
  remoteVersion: string | null;
  progress: DownloadProgress | null;
  error: string | null;
  notice: string | null;
}>();
defineEmits<{ play: []; logout: []; settings: [] }>();

const folderError = ref<string | null>(null);
const displayError = computed(() => folderError.value ?? props.error);
const accountLabel = computed(() => {
  if (!props.authorized) return "Не авторизован";
  return props.authKind === "microsoft"
    ? "Аккаунт Microsoft"
    : "Ник из Telegram";
});

const playLabel = computed(() => {
  if (props.gameRunning) return "Игра запущена";
  if (props.busy && props.progress) {
    if (props.progress.total > 0) {
      const percent = Math.min(
        99,
        Math.round((props.progress.received / props.progress.total) * 100),
      );
      return `${percent}%`;
    }
    return props.progress.label;
  }
  if (props.busy) return "Подготовка…";
  if (props.needsDownload) {
    return props.remoteVersion
      ? `Загрузить ${props.remoteVersion}`
      : "Загрузить";
  }
  return "Играть";
});

const percent = computed(() => {
  if (!props.progress || props.progress.total <= 0) return 0;
  return Math.min(
    100,
    Math.round((props.progress.received / props.progress.total) * 100),
  );
});

async function openFolder(): Promise<void> {
  try {
    await openGameFolder();
    folderError.value = null;
  } catch (caught) {
    folderError.value =
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
        <span>{{ accountLabel }}</span>
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
      @click="$emit('play')"
    >
      {{ playLabel }}
    </button>
    <div v-if="busy && !gameRunning" class="progress-track" aria-hidden="true">
      <span :style="{ width: `${percent}%` }" />
    </div>
    <p v-if="displayError" class="status-copy error">{{ displayError }}</p>
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
  padding-top: 40px;
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
  margin-top: 18px;
  padding: 0;
  color: #fff;
  border: 0;
  border-radius: 9px;
  background: var(--accent);
  font-size: 16px;
  font-weight: 700;
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
  margin-top: 10px;
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
