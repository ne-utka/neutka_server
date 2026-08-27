<?php
require __DIR__ . "/bot_lib.php";
header("Content-Type: application/json; charset=utf-8");

try {
    $env = load_env(__DIR__ . "/.env");
} catch (Throwable $err) {
    http_response_code(500);
    echo json_encode(["ok" => false]);
    exit;
}

$token = $env["TELEGRAM_BOT_TOKEN"] ?? "";
$rconPassword = $env["RCON_PASSWORD"] ?? "";
$webhookSecret = $env["WEBHOOK_SECRET"] ?? "";
if ($token === "" || $rconPassword === "") {
    http_response_code(500);
    echo json_encode(["ok" => false]);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
    echo json_encode(["ok" => true]);
    exit;
}

if ($webhookSecret !== "") {
    $got = (string) ($_GET["k"] ?? ($_SERVER["HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN"] ?? ""));
    if ($got === "" || !hash_equals($webhookSecret, $got)) {
        http_response_code(403);
        echo json_encode(["ok" => false]);
        exit;
    }
}

$update = json_decode((string) file_get_contents("php://input"), true);
$message = is_array($update) ? ($update["message"] ?? null) : null;
if (is_array($message)) {
    handle_message($env, $message);
}
echo json_encode(["ok" => true]);
