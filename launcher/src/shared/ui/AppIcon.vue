<script setup lang="ts">
defineProps<{
  name:
    | "logo"
    | "minimize"
    | "close"
    | "logout"
    | "folder"
    | "settings"
    | "chevron";
  size?: number;
}>();
</script>

<template>
  <svg
    :width="size ?? 20"
    :height="size ?? 20"
    viewBox="0 0 24 24"
    fill="none"
    aria-hidden="true"
  >
    <template v-if="name === 'logo'">
      <circle cx="12" cy="12" r="10" fill="#22C55E" />
      <path
        d="M8.2 9.1 12 6.9l3.8 2.2v4.4L12 15.7l-3.8-2.2V9.1Z"
        fill="white"
      />
      <path d="m8.2 9.1 3.8 2.2 3.8-2.2M12 11.3v4.4" stroke="#22C55E" />
    </template>
    <path
      v-else-if="name === 'minimize'"
      d="M5 12h14"
      stroke="currentColor"
      stroke-width="1.5"
    />
    <path
      v-else-if="name === 'close'"
      d="m7 7 10 10M17 7 7 17"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
    />
    <template v-else-if="name === 'logout'">
      <path
        d="M10 5H6.8A1.8 1.8 0 0 0 5 6.8v10.4A1.8 1.8 0 0 0 6.8 19H10"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <path
        d="m14 8 4 4-4 4M18 12H9"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </template>
    <path
      v-else-if="name === 'folder'"
      d="M3.5 7.5h6l2-2h9v12.8H3.5V7.5Zm0 3h17"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linejoin="round"
    />
    <template v-else-if="name === 'settings'">
      <circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.8" />
      <path
        d="M12 3.5v2M12 18.5v2M20.5 12h-2M5.5 12h-2M18 6l-1.4 1.4M7.4 16.6 6 18M18 18l-1.4-1.4M7.4 7.4 6 6"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
      />
    </template>
    <path
      v-else-if="name === 'chevron'"
      d="m8 10 4 4 4-4"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
  </svg>
</template>
