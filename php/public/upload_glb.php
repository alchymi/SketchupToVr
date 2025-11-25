<?php
declare(strict_types=1);

require_once __DIR__ . '/src/helpers.php';

handle_cors();

// ------------------------------------------------------------
// Récupération des Public Keys (depuis Docker)
// ------------------------------------------------------------
$publicKeys = array_filter(array_map('trim', explode(',', getenv('PUBLIC_KEYS') ?: '')));

if (empty($publicKeys)) {
    json_response(500, "Configuration invalide : aucune PUBLIC_KEY.");
}

// ------------------------------------------------------------
// Headers HMAC envoyés par le plugin SketchUp
// ------------------------------------------------------------
$pubKey    = $_SERVER['HTTP_X_API_KEY']       ?? null;
$timestamp = $_SERVER['HTTP_X_API_TIMESTAMP'] ?? null;
$signature = $_SERVER['HTTP_X_API_SIGNATURE'] ?? null;

if (!$pubKey || !$timestamp || !$signature) {
    json_response(400, "Headers HMAC manquants.");
}

if (!in_array($pubKey, $publicKeys)) {
    json_response(403, "Clé API inconnue.");
}

// ------------------------------------------------------------
// Récupération du SECRET lié à cette clé publique
// ------------------------------------------------------------
$secretKey = getenv("SECRET_" . $pubKey);

if (!$secretKey) {
    json_response(500, "Secret introuvable pour la clé $pubKey.");
}

// Anti-replay : timestamp max 60s
if (abs(time() - (int)$timestamp) > 600) {
    json_response(403, "Timestamp expiré.");
}

// ------------------------------------------------------------
// Vérification du fichier (obligatoire avant HMAC)
// ------------------------------------------------------------
if (!isset($_FILES['file'])) {
    json_response(400, "Fichier manquant.");
}

$fileTmp = $_FILES['file']['tmp_name'];
$fileHash = hash_file("sha256", $fileTmp);

// ------------------------------------------------------------
// Vérification HMAC SHA256
// payload = timestamp:code:filehash
// ------------------------------------------------------------
$code = $_POST['code'] ?? "";
if (!$code || !preg_match('/^[A-Z0-9]{4}$/', $code)) {
    $code = generate_code(4);
    $codeGeneratedServerSide = true;
} else {
    $codeGeneratedServerSide = false;
}

$payload  = "{$timestamp}:{$code}:{$fileHash}";
$expected = hash_hmac("sha256", $payload, $secretKey);

if (!hash_equals($expected, $signature)) {
    json_response(403, "Signature HMAC invalide.");
}

// ------------------------------------------------------------
// Gestion upload final
// ------------------------------------------------------------
ensure_upload_dir();

$timestampName = date('Ymd_His');
$finalFilename = $code . '_' . $timestampName . '.glb';
$finalPath     = UPLOAD_DIR . '/' . $finalFilename;

if (!move_uploaded_file($fileTmp, $finalPath)) {
    json_response(500, "Échec sauvegarde fichier.");
}

$fileUrl = rtrim(base_public_url(), '/') . '/' . $finalFilename;

// ------------------------------------------------------------
// Mise à jour manifest
// ------------------------------------------------------------
$manifest = load_manifest();

$entry = [
    'code'        => $code,
    'file_name'   => $finalFilename,
    'file_url'    => $fileUrl,
    'size_bytes'  => $_FILES['file']['size'],
    'uploaded_at' => date('c'),
    'filter'      => substr($pubKey, 0, 3)
];

if ($codeGeneratedServerSide) {
    $entry['server_generated_code'] = true;
}

$manifest[] = $entry;
save_manifest($manifest);

// ------------------------------------------------------------
json_response(200, "Upload réussi.", $entry);


// -------------------------------------------------------------------------
// AUTO-CLEAN : supprimer les fichiers de plus de 7 jours + nettoyer manifest
// -------------------------------------------------------------------------
function clean_old_files(int $days = 7): void
{
    $manifest = load_manifest();
    $changed = false;

    $cutoff = time() - ($days * 86400); // 7 jours

    foreach ($manifest as $index => $entry) {

        if (!isset($entry['uploaded_at'])) continue;

        $uploadedTs = strtotime($entry['uploaded_at']);
        if ($uploadedTs === false) continue;

        if ($uploadedTs < $cutoff) {

            // Fichier à supprimer
            $filePath = UPLOAD_DIR . '/' . $entry['file_name'];

            if (file_exists($filePath)) {
                @unlink($filePath);
            }

            // On supprime aussi du manifest
            unset($manifest[$index]);
            $changed = true;
        }
    }

    // Réindexation + sauvegarde du manifest si modifié
    if ($changed) {
        $manifest = array_values($manifest);
        save_manifest($manifest);
    }
}