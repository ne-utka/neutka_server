<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import type { OptionalMod } from "@/entities/launcher/model";
import {
  getDistributionStatus,
  setMemoryGb,
  setOptionalMods,
} from "@/shared/api/launcher";
import AppIcon from "@/shared/ui/AppIcon.vue";

const props = defineProps<{
  busy: boolean;
  gameRunning: boolean;
}>();
defineEmits<{ reinstall: [] }>();

const memory = ref("4");
const memoryOptions = ref<number[]>([2, 4, 6, 8]);
const totalMemory = ref(0);
const recommendedMemory = ref(0);
const mods = ref<OptionalMod[]>([]);
const enabled = ref<string[]>([]);
const remoteError = ref<string | null>(null);

const reinstallDisabled = computed(
  () => props.busy || props.gameRunning,
);
const reinstallHint = computed(() => {
  if (props.gameRunning) {
    return "Закройте игру, чтобы переустановить клиент.";
  }
  if (props.busy) {
    return "Дождитесь окончания загрузки или запуска.";
  }
  return "Удалит локальную сборку и скачает её заново.";
});

onMounted(() => {
  void load();
});

async function load(): Promise<void> {
  try {
    const status = await getDistributionStatus();
    memory.value = String(status.memoryGb);
    memoryOptions.value = status.memoryOptions;
    totalMemory.value = status.totalMemoryGb;
    recommendedMemory.value = status.recommendedMemoryGb;
    mods.value = status.optionalMods;
    enabled.value = [...status.enabledOptionalModIds];
    remoteError.value = status.error;
  } catch {
    remoteError.value = "Не удалось получить список модов";
  }
}

async function onMemoryChange(): Promise<void> {
  try {
    await setMemoryGb(Number(memory.value));
  } catch (error) {
    remoteError.value =
      typeof error === "string" ? error : "Не удалось сохранить память";
  }
}

async function toggleMod(id: string): Promise<void> {
  const next = enabled.value.includes(id)
    ? enabled.value.filter((item) => item !== id)
    : [...enabled.value, id];
  enabled.value = next;
  try {
    await setOptionalMods(next);
  } catch (error) {
    remoteError.value =
      typeof error === "string" ? error : "Не удалось сохранить моды";
  }
}
</script>

<template>
  <section class="settings-page">
    <h1>Выделенная память</h1>

    <div class="select-shell">
      <select
        v-model="memory"
        aria-label="Выделенная память"
        @change="onMemoryChange"
      >
        <option
          v-for="value in memoryOptions"
          :key="value"
          :value="String(value)"
        >
          {{ value }} ГБ{{ value === recommendedMemory ? " — рекомендуем" : "" }}
        </option>
      </select>
      <AppIcon name="chevron" :size="20" />
    </div>
    <p v-if="totalMemory > 0" class="hint">
      В системе {{ totalMemory }} ГБ. Остальное нужно Windows, браузеру и
      голосовому чату, поэтому список ограничен.
    </p>

    <h2>Опциональные моды</h2>
    <div class="section-divider" />

    <p v-if="remoteError && mods.length === 0" class="hint">
      {{ remoteError }}
    </p>
    <p v-else-if="mods.length === 0" class="hint">
      На сервере пока нет optional-модов. Добавьте их в
      launcher/game/optional и в manifest.json.
    </p>
    <ul v-else class="mod-list">
      <li v-for="mod in mods" :key="mod.id">
        <button
          type="button"
          :class="{ active: enabled.includes(mod.id) }"
          :aria-pressed="enabled.includes(mod.id)"
          @click="toggleMod(mod.id)"
        >
          <span class="mod-name">{{ mod.name }}</span>
          <span class="mod-state">
            {{ enabled.includes(mod.id) ? "Вкл" : "Выкл" }}
          </span>
        </button>
      </li>
    </ul>

    <h2>Клиент</h2>
    <div class="section-divider" />
    <button
      class="reinstall-button"
      type="button"
      :disabled="reinstallDisabled"
      @click="$emit('reinstall')"
    >
      Переустановить клиент
    </button>
    <p class="hint">{{ reinstallHint }}</p>
  </section>
</template>

<style scoped>
.settings-page {
  width: 100%;
  height: 100%;
  overflow: auto;
  padding: 32px 40px 32px;
}

h1,
h2 {
  margin: 0;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
  line-height: 22px;
}

.select-shell {
  position: relative;
  width: 100%;
  height: 56px;
  margin-top: 20px;
}

select {
  width: 100%;
  height: 56px;
  padding: 0 52px 0 19px;
  color: #fff;
  border: 1px solid #404040;
  border-radius: 8px;
  appearance: none;
  background: #171717;
  font-size: 16px;
  font-weight: 500;
}

.select-shell svg {
  position: absolute;
  top: 18px;
  right: 18px;
  color: #a3a3a3;
  pointer-events: none;
}

h2 {
  margin-top: 38px;
}

.section-divider {
  width: 100%;
  height: 2px;
  margin-top: 16px;
  background: #404040;
}

.hint {
  margin: 16px 0 0;
  color: #737373;
  font-size: 13px;
  line-height: 18px;
}

.mod-list {
  margin: 16px 0 0;
  padding: 0;
  list-style: none;
}

.mod-list li + li {
  margin-top: 10px;
}

.mod-list button {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  height: 56px;
  padding: 0 18px;
  color: #fff;
  border: 0;
  border-radius: 8px;
  background: #1f1f1f;
  font-size: 15px;
  font-weight: 600;
}

.mod-state {
  color: #a3a3a3;
  font-size: 13px;
}

.mod-list button.active .mod-state {
  color: var(--accent);
}

.reinstall-button {
  width: 100%;
  height: 56px;
  margin-top: 16px;
  padding: 0;
  color: #fff;
  border: 0;
  border-radius: 8px;
  background: var(--accent);
  font-size: 16px;
  font-weight: 700;
}

.reinstall-button:hover:not(:disabled) {
  background: var(--accent-hover);
}

.reinstall-button:disabled {
  color: #505050;
  background: #2b2b2b;
  cursor: default;
}
</style>
