<?php
/**
 * Shared SpringRP Telegram /auth helpers.
 */
declare(strict_types=1);

function load_env(string $path): array
{
    if (!is_readable($path)) {
        throw new RuntimeException("missing env");
    }
    $env = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES) as $line) {
        $line = trim($line);
        if ($line === "" || $line[0] === "#") {
            continue;
        }
        $eq = strpos($line, "=");
        if ($eq === false || $eq < 1) {
            continue;
        }
        $env[trim(substr($line, 0, $eq))] = trim(substr($line, $eq + 1));
    }
    return $env;
}

function telegram(string $token, string $method, array $payload): array
{
    $url = "https://api.telegram.org/bot{$token}/{$method}";
    $body = json_encode($payload, JSON_UNESCAPED_UNICODE);
    $raw = "";
    if (function_exists("curl_init")) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => ["Content-Type: application/json"],
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 20,
        ]);
        $raw = (string) curl_exec($ch);
        curl_close($ch);
    } else {
        $ctx = stream_context_create([
            "http" => [
                "method" => "POST",
                "header" => "Content-Type: application/json\r\nContent-Length: " . strlen($body) . "\r\n",
                "content" => $body,
                "timeout" => 20,
                "ignore_errors" => true,
            ],
        ]);
        $raw = (string) @file_get_contents($url, false, $ctx);
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function send(string $token, int $chatId, string $text): void
{
    $res = telegram($token, "sendMessage", ["chat_id" => $chatId, "text" => $text]);
    if (empty($res["ok"])) {
        @file_put_contents(__DIR__ . "/bot.log", date("c") . " sendMessage failed\n", FILE_APPEND);
    }
}

function cmd_name(string $text): string
{
    $parts = preg_split("/\s+/", trim($text), 2);
    $first = strtolower((string) ($parts[0] ?? ""));
    $at = strpos($first, "@");
    if ($at !== false) {
        $first = substr($first, 0, $at);
    }
    return $first;
}

function start_text(): string
{
    return "SpringRP — доступ на сервер.\n\n"
        . "1) Привяжи ник: /auth Ник\n"
        . "2) В лаунчере нажми «Продолжить» — появится код.\n"
        . "3) Пришли этот код сюда, чтобы войти.\n\n"
        . "Роль «игрок» действует 30 дней.";
}

function usage_text(): string
{
    return "Напиши так:\n"
        . "/auth Ник\n\n"
        . "Ник как в Minecraft: 3–16 символов, латиница, цифры и _.\n"
        . "Если в лаунчере уже есть код — просто пришли его сюда.";
}

function success_text(string $name): string
{
    return "Готово. Ник {$name} привязан.\n\n"
        . "Роль «игрок» выдана на 30 дней.\n"
        . "Теперь в лаунчере введи этот ник и нажми «Продолжить» — пришли сюда код с экрана.";
}

function queued_text(string $name): string
{
    return "Ник {$name} принят.\n\n"
        . "Роль «игрок» выдастся в течение нескольких секунд.\n"
        . "В лаунчере введи этот ник и пришли сюда код с экрана.";
}

function with_json_file(string $file, callable $mutator)
{
    $fp = fopen($file, "c+");
    if ($fp === false) {
        throw new RuntimeException("json file unavailable");
    }
    flock($fp, LOCK_EX);
    $raw = stream_get_contents($fp);
    $data = json_decode((string) $raw, true);
    if (!is_array($data)) {
        $data = [];
    }
    $result = call_user_func_array($mutator, [&$data]);
    rewind($fp);
    ftruncate($fp, 0);
    fwrite($fp, json_encode($data, JSON_UNESCAPED_UNICODE));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
    return $result;
}

function bind_player(string $name, int $chatId): void
{
    $key = strtolower($name);
    with_json_file(__DIR__ . "/bound.json", function (&$data) use ($key, $name, $chatId) {
        $data[$key] = ["nick" => $name, "chat_id" => $chatId, "ts" => time()];
        return true;
    });
}

function bound_player(string $name): ?array
{
    $key = strtolower($name);
    return with_json_file(__DIR__ . "/bound.json", function (&$data) use ($key) {
        $row = $data[$key] ?? null;
        return is_array($row) ? $row : null;
    });
}

function create_login_code(string $name): ?array
{
    $bound = bound_player($name);
    if ($bound === null) {
        return null;
    }
    $nick = (string) ($bound["nick"] ?? $name);
    $chatId = (int) ($bound["chat_id"] ?? 0);
    $expires = time() + 300;
    $code = with_json_file(__DIR__ . "/codes.json", function (&$data) use ($nick, $chatId, $expires) {
        foreach ($data as $existing => $row) {
            if (is_array($row) && strcasecmp((string) ($row["nick"] ?? ""), $nick) === 0) {
                unset($data[$existing]);
            }
        }
        do {
            $next = (string) random_int(100000, 999999);
        } while (isset($data[$next]));
        $data[$next] = [
            "nick" => $nick,
            "chat_id" => $chatId,
            "exp" => $expires,
            "verified" => false,
        ];
        return $next;
    });
    return ["code" => $code, "nick" => $nick, "expires_in" => 300];
}

function login_code_status(string $code): array
{
    $code = preg_replace("/\D+/", "", $code);
    if (!preg_match("/^\d{6}$/", $code)) {
        return ["status" => "missing"];
    }
    return with_json_file(__DIR__ . "/codes.json", function (&$data) use ($code) {
        $row = $data[$code] ?? null;
        if (!is_array($row)) {
            return ["status" => "missing"];
        }
        if ((int) ($row["exp"] ?? 0) < time()) {
            unset($data[$code]);
            return ["status" => "expired"];
        }
        if (!empty($row["verified"])) {
            return ["status" => "verified", "nick" => (string) ($row["nick"] ?? "")];
        }
        return ["status" => "pending"];
    });
}

function confirm_login_code(string $raw, int $chatId): string
{
    $code = preg_replace("/\D+/", "", $raw);
    if (!preg_match("/^\d{6}$/", $code)) {
        return "missing";
    }
    return with_json_file(__DIR__ . "/codes.json", function (&$data) use ($code, $chatId) {
        $row = $data[$code] ?? null;
        if (!is_array($row)) {
            return "missing";
        }
        if ((int) ($row["exp"] ?? 0) < time()) {
            unset($data[$code]);
            return "expired";
        }
        $owner = (int) ($row["chat_id"] ?? 0);
        if ($owner > 0 && $owner !== $chatId) {
            return "wrong_chat";
        }
        $data[$code]["verified"] = true;
        return "ok:" . (string) ($row["nick"] ?? "");
    });
}

function enqueue_auth(string $name): void
{
    $file = __DIR__ . "/pending.json";
    $fp = fopen($file, "c+");
    if ($fp === false) {
        throw new RuntimeException("queue file unavailable");
    }
    flock($fp, LOCK_EX);
    $raw = stream_get_contents($fp);
    $list = json_decode((string) $raw, true);
    if (!is_array($list)) {
        $list = [];
    }
    foreach ($list as $row) {
        if (isset($row["name"]) && strcasecmp((string) $row["name"], $name) === 0) {
            flock($fp, LOCK_UN);
            fclose($fp);
            return;
        }
    }
    $list[] = ["name" => $name, "ts" => time()];
    rewind($fp);
    ftruncate($fp, 0);
    fwrite($fp, json_encode($list, JSON_UNESCAPED_UNICODE));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
}

function rcon_packet(int $id, int $type, string $payload): string
{
    $body = pack("VVa*xx", $id, $type, $payload);
    return pack("V", strlen($body)) . $body;
}

function rcon_read($fp): array
{
    $lenRaw = fread($fp, 4);
    if ($lenRaw === false || strlen($lenRaw) < 4) {
        throw new RuntimeException("RCON: empty response");
    }
    $len = unpack("V", $lenRaw)[1];
    if ($len < 10 || $len > 65535) {
        throw new RuntimeException("RCON: bad packet length");
    }
    $data = "";
    while (strlen($data) < $len) {
        $chunk = fread($fp, $len - strlen($data));
        if ($chunk === false || $chunk === "") {
            throw new RuntimeException("RCON: truncated packet");
        }
        $data .= $chunk;
    }
    $id = unpack("V", substr($data, 0, 4))[1];
    $type = unpack("V", substr($data, 4, 4))[1];
    if ($id >= 0x80000000) {
        $id -= 0x100000000;
    }
    $body = substr($data, 8, $len - 10);
    return [$id, $type, $body];
}

function rcon(string $host, int $port, string $password, string $command): string
{
    $errno = 0;
    $errstr = "";
    $fp = @fsockopen($host, $port, $errno, $errstr, 3);
    if ($fp === false) {
        throw new RuntimeException("RCON connect failed: {$errstr}");
    }
    stream_set_timeout($fp, 3);
    fwrite($fp, rcon_packet(1, 3, $password));
    [$id] = rcon_read($fp);
    if ($id === -1) {
        fclose($fp);
        throw new RuntimeException("RCON auth failed");
    }
    fwrite($fp, rcon_packet(2, 2, $command));
    [, , $payload] = rcon_read($fp);
    fclose($fp);
    return trim((string) $payload);
}

function handle_message(array $env, array $message): void
{
    $token = $env["TELEGRAM_BOT_TOKEN"] ?? "";
    $rconHost = $env["RCON_HOST"] ?? "5.129.240.121";
    $rconPort = (int) ($env["RCON_PORT"] ?? 25575);
    $rconPassword = $env["RCON_PASSWORD"] ?? "";
    $lpGroup = $env["LP_GROUP"] ?? "игрок";
    $authDuration = $env["AUTH_DURATION"] ?? "30d";

    $chatId = (int) ($message["chat"]["id"] ?? 0);
    $text = trim((string) ($message["text"] ?? ""));
    if ($chatId < 1 || $text === "" || $token === "") {
        return;
    }

    try {
        $cmd = cmd_name($text);
        if ($cmd === "/start" || $cmd === "/help") {
            send($token, $chatId, start_text());
            return;
        }

        $digits = preg_replace("/\D+/", "", $text);
        if (preg_match("/^\d{6}$/", $digits) && !str_starts_with($text, "/")) {
            $result = confirm_login_code($digits, $chatId);
            if (str_starts_with($result, "ok:")) {
                $nick = substr($result, 3);
                send($token, $chatId, "Лаунчер подтверждён. Ник {$nick} — можно нажимать «Играть».");
                return;
            }
            if ($result === "expired") {
                send($token, $chatId, "Этот код уже истёк. Нажми «Продолжить» в лаунчере ещё раз.");
                return;
            }
            if ($result === "wrong_chat") {
                send($token, $chatId, "Этот код для другого Telegram. Пиши с аккаунта, которым делал /auth.");
                return;
            }
            send($token, $chatId, "Нет такого кода. Нажми «Продолжить» в лаунчере ещё раз и пришли новый.");
            return;
        }

        if ($cmd !== "/auth") {
            send($token, $chatId, "Я понимаю /auth Ник и код из лаунчера.\n\n" . usage_text());
            return;
        }

        $name = "";
        if (preg_match("/^\\/auth(?:@\\w+)?(?:\\s+(.+))?$/iu", $text, $match)) {
            $name = trim((string) ($match[1] ?? ""));
        }
        if (!preg_match("/^[A-Za-z0-9_]{3,16}$/", $name)) {
            send($token, $chatId, usage_text());
            return;
        }

        $quoted = strpos($lpGroup, " ") !== false ? "\"{$lpGroup}\"" : $lpGroup;
        try {
            rcon($rconHost, $rconPort, $rconPassword, "lp user {$name} parent addtemp {$quoted} {$authDuration}");
            bind_player($name, $chatId);
            send($token, $chatId, success_text($name));
        } catch (Throwable $rconErr) {
            enqueue_auth($name);
            bind_player($name, $chatId);
            send($token, $chatId, queued_text($name));
        }
    } catch (Throwable $err) {
        send($token, $chatId, "Не получилось привязать ник. Попробуй ещё раз через минуту.");
    }
}
