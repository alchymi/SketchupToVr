<?php
declare(strict_types=1);

require_once __DIR__ . '/src/helpers.php';
handle_cors();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(405, 'Méthode non autorisée, utilise GET.');
}

ensure_upload_dir(); // au cas où

$files = load_manifest();

// Tri du plus récent au plus ancien
usort($files, function (array $a, array $b) {
    $ta = isset($a['uploaded_at']) ? strtotime($a['uploaded_at']) : 0;
    $tb = isset($b['uploaded_at']) ? strtotime($b['uploaded_at']) : 0;
    return $tb <=> $ta;
});

json_response(200, 'Liste des fichiers.', [
    'files' => $files,
]);
