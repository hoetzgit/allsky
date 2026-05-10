<?php
if (basename(__FILE__) === basename($_SERVER['SCRIPT_FILENAME'])) {
    include_once('functions.php');
    redirect("/index.php");
}

class RememberMe
{
    private const COOKIE = 'allsky_remember';
    private const TTL = 2592000; // 30 days

    private static function storeFile(): string
    {
        return rtrim((string)ALLSKY_MYFILES_DIR, '/\\') . '/remember_tokens.json';
    }

    private static function cookieOptions(int $expires): array
    {
        $secureCookie = (
            isset($_SERVER['HTTPS']) &&
            $_SERVER['HTTPS'] !== '' &&
            $_SERVER['HTTPS'] !== 'off'
        );

        return [
            'expires' => $expires,
            'path' => '/',
            'secure' => $secureCookie,
            'httponly' => true,
            'samesite' => 'Lax',
        ];
    }

    private static function readTokens(): array
    {
        $file = self::storeFile();
        if (!is_file($file)) {
            return [];
        }

        $raw = @file_get_contents($file);
        if ($raw === false || trim($raw) === '') {
            return [];
        }

        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : [];
    }

    private static function writeTokens(array $tokens): bool
    {
        $file = self::storeFile();
        $encoded = json_encode(array_values($tokens), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if ($encoded === false) {
            return false;
        }

        $ok = @file_put_contents($file, $encoded, LOCK_EX);
        if ($ok === false) {
            $msg = updateFile($file, $encoded, 'remember tokens', false, true);
            if ($msg !== '') {
                return false;
            }
        }

        @chmod($file, 0600);
        return true;
    }

    private static function pruneTokens(array $tokens, ?string $username = null): array
    {
        $now = time();
        $kept = [];

        foreach ($tokens as $entry) {
            if (!is_array($entry)) {
                continue;
            }
            if ((int)($entry['expires'] ?? 0) <= $now) {
                continue;
            }
            if ($username !== null && (string)($entry['username'] ?? '') === $username) {
                continue;
            }
            $kept[] = $entry;
        }

        return $kept;
    }

    public static function clearCookie(): void
    {
        $expired = time() - 3600;
        setcookie(self::COOKIE, '', self::cookieOptions($expired));
        setcookie('allsky_remember_username', '', self::cookieOptions($expired));
        setcookie('allsky_remember_password', '', self::cookieOptions($expired));
    }

    public static function issueToken(string $username): void
    {
        $selector = bin2hex(random_bytes(12));
        $token = bin2hex(random_bytes(32));
        $expires = time() + self::TTL;

        $tokens = self::pruneTokens(self::readTokens());
        $tokens[] = [
            'selector' => $selector,
            'token_hash' => hash('sha256', $token),
            'username' => $username,
            'created' => time(),
            'expires' => $expires,
        ];

        if (self::writeTokens($tokens)) {
            setcookie(self::COOKIE, $selector . ':' . $token, self::cookieOptions($expires));
            setcookie('allsky_remember_username', '', self::cookieOptions(time() - 3600));
            setcookie('allsky_remember_password', '', self::cookieOptions(time() - 3600));
        }
    }

    public static function loginFromCookie(string $currentUsername): bool
    {
        $cookie = (string)($_COOKIE[self::COOKIE] ?? '');
        if ($cookie === '' || strlen($cookie) > 256 || strpos($cookie, ':') === false) {
            return false;
        }

        [$selector, $token] = explode(':', $cookie, 2);
        if (!preg_match('/^[a-f0-9]{24}$/', $selector) || !preg_match('/^[a-f0-9]{64}$/', $token)) {
            self::clearCookie();
            return false;
        }

        $tokens = self::pruneTokens(self::readTokens());
        $matched = null;
        $remaining = [];

        foreach ($tokens as $entry) {
            if ((string)($entry['selector'] ?? '') === $selector) {
                $matched = $entry;
                continue;
            }
            $remaining[] = $entry;
        }

        if ($matched === null || (string)($matched['username'] ?? '') !== $currentUsername) {
            self::writeTokens($remaining);
            self::clearCookie();
            return false;
        }

        $expected = (string)($matched['token_hash'] ?? '');
        if (!hash_equals($expected, hash('sha256', $token))) {
            self::writeTokens($remaining);
            self::clearCookie();
            return false;
        }

        self::writeTokens($remaining);
        self::issueToken($currentUsername);
        return true;
    }

    public static function revokeAll(?string $username = null): void
    {
        $tokens = self::readTokens();
        if ($username === null) {
            $tokens = [];
        } else {
            $tokens = self::pruneTokens($tokens, $username);
        }

        self::writeTokens($tokens);
        self::clearCookie();
    }
}
