<?php
declare(strict_types=1);

require_once __DIR__ . '/src/helpers.php';

handle_cors();

// ---------------------------------------------------------
// Charger les API Keys autorisées
// ---------------------------------------------------------
$rawKeys = getenv('API_KEYS') ?: '';
$apiKeys = array_filter(array_map('trim', explode(',', $rawKeys)));

if (empty($apiKeys)) {
    json_response(500, "Configuration invalide : aucune API key définie.");
}

// ---------------------------------------------------------
// Vérification de la clé envoyée
// ---------------------------------------------------------
$providedKey = $_SERVER['HTTP_X_API_KEY'] ?? null;

if (!$providedKey || !in_array($providedKey, $apiKeys, true)) {
    json_response(403, "API Key invalide.");
}

$apiFilter = substr($providedKey, 0, 3);

// ---------------------------------------------------------
ensure_upload_dir();

// ----- CODE -----
if (!isset($_POST['code']) || !preg_match('/^[A-Z0-9]{4}$/', $_POST['code'])) {
    $code = generate_code(4);
    $codeGeneratedServerSide = true;
} else {
    $code = strtoupper($_POST['code']);
    $codeGeneratedServerSide = false;
}

// ----- FICHIER -----
if (!isset($_FILES['file'])) {
    json_response(400, 'Fichier manquant.');
}

$file = $_FILES['file'];

if ($file['error'] !== UPLOAD_ERR_OK) {
    json_response(400, 'Erreur upload (code ' . $file['error'] . ').');
}

if ($file['size'] <= 0) {
    json_response(400, 'Fichier vide.');
}

$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if ($ext !== 'glb') {
    json_response(400, 'Seuls les fichiers .glb sont acceptés.');
}

$timestampName = date('Ymd_His');
$finalFilename = $code . '_' . $timestampName . '.glb';
$finalPath     = UPLOAD_DIR . '/' . $finalFilename;

if (!move_uploaded_file($file['tmp_name'], $finalPath)) {
    json_response(500, 'Impossible de sauvegarder le fichier.');
}

$fileUrl = rtrim(base_public_url(), '/') . '/' . $finalFilename;

// ----- MANIFEST -----
$manifest = load_manifest();

$entry = [
    'code'        => $code,
    'file_name'   => $finalFilename,
    'file_url'    => $fileUrl,
    'size_bytes'  => $file['size'],
    'uploaded_at' => date('c'),
    'filter'      => $apiFilter
];

if ($codeGeneratedServerSide) {
    $entry['server_generated_code'] = true;
}

$manifest[] = $entry;
save_manifest($manifest);

// ----- NETTOYAGE AUTO (7 jours) -----
clean_old_files(7);

// ---------------------------------------------------------
json_response(200, "Upload réussi.", $entry);


// =====================================================================
// SUPPRESSION AUTOMATIQUE DES FICHIERS > X jours
// =====================================================================
function clean_old_files(int $days = 7): void
{
    $manifest = load_manifest();
    $changed = false;

    $cutoff = time() - ($days * 86400);

    foreach ($manifest as $index => $entry) {

        if (!isset($entry['uploaded_at'])) continue;

        $ts = strtotime($entry['uploaded_at']);
        if ($ts === false) continue;

        if ($ts < $cutoff) {

            $path = UPLOAD_DIR . '/' . $entry['file_name'];
            if (file_exists($path)) {
                @unlink($path);
            }

            unset($manifest[$index]);
            $changed = true;
        }
    }

    if ($changed) {
        $manifest = array_values($manifest);
        save_manifest($manifest);
    }
}
