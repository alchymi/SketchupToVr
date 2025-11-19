<?php
declare(strict_types=1);

require_once __DIR__ . '/src/helpers.php';

handle_cors();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(405, 'Méthode non autorisée, utilise POST.');
}

ensure_upload_dir();

// ----- RÉCUPÉRATION / GÉNÉRATION DU CODE -----

$code = null;

// POST en priorité
if (isset($_POST['code']) && trim($_POST['code']) !== '') {
    $code = strtoupper(trim($_POST['code']));
}

if ($code === null || !preg_match('/^[A-Z0-9]{4}$/', $code)) {
    // Pas de code valide → on en génère un
    $code = generate_code(4);
}

$codeGeneratedServerSide = !isset($_POST['code']);

// ----- FICHIER -----

if (!isset($_FILES['file'])) {
    json_response(400, 'Fichier manquant (champ "file").');
}

$file = $_FILES['file'];

if ($file['error'] !== UPLOAD_ERR_OK) {
    json_response(400, 'Erreur lors de l’upload du fichier (code '.$file['error'].').');
}

if ($file['size'] <= 0) {
    json_response(400, 'Fichier vide.');
}

if ($file['size'] > MAX_FILE_SIZE) {
    json_response(400, 'Fichier trop volumineux (max '.(MAX_FILE_SIZE / (1024 * 1024)).' Mo).');
}

$originalName = $file['name'];
$extension    = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));

if ($extension !== 'glb') {
    json_response(400, 'Extension invalide. Seuls les fichiers .glb sont acceptés.');
}

// ----- SAUVEGARDE FICHIER -----

$timestamp     = date('Ymd_His');
$finalFilename = $code . '_' . $timestamp . '.glb';
$finalPath     = UPLOAD_DIR . '/' . $finalFilename;

if (!move_uploaded_file($file['tmp_name'], $finalPath)) {
    json_response(500, 'Impossible de sauvegarder le fichier uploadé.');
}

$fileUrl = rtrim(base_public_url(), '/') . '/' . $finalFilename;

// ----- MAJ MANIFEST -----

$manifest = load_manifest();

$entry = [
    'code'        => $code,
    'file_name'   => $finalFilename,
    'file_url'    => $fileUrl,
    'size_bytes'  => $file['size'],
    'uploaded_at' => date('c'),          // ISO 8601
];

if ($codeGeneratedServerSide) {
    $entry['server_generated_code'] = true;
}

$manifest[] = $entry;
save_manifest($manifest);

// ----- RÉPONSE -----

$message = 'Upload réussi.';
if ($codeGeneratedServerSide) {
    $message .= ' (code généré côté serveur)';
}

json_response(200, $message, $entry);
