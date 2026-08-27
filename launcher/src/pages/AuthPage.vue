<script setup lang="ts">
import { computed, ref } from "vue";
import {
  completeMicrosoftAuth,
  completeNicknameAuth,
  startMicrosoftAuth,
  startNicknameAuth,
  type DeviceCodeChallenge,
  type NicknameChallenge,
} from "@/shared/api/launcher";
import {
  fitWindowToMicrosoftAuth,
  fitWindowToScreen,
} from "@/shared/lib/window";

const emit = defineEmits<{
  complete: [nickname: string, authorized: boolean];
}>();
const nickname = ref("");
const microsoftLoading = ref(false);
const microsoftStatusVisible = ref(false);
const challenge = ref<DeviceCodeChallenge | null>(null);
const oauthError = ref<string | null>(null);
const nickStatusVisible = ref(false);
const nickLoading = ref(false);
const nickChallenge = ref<NicknameChallenge | null>(null);
const nickError = ref<string | null>(null);
const nickUnbound = ref(false);
const codeCopied = ref(false);
let microsoftAttempt = 0;
let nickAttempt = 0;
let copiedReset: ReturnType<typeof setTimeout> | null = null;

const isValid = computed(() => /^[A-Za-z0-9_]{3,16}$/.test(nickname.value));
const nickWaiting = computed(
  () => nickStatusVisible.value && !nickUnbound.value && !nickError.value,
);

function errorText(error: unknown, fallback: string): string {
  if (typeof error === "string") return error;
  if (error && typeof error === "object" && "message" in error) {
    const message = (error as { message: unknown }).message;
    if (typeof message === "string") return message;
  }
  return fallback;
}

async function continueWithNickname(): Promise<void> {
  if (!isValid.value || nickLoading.value || microsoftLoading.value) return;

  const attempt = ++nickAttempt;
  nickLoading.value = true;
  nickStatusVisible.value = true;
  nickChallenge.value = null;
  nickError.value = null;
  nickUnbound.value = false;
  codeCopied.value = false;
  void fitWindowToMicrosoftAuth();

  try {
    const nextChallenge = await startNicknameAuth(nickname.value);
    if (attempt !== nickAttempt) return;
    nickChallenge.value = nextChallenge;
    const profile = await completeNicknameAuth(nextChallenge);
    if (attempt !== nickAttempt) return;
    emit("complete", profile.name, true);
  } catch (error) {
    if (attempt !== nickAttempt) return;
    const message = errorText(error, "Не удалось войти по нику");
    if (message === "not_bound") {
      nickUnbound.value = true;
      nickError.value = null;
      return;
    }
    nickError.value = message;
  } finally {
    if (attempt === nickAttempt) {
      nickLoading.value = false;
    }
  }
}

async function authorizeMicrosoft(): Promise<void> {
  if (microsoftLoading.value || nickLoading.value) return;

  const attempt = ++microsoftAttempt;
  microsoftLoading.value = true;
  microsoftStatusVisible.value = true;
  challenge.value = null;
  oauthError.value = null;
  codeCopied.value = false;
  void fitWindowToMicrosoftAuth();

  try {
    const deviceChallenge = await startMicrosoftAuth();
    if (attempt !== microsoftAttempt) return;
    challenge.value = deviceChallenge;
    const profile = await completeMicrosoftAuth(deviceChallenge);
    if (attempt !== microsoftAttempt) return;
    emit("complete", profile.name, true);
  } catch (error) {
    if (attempt !== microsoftAttempt) return;
    oauthError.value = errorText(
      error,
      "Не удалось выполнить авторизацию Microsoft",
    );
  } finally {
    if (attempt === microsoftAttempt) {
      microsoftLoading.value = false;
    }
  }
}

function closeMicrosoftStatus(): void {
  microsoftAttempt += 1;
  microsoftStatusVisible.value = false;
  microsoftLoading.value = false;
  challenge.value = null;
  oauthError.value = null;
  codeCopied.value = false;
  if (copiedReset) {
    clearTimeout(copiedReset);
    copiedReset = null;
  }
  void fitWindowToScreen("auth");
}

function closeNickStatus(): void {
  nickAttempt += 1;
  nickStatusVisible.value = false;
  nickLoading.value = false;
  nickChallenge.value = null;
  nickError.value = null;
  nickUnbound.value = false;
  codeCopied.value = false;
  if (copiedReset) {
    clearTimeout(copiedReset);
    copiedReset = null;
  }
  void fitWindowToScreen("auth");
}

