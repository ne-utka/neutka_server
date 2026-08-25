<script setup lang="ts">
import { onMounted, ref, watch } from "vue";
import AuthPage from "@/pages/AuthPage.vue";
import HomePage from "@/pages/HomePage.vue";
import SettingsPage from "@/pages/SettingsPage.vue";
import {
  getAuthenticatedProfile,
  signOutMicrosoft,
} from "@/shared/api/launcher";
import {
  fitWindowToScreen,
  type AppScreen,
} from "@/shared/lib/window";
import AppHeader from "@/widgets/AppHeader.vue";

const screen = ref<AppScreen>("home");
const nickname = ref("123");
const authorized = ref(false);

watch(
  screen,
  (nextScreen) => {
    void fitWindowToScreen(nextScreen).catch((error) => {
      console.error("Unable to resize launcher window", error);
    });
  },
  { immediate: true },
);

onMounted(async () => {
  try {
    const profile = await getAuthenticatedProfile();
    if (profile) {
      nickname.value = profile.name;
      authorized.value = true;
    }
  } catch {
    // Browser-only preview has no Tauri IPC bridge.
  }
});

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
</script>

<template>
  <div class="app-shell">
    <AppHeader :screen="screen" @back="screen = 'home'" />
    <main class="app-content">
      <HomePage
        v-if="screen === 'home'"
        :nickname="nickname"
        :authorized="authorized"
        @logout="logout"
        @settings="screen = 'settings'"
      />
      <AuthPage
        v-else-if="screen === 'auth'"
        @complete="completeAuthorization"
      />
      <SettingsPage v-else />
    </main>
  </div>
</template>
