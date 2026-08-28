<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from "vue";

const REFRESH_INTERVAL_MS = 60_000;

const props = defineProps<{ nickname: string }>();
const avatarUrl = ref<string | null>(null);
const state = ref<"loading" | "loaded" | "error">("loading");

let activeController: AbortController | null = null;
let activeObjectUrl: string | null = null;
let refreshTimer = 0;

function abortActiveRequest(): void {
  activeController?.abort();
  activeController = null;
}

function revokeObjectUrl(): void {
  if (activeObjectUrl) {
    URL.revokeObjectURL(activeObjectUrl);
    activeObjectUrl = null;
  }
}

function resetRequest(): void {
  abortActiveRequest();
  revokeObjectUrl();
  avatarUrl.value = null;
}

async function loadAvatar(options: { showLoading: boolean }): Promise<void> {
  const nickname = props.nickname.trim();
  abortActiveRequest();

  if (options.showLoading) {
    revokeObjectUrl();
    avatarUrl.value = null;
    state.value = "loading";
  }

  if (!nickname) {
    if (options.showLoading || !avatarUrl.value) {
      state.value = "error";
    }
    return;
  }

  const controller = new AbortController();
  activeController = controller;

  try {
    const response = await fetch(
      `https://mc-heads.net/avatar/${encodeURIComponent(nickname)}/64?t=${Date.now()}`,
      {
        cache: "no-store",
        signal: controller.signal,
      },
    );

    if (!response.ok) throw new Error(`Avatar API returned ${response.status}`);

    const blob = await response.blob();
    if (!blob.type.startsWith("image/")) {
      throw new Error("Avatar API did not return an image");
    }

    const nextObjectUrl = URL.createObjectURL(blob);
    const previousObjectUrl = activeObjectUrl;
    activeObjectUrl = nextObjectUrl;
    avatarUrl.value = nextObjectUrl;
    state.value = "loaded";
    if (previousObjectUrl) URL.revokeObjectURL(previousObjectUrl);
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      return;
    }
    if (options.showLoading || !avatarUrl.value) {
      state.value = "error";
    }
    console.warn("Unable to load player avatar", error);
  } finally {
    if (activeController === controller) activeController = null;
  }
}

function refreshInBackground(): void {
  if (document.visibilityState === "hidden") return;
  void loadAvatar({ showLoading: false });
}

watch(
  () => props.nickname,
  () => {
    void loadAvatar({ showLoading: true });
  },
  { immediate: true },
);

onMounted(() => {
  window.addEventListener("focus", refreshInBackground);
  document.addEventListener("visibilitychange", refreshInBackground);
  refreshTimer = window.setInterval(refreshInBackground, REFRESH_INTERVAL_MS);
});

onBeforeUnmount(() => {
  window.removeEventListener("focus", refreshInBackground);
  document.removeEventListener("visibilitychange", refreshInBackground);
  window.clearInterval(refreshTimer);
  resetRequest();
});
</script>

<template>
  <div
    v-if="state === 'loading'"
    class="avatar avatar-loading"
    role="status"
    aria-label="Загрузка головы игрока"
  >
    <span class="spinner" />
  </div>
  <img
    v-else-if="state === 'loaded' && avatarUrl"
    class="avatar"
    :src="avatarUrl"
    :alt="`Голова игрока ${nickname}`"
  />
  <svg
    v-else
    class="avatar"
    viewBox="0 0 8 8"
    shape-rendering="crispEdges"
    aria-label="Заглушка Алекс"
  >
    <rect width="8" height="8" fill="#F2B58B" />
    <path d="M0 0h8v2H0zM0 2h2v3H0zM6 2h2v2H6z" fill="#9B4E24" />
    <path d="M2 2h4v1H2zM1 5h1v2H1zM6 4h1v3H6z" fill="#C66B32" />
    <path d="M2 4h1v1H2zM5 4h1v1H5z" fill="#3C6E67" />
    <path d="M3 5h2v1H3z" fill="#D89570" />
    <path d="M2 7h4v1H2z" fill="#8B492B" />
  </svg>
</template>

<style scoped>
.avatar {
  display: block;
  width: 64px;
  height: 64px;
  border-radius: 8px;
  image-rendering: pixelated;
  object-fit: cover;
}

.avatar-loading {
  display: grid;
  background: #262626;
  image-rendering: auto;
  place-items: center;
}

.spinner {
  width: 26px;
  height: 26px;
  border: 3px solid #404040;
  border-top-color: #a3a3a3;
  border-radius: 50%;
  animation: spin 0.75s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .spinner {
    animation-duration: 1.5s;
  }
}
</style>