async function copyDisplayedCode(value: string | undefined): Promise<void> {
  if (!value) return;
  const plain = value.replace(/\s+/g, "");

  try {
    await navigator.clipboard.writeText(plain);
  } catch {
    const field = document.createElement("textarea");
    field.value = plain;
    field.setAttribute("readonly", "");
    field.style.position = "fixed";
    field.style.left = "-9999px";
    document.body.append(field);
    field.select();
    document.execCommand("copy");
    field.remove();
  }

  codeCopied.value = true;
  if (copiedReset) clearTimeout(copiedReset);
  copiedReset = setTimeout(() => {
    codeCopied.value = false;
    copiedReset = null;
  }, 2000);
}
</script>

<template>
  <section class="auth-page">
    <div class="oauth-actions">
      <button
        class="microsoft-auth-button"
        type="button"
        :disabled="microsoftLoading || nickLoading"
        @click="authorizeMicrosoft"
      >
        <svg
          class="microsoft-icon"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <path fill="#F25022" d="M2 2h9.5v9.5H2z" />
          <path fill="#7FBA00" d="M12.5 2H22v9.5h-9.5z" />
          <path fill="#00A4EF" d="M2 12.5h9.5V22H2z" />
          <path fill="#FFB900" d="M12.5 12.5H22V22h-9.5z" />
        </svg>
        <span>Авторизация Microsoft</span>
      </button>
    </div>

    <div class="divider" aria-hidden="true">
      <span />
      <p>или</p>
      <span />
    </div>

    <form @submit.prevent="continueWithNickname">
      <input
        v-model="nickname"
        type="text"
        inputmode="text"
        maxlength="16"
        autocomplete="username"
        placeholder="Введите ник"
        aria-describedby="nickname-hint"
      />
      <p id="nickname-hint" class="hint">
        Латиница, от 3 до 16 символов
      </p>
      <button
        class="continue-button"
        type="submit"
        :disabled="!isValid || nickLoading || microsoftLoading"
      >
        Продолжить
      </button>
    </form>

    <div
      v-if="microsoftStatusVisible"
      class="microsoft-status"
      role="dialog"
      aria-live="polite"
      aria-label="Авторизация Microsoft"
    >
      <span v-if="!oauthError" class="oauth-spinner" />
      <h2>
        {{
          oauthError
            ? "Ошибка авторизации"
            : challenge
              ? "Завершите вход в браузере"
              : "Подготовка входа…"
        }}
      </h2>
      <button
        v-if="challenge && !oauthError"
        class="microsoft-code"
        type="button"
        aria-label="Скопировать код Microsoft"
        @click="copyDisplayedCode(challenge.userCode)"
      >
        <span>{{ challenge.userCode }}</span>
      </button>
      <p v-if="challenge && !oauthError">
        {{ codeCopied ? "(скопировано)" : "Введите этот код на странице Microsoft" }}
      </p>
      <p v-if="oauthError" class="oauth-error">{{ oauthError }}</p>
      <button
        class="dismiss-button"
        type="button"
        @click="closeMicrosoftStatus"
      >
        Вернуться
      </button>
    </div>

    <div
      v-if="nickStatusVisible"
      class="microsoft-status"
      role="dialog"
      aria-live="polite"
      aria-label="Вход по нику"
    >
      <span v-if="nickWaiting" class="oauth-spinner" />
      <h2>
        {{
          nickUnbound
            ? "Ник не привязан"
            : nickError
              ? "Ошибка входа"
              : nickChallenge
                ? "Подтвердите вход в Telegram"
                : "Проверяем ник…"
        }}
      </h2>
      <button
        v-if="nickChallenge && nickWaiting"
        class="microsoft-code"
        type="button"
        aria-label="Скопировать код"
        @click="copyDisplayedCode(nickChallenge.userCode)"
      >
        <span>{{ nickChallenge.userCode }}</span>
      </button>
      <p v-if="nickChallenge && nickWaiting">
        {{
          codeCopied
            ? "(скопировано)"
            : "Отправьте этот код боту @springauthbot"
        }}
      </p>
      <p v-if="nickUnbound" class="oauth-error">
        Вы не привязали никнейм в
        <a href="https://t.me/springauthbot" target="_blank" rel="noreferrer">
          @springauthbot
        </a>.
        Напишите боту /auth и этот ник, затем нажмите «Продолжить» снова.
      </p>
      <p v-if="nickError" class="oauth-error">{{ nickError }}</p>
      <button
        class="dismiss-button"
        type="button"
        @click="closeNickStatus"
      >
        Вернуться
      </button>
    </div>
  </section>
