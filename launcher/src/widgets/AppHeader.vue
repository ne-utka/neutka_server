<script setup lang="ts">
import launcherIcon from "@/shared/assets/launcher-icon.png";
import type { AppScreen } from "@/shared/lib/window";
import { closeWindow, minimizeWindow } from "@/shared/lib/window";
import AppIcon from "@/shared/ui/AppIcon.vue";

const props = defineProps<{ screen: AppScreen }>();
const emit = defineEmits<{ back: [] }>();
</script>

<template>
  <header class="title-bar" data-tauri-drag-region>
    <button
      v-if="props.screen === 'settings'"
      class="title-identity title-back"
      type="button"
      aria-label="Вернуться на главный экран"
      @click="emit('back')"
    >
      <img class="launcher-mark" :src="launcherIcon" alt="" />
      <span>Настройки</span>
    </button>
    <div v-else class="title-identity" data-tauri-drag-region>
      <img class="launcher-mark" :src="launcherIcon" alt="" />
      <span data-tauri-drag-region>SpringRP</span>
    </div>

    <div class="window-controls">
      <button type="button" aria-label="Свернуть" @click="minimizeWindow">
        <AppIcon name="minimize" :size="16" />
      </button>
      <button
        class="close-control"
        type="button"
        aria-label="Закрыть"
        @click="closeWindow"
      >
        <AppIcon name="close" :size="16" />
      </button>
    </div>
  </header>
</template>

<style scoped>
.title-bar {
  display: flex;
  flex: 0 0 32px;
  align-items: center;
  justify-content: space-between;
  height: 32px;
  color: #fff;
  background: #0b0b0b;
  user-select: none;
}

.title-identity {
  display: flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
  height: 32px;
  padding: 0 8px;
  color: #fff;
  border: 0;
  background: transparent;
  font-size: 12px;
  font-weight: 500;
  line-height: 1;
}

.title-back {
  cursor: pointer;
}

.launcher-mark {
  display: block;
  width: 16px;
  height: 16px;
  border-radius: 4px;
}

.window-controls {
  display: flex;
  height: 32px;
}

.window-controls button {
  display: grid;
  width: 46px;
  height: 32px;
  padding: 0;
  color: #a3a3a3;
  border: 0;
  background: transparent;
  place-items: center;
}

.window-controls button:hover {
  color: #fff;
  background: #282828;
}

.window-controls .close-control:hover {
  background: #c42b1c;
}
</style>
