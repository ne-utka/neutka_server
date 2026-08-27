const fs = require("fs");
const https = require("https");
const net = require("net");
const path = require("path");

function loadEnv(filePath) {
  const env = {};
  if (!fs.existsSync(filePath)) {
    throw new Error("Missing .env next to bot.js");
  }
  for (const line of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }
    const eq = trimmed.indexOf("=");
    if (eq < 1) {
      continue;
    }
    env[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
  }
  return env;
}

const env = loadEnv(path.join(__dirname, ".env"));
const TOKEN = env.TELEGRAM_BOT_TOKEN;
const RCON_HOST = env.RCON_HOST || "5.129.240.121";
const RCON_PORT = Number(env.RCON_PORT || 25575);
const RCON_PASSWORD = env.RCON_PASSWORD || "";
const LP_GROUP = env.LP_GROUP || "игрок";
const AUTH_DURATION = env.AUTH_DURATION || "30d";
const NAME_RE = /^[A-Za-z0-9_]{3,16}$/;

if (!TOKEN) {
  throw new Error("TELEGRAM_BOT_TOKEN is empty");
}
if (!RCON_PASSWORD) {
  throw new Error("RCON_PASSWORD is empty");
}

function telegram(method, payload) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const req = https.request(
      {
        hostname: "api.telegram.org",
        path: `/bot${TOKEN}/${method}`,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
          } catch (err) {
            reject(err);
          }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function send(chatId, text) {
  return telegram("sendMessage", { chat_id: chatId, text });
}

function rcon(command) {
  return new Promise((resolve, reject) => {
    const socket = net.connect({ host: RCON_HOST, port: RCON_PORT });
    let buffer = Buffer.alloc(0);
    let nextId = 1;
    const pending = new Map();

    function packet(type, payload) {
      const id = nextId++;
      const body = Buffer.from(payload, "utf8");
      const buf = Buffer.alloc(14 + body.length);
      buf.writeInt32LE(10 + body.length, 0);
      buf.writeInt32LE(id, 4);
      buf.writeInt32LE(type, 8);
      body.copy(buf, 12);
      socket.write(buf);
      return id;
    }

    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error("RCON timeout"));
    }, 8000);

    socket.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    socket.on("connect", () => {
      const id = packet(3, RCON_PASSWORD);
      pending.set(id, { kind: "auth" });
    });
    socket.on("data", (data) => {
      buffer = Buffer.concat([buffer, data]);
      while (buffer.length >= 4) {
        const size = buffer.readInt32LE(0);
        if (buffer.length < 4 + size) {
          return;
        }
        const id = buffer.readInt32LE(4);
        const type = buffer.readInt32LE(8);
        const payload = buffer.slice(12, 4 + size - 2).toString("utf8");
        buffer = buffer.slice(4 + size);
        if (id === -1) {
          clearTimeout(timer);
          socket.destroy();
          reject(new Error("RCON auth failed"));
          return;
        }
        const wait = pending.get(id);
        if (!wait) {
          continue;
        }
        pending.delete(id);
        if (wait.kind === "auth") {
          const cmdId = packet(2, command);
          pending.set(cmdId, { kind: "cmd" });
        } else if (wait.kind === "cmd") {
          clearTimeout(timer);
          socket.end();
          resolve((payload || "").trim());
        }
      }
    });
  });
}

async function authPlayer(name) {
  const quoted = LP_GROUP.includes(" ") ? `"${LP_GROUP}"` : LP_GROUP;
  const command = `lp user ${name} parent addtemp ${quoted} ${AUTH_DURATION}`;
  const response = await rcon(command);
  return response;
}

const START_TEXT =
  "SpringRP — доступ на сервер.\n\n" +
  "Привяжи игровой ник командой:\n" +
  "/auth Ник\n\n" +
  "После успешной привязки можно заходить через лаунчер.\n" +
  "Роль «игрок» действует 30 дней. Когда срок кончится — напиши /auth снова.";

const USAGE_TEXT =
  "Напиши так:\n" +
  "/auth Ник\n\n" +
  "Ник как в Minecraft: 3–16 символов, латиница, цифры и _.\n" +
  "Пример: /auth Steve";

function cmdName(text) {
  const first = (text.split(/\s+/)[0] || "").toLowerCase();
  const at = first.indexOf("@");
  return at >= 0 ? first.slice(0, at) : first;
}

async function handleMessage(message) {
  const chatId = message.chat && message.chat.id;
  const text = (message.text || "").trim();
  if (!chatId || !text) {
    return;
  }
  const cmd = cmdName(text);
  if (cmd === "/start" || cmd === "/help") {
    await send(chatId, START_TEXT);
    return;
  }
  if (cmd !== "/auth") {
    await send(chatId, "Я понимаю только /auth Ник.\n\n" + USAGE_TEXT);
    return;
  }
  const match = text.match(/^\/auth(?:@\w+)?(?:\s+(.+))?$/i);
  const name = ((match && match[1]) || "").trim();
  if (!NAME_RE.test(name)) {
    await send(chatId, USAGE_TEXT);
    return;
  }
  try {
    await authPlayer(name);
    await send(
      chatId,
      `Готово. Ник ${name} привязан.\n\nРоль «игрок» выдана на 30 дней — сервер пустит.\nЕсли выкинет по сроку, напиши /auth ${name} ещё раз.`
    );
  } catch (err) {
    await send(chatId, "Не получилось привязать ник. Попробуй ещё раз через минуту.");
  }
}

async function poll(offset) {
  const data = await telegram("getUpdates", {
    offset,
    timeout: 50,
    allowed_updates: ["message"],
  });
  let next = offset;
  if (data.ok && Array.isArray(data.result)) {
    for (const update of data.result) {
      next = update.update_id + 1;
      if (update.message) {
        try {
          await handleMessage(update.message);
        } catch (err) {
          console.error(err);
        }
      }
    }
  }
  return next;
}

async function main() {
  console.log(`Auth bot polling as long-running process, RCON ${RCON_HOST}:${RCON_PORT}`);
  let offset = 0;
  for (;;) {
    try {
      offset = await poll(offset);
    } catch (err) {
      console.error(err.message || err);
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }
}

main();
