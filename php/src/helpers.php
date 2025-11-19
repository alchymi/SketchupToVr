<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

/**
 * Réponse JSON uniforme.
 */
function json_response(int $status, string $message, array $data = []): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');

    echo json_encode([
        'success' => $status >= 200 && $status < 300,
        'message' => $message,
        'data'    => $data,
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

    exit;
}

/**
 * Gère basiquement le CORS (utile si tu appelles depuis Unity WebGL plus tard).
 */
function handle_cors(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

/**
 * S'assure que le dossier d'upload existe.
 */
function ensure_upload_dir(): void {
    if (!is_dir(UPLOAD_DIR)) {
        if (!mkdir(UPLOAD_DIR, 0775, true) && !is_dir(UPLOAD_DIR)) {
            json_response(500, 'Impossible de créer le dossier de stockage.');
        }
    }
}

/**
 * Charge le manifest JSON, renvoie un tableau.
 */
function load_manifest(): array {
    if (!file_exists(MANIFEST_FILE)) {
        return [];
    }

    $json = file_get_contents(MANIFEST_FILE);
    if ($json === false || trim($json) === '') {
        return [];
    }

    $data = json_decode($json, true);
    if (!is_array($data)) {
        return [];
    }

    return $data;
}

/**
 * Sauvegarde le manifest JSON.
 */
function save_manifest(array $data): void {
    $json = json_encode(
        $data,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
    );

    file_put_contents(MANIFEST_FILE, $json);
}

/**
 * Génère un code court type "XA1B".
 */
function generate_code(int $length = 4): string {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    $out   = '';
    $max   = strlen($chars) - 1;

    for ($i = 0; $i < $length; $i++) {
        $out .= $chars[random_int(0, $max)];
    }

    return $out;
}
