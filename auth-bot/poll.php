<?php
/**
 * Telegram cannot webhook into REG.RU (connection timed out).
 * Paper pokes this URL; we pull updates from api.telegram.org instead.
 */
declare(strict_types=1);
require __DIR__ . "/bot_lib.php";
header("Content-Type: text/plain; charset=utf-8");

$lock = fopen(__DIR__ . "/poll.lock", "c");
if ($lock === false || !flock($lock, LOCK_EX | LOCK_NB)) {
    echo "busy";
    exit;
}

try {
    $env = load_env(__DIR__ . "/.env");
} catch (Throwable $err) {
    flock($lock, LOCK_UN);
    fclose($lock);
    http_response_code(500);
    echo "env";
    exit;
}

$secret = $env["CLAIM_SECRET"] ?? "";
$got = (string) ($_GET["secret"] ?? ($_SERVER["HTTP_X_AUTH_SECRET"] ?? ""));
if ($secret === "" || $got === "" || !hash_equals($secret, $got)) {
    flock($lock, LOCK_UN);
    fclose($lock);
    http_response_code(403);
    echo "forbidden";
    exit;
}

$token = $env["TELEGRAM_BOT_TOKEN"] ?? "";
if ($token === "") {
    flock($lock, LOCK_UN);
    fclose($lock);
    http_response_code(500);
    echo "token";
    exit;
}

$offsetFile = __DIR__ . "/offset.json";
$offset = 0;
if (is_readable($offsetFile)) {
    $saved = json_decode((string) file_get_contents($offsetFile), true);
    if (is_array($saved) && isset($saved["offset"])) {
        $offset = (int) $saved["offset"];
    }
}

$data = telegram($token, "getUpdates", [
    "offset" => $offset,
    "timeout" => 0,
    "limit" => 20,
    "allowed_updates" => ["message"],
]);
if (empty($data["ok"]) || !isset($data["result"]) || !is_array($data["result"])) {
    flock($lock, LOCK_UN);
    fclose($lock);
    echo "tg";
    exit;
}

$next = $offset;
foreach ($data["result"] as $update) {
    if (!is_array($update)) {
        continue;
    }
    $next = max($next, ((int) ($update["update_id"] ?? 0)) + 1);
}
file_put_contents($offsetFile, json_encode(["offset" => $next]), LOCK_EX);

$seen = [];
foreach ($data["result"] as $update) {
    if (!is_array($update) || !isset($update["message"]) || !is_array($update["message"])) {
        continue;
    }
    $message = $update["message"];
    $chatId = (int) ($message["chat"]["id"] ?? 0);
    $text = trim((string) ($message["text"] ?? ""));
    $key = $chatId . "\0" . $text;
    if ($key === "0\0" || isset($seen[$key])) {
        continue;
    }
    $seen[$key] = true;
    handle_message($env, $message);
}

flock($lock, LOCK_UN);
fclose($lock);
echo "ok " . count($seen);
