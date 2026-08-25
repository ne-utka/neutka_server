<script setup lang="ts">
import { ref } from "vue";
import AppIcon from "@/shared/ui/AppIcon.vue";

const memory = ref("2");
const memoryOptions = ["1", "2", "3", "4", "6", "8"];
</script>

<template>
  <section class="settings-page">
    <h1>Выделенная память</h1>

    <div class="select-shell">
      <select v-model="memory" aria-label="Выделенная память">
        <option v-for="value in memoryOptions" :key="value" :value="value">
          {{ value }} ГБ
        </option>
      </select>
      <AppIcon name="chevron" :size="20" />
    </div>

    <h2>Опциональные моды</h2>
    <div class="section-divider" />
  </section>
</template>

<style scoped>
.settings-page {
  width: 100%;
  padding: 32px 40px 0;
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
</style>
