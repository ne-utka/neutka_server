<?php
/**
 * Paper/Denizen pulls pending /auth nicks. Shared hosting often cannot open RCON.
 */
declare(strict_types=1);
header("Content-Type: text/plain; charset=utf-8");

function load_env(string $path): array
{
    if (!is_readable($path)) {
        http_response_code(500);
        exit;
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

$env = load_env(__DIR__ . "/.env");
$secret = $env["CLAIM_SECRET"] ?? "";
$got = (string) ($_SERVER["HTTP_X_AUTH_SECRET"] ?? ($_GET["secret"] ?? ""));
if ($secret === "" || !hash_equals($secret, $got)) {
    http_response_code(403);
    exit;
}

$file = __DIR__ . "/pending.json";
$fp = fopen($file, "c+");
if ($fp === false) {
    http_response_code(500);
    exit;
}
flock($fp, LOCK_EX);
$raw = stream_get_contents($fp);
$list = json_decode((string) $raw, true);
if (!is_array($list)) {
    $list = [];
}
rewind($fp);
ftruncate($fp, 0);
fwrite($fp, "[]");
fflush($fp);
flock($fp, LOCK_UN);
fclose($fp);

$names = [];
foreach ($list as $row) {
    $name = is_array($row) ? (string) ($row["name"] ?? "") : "";
    if (preg_match("/^[A-Za-z0-9_]{3,16}$/", $name)) {
        $names[strtolower($name)] = $name;
    }
}
echo implode("\n", array_values($names));
