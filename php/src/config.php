<?php
declare(strict_types=1);

// Racine "publique" (PHP + uploads)
const PUBLIC_ROOT   = __DIR__ . '/..';
const UPLOAD_DIR    = PUBLIC_ROOT . '/uploads_glb';
const MANIFEST_FILE = UPLOAD_DIR . '/manifest.json';

// Limite logique dans le script (PHP.ini reste la vraie limite)
const MAX_FILE_SIZE = 200 * 1024 * 1024; // 200 Mo

/**
 * URL publique de base vers le dossier des GLB.
 * On peut la surcharger avec la variable d'env BASE_PUBLIC_URL.
 */
/**
 * URL publique de base vers le dossier des GLB.
 * On peut la surcharger avec la variable d'env BASE_PUBLIC_URL.
 */
function base_public_url(): string {
    $env = getenv('BASE_PUBLIC_URL');
    if ($env && $env !== '') {
        return rtrim($env, '/');
    }

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host   = $_SERVER['HTTP_HOST'] ?? 'localhost';

    // Par défaut : http(s)://host/uploads_glb
    return $scheme . '://' . $host . '/uploads_glb';
}