</template>

<style scoped>
.auth-page {
  width: 376px;
  margin: 0 auto;
  padding: 26px 0;
}

.oauth-actions {
  display: grid;
}

.oauth-actions button {
  width: 376px;
  height: 64px;
  padding: 0;
  color: #fff;
  border: 0;
  border-radius: 9px;
  background: var(--accent);
  font-size: 17px;
  font-weight: 600;
}

.oauth-actions button:not(:disabled):hover,
.continue-button:not(:disabled):hover {
  background: var(--accent-hover);
}

.oauth-actions button:disabled {
  cursor: wait;
  opacity: 0.72;
}

.oauth-actions .microsoft-auth-button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.microsoft-icon {
  width: 20px;
  height: 20px;
  flex: 0 0 auto;
}

.divider {
  display: grid;
  align-items: center;
  margin: 20px 0 16px;
  grid-template-columns: 1fr auto 1fr;
  gap: 16px;
}

.divider span {
  height: 2px;
  background: #404040;
}

.divider p {
  margin: 0;
  color: #565656;
  font-size: 14px;
  font-weight: 700;
  line-height: 18px;
}

form {
  margin: 0;
}

input {
  width: 376px;
  height: 56px;
  padding: 0 19px;
  color: #fff;
  border: 1px solid #404040;
  border-radius: 8px;
  background: transparent;
  caret-color: var(--accent);
  font-size: 16px;
  font-weight: 400;
}

input::placeholder {
  color: #696969;
  opacity: 1;
}

input:focus {
  border-color: #525252;
  outline: none;
}

.hint {
  margin: 6px 0 0;
  color: #565656;
  font-size: 12px;
  font-weight: 700;
  line-height: 15px;
}

.continue-button {
  width: 376px;
  height: 64px;
  margin-top: 16px;
  padding: 0;
  color: #fff;
  border: 0;
  border-radius: 8px;
  background: var(--accent);
  font-size: 17px;
  font-weight: 600;
}

.continue-button:disabled {
  color: #505050;
  background: #2b2b2b;
  cursor: default;
}

.microsoft-status {
  position: fixed;
  z-index: 20;
  inset: 32px 0 0;
  display: flex;
  align-items: center;
  padding: 24px 40px 88px;
  background: #171717;
  text-align: center;
  flex-direction: column;
  justify-content: center;
}

.microsoft-status h2 {
  margin: 14px 0 0;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
}

.microsoft-status .microsoft-code {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  margin-top: 16px;
  padding: 12px 18px;
  color: #fff;
  border: 1px solid #404040;
  border-radius: 8px;
  background: #222;
  font-family: "Inter Variable", Inter, sans-serif;
  font-size: 24px;
  font-weight: 700;
  text-align: center;
}

.microsoft-status .microsoft-code span {
  letter-spacing: 0.14em;
  margin-inline-end: -0.14em;
}

.microsoft-status .microsoft-code:hover {
  border-color: #525252;
  background: #2a2a2a;
}

.microsoft-status p {
  margin: 8px 0 0;
  color: #a3a3a3;
  font-size: 13px;
  line-height: 18px;
}

.microsoft-status a {
  color: #fff;
  text-decoration: underline;
}

.oauth-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #404040;
  border-top-color: #a3a3a3;
  border-radius: 50%;
  animation: oauth-spin 0.75s linear infinite;
}

.oauth-error {
  max-width: 340px;
  color: #d4d4d4 !important;
}

.dismiss-button {
  position: absolute;
  right: 40px;
  bottom: 24px;
  left: 40px;
  height: 48px;
  color: #fff;
  border: 0;
  border-radius: 8px;
  background: var(--accent);
  font-size: 14px;
  font-weight: 700;
}

.dismiss-button:hover {
  background: var(--accent-hover);
}

@keyframes oauth-spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
