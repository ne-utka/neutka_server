<script setup lang="ts">
import AppIcon from "@/shared/ui/AppIcon.vue";
import PlayerAvatar from "@/shared/ui/PlayerAvatar.vue";

defineProps<{ nickname: string; authorized: boolean }>();
defineEmits<{ logout: []; settings: [] }>();
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

    <button class="play-button" type="button">Играть</button>

    <div class="quick-actions">
      <button type="button">
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

.play-button:hover {
  background: var(--accent-hover);
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
