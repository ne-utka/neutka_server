<?php
/**
 * Launcher nickname login: start a Telegram code, then poll until the bot confirms it.
 */
declare(strict_types=1);

require __DIR__ . "/bot_lib.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=utf-8");

if (($_SERVER["REQUEST_METHOD"] ?? "") === "OPTIONS") {
    http_response_code(204);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") === "GET") {
    $nick = trim((string) ($_GET["nick"] ?? ""));
    if ($nick !== "") {
        if (!preg_match("/^[A-Za-z0-9_]{3,16}$/", $nick)) {
            http_response_code(400);
            echo json_encode(["ok" => false, "error" => "bad_nick"], JSON_UNESCAPED_UNICODE);
            exit;
        }
        $bound = bound_player($nick);
        if ($bound === null) {
            echo json_encode(["ok" => false, "error" => "not_bound"], JSON_UNESCAPED_UNICODE);
            exit;
        }
        echo json_encode([
            "ok" => true,
            "nick" => (string) ($bound["nick"] ?? $nick),
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
    $code = (string) ($_GET["code"] ?? "");
    echo json_encode(login_code_status($code), JSON_UNESCAPED_UNICODE);
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
    http_response_code(405);
    echo json_encode(["ok" => false, "error" => "method"], JSON_UNESCAPED_UNICODE);
    exit;
}

$raw = (string) file_get_contents("php://input");
$body = json_decode($raw, true);
if (!is_array($body)) {
    $body = $_POST;
}
$nick = trim((string) ($body["nick"] ?? ""));
if (!preg_match("/^[A-Za-z0-9_]{3,16}$/", $nick)) {
    http_response_code(400);
    echo json_encode(["ok" => false, "error" => "bad_nick"], JSON_UNESCAPED_UNICODE);
    exit;
}

$created = create_login_code($nick);
if ($created === null) {
    echo json_encode(["ok" => false, "error" => "not_bound"], JSON_UNESCAPED_UNICODE);
    exit;
}

$code = (string) $created["code"];
echo json_encode([
    "ok" => true,
    "code" => $code,
    "user_code" => substr($code, 0, 3) . " " . substr($code, 3, 3),
    "nick" => (string) $created["nick"],
    "expires_in" => (int) $created["expires_in"],
], JSON_UNESCAPED_UNICODE);
