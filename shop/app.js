const modal = document.querySelector("#nickname-modal");
const buyButtons = document.querySelectorAll(".buy-button");
const closeButton = document.querySelector("#modal-close");
const form = document.querySelector("#nickname-form");
const nicknameInput = document.querySelector("#nickname");
const nicknameHint = document.querySelector("#nickname-hint");
const toast = document.querySelector("#toast");

const nicknamePattern = /^[A-Za-z0-9_]{3,16}$/;
let toastTimer;
let activeProduct = "Проходка";

function openModal(event) {
  activeProduct = event.currentTarget.dataset.product ?? "Проходка";
  modal.hidden = false;
  document.body.style.overflow = "hidden";
  nicknameInput.value = localStorage.getItem("springrp-shop-nickname") ?? "";
  resetValidation();
  requestAnimationFrame(() => nicknameInput.focus());
}

function closeModal() {
  modal.hidden = true;
  document.body.style.overflow = "";
  document.querySelector(`[data-product="${CSS.escape(activeProduct)}"]`)?.focus();
}

function resetValidation() {
  nicknameInput.classList.remove("invalid");
  nicknameHint.classList.remove("error");
  nicknameHint.textContent = "Латиница, цифры и нижнее подчёркивание";
}

function showToast(message) {
  clearTimeout(toastTimer);
  toast.querySelector("span").textContent = message;
  toast.hidden = false;
  toastTimer = setTimeout(() => {
    toast.hidden = true;
  }, 4000);
}

buyButtons.forEach((button) => button.addEventListener("click", openModal));
closeButton.addEventListener("click", closeModal);

modal.addEventListener("click", (event) => {
  if (event.target === modal) closeModal();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !modal.hidden) closeModal();
});

nicknameInput.addEventListener("input", resetValidation);

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const nickname = nicknameInput.value.trim();

  if (!nicknamePattern.test(nickname)) {
    nicknameInput.classList.add("invalid");
    nicknameHint.classList.add("error");
    nicknameHint.textContent = "Введите от 3 до 16 символов латиницей";
    nicknameInput.focus();
    return;
  }

  localStorage.setItem("springrp-shop-nickname", nickname);
  closeModal();
  showToast(`${activeProduct}: ник ${nickname} сохранён. Касса появится позже.`);
});
