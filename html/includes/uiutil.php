<?php
include_once('functions.php');
initialize_variables();
include_once('authenticate.php');
include_once('utilbase.php');

/**
 * UIUTIL
 *
 * Small UI-facing endpoint collection for the dashboard.
 * Renders HTML fragments (progress bars, text) rather than JSON by default.
 *
 * Exposed routes:
 *   GET  AllskyStatus          -> overall system status (preformatted string/HTML)
 *   POST AllskyControl         -> start, stop, or restart the Allsky service
 *   GET  CPULoad               -> CPU load as a bootstrap progress bar
 *   GET  CPUTemp               -> CPU temperature as a progress bar with status color
 *   GET  DayNightStatus        -> current capture mode and transition times
 *   GET  DirectoryBrowserList  -> one directory level for helper directory browsers
 *   GET  ListFileTypeContent   -> reusable image/video listing fragment
 *   GET  MemoryUsed            -> memory usage as a progress bar
 *   GET  ThrottleStatus        -> Raspberry Pi throttle state as a colored bar
 *   GET  Uptime                -> human-readable uptime string
 *   POST Multiple              -> batch several GETs in one JSON request
 *
 * Notes:
 * - This class flips $jsonResponse to false so `sendHTTPResponse()` returns
 *   text/HTML snippets (good for dropping into the DOM).
 * - All user-visible text is escaped; numbers are clamped where appropriate.
 * - The heavy lifting (load/temp/mem/throttle/uptime) comes from helpers
 *   in functions.php.
 */
class UIUTIL extends UTILBASE {

    private bool $returnValues = false;
    
    /**
     * Return the route allow-list used by UTILBASE.
     *
     * Each key is a request name accepted in the `request` query parameter and
     * each value is the list of HTTP verbs that may call that route.  Keeping
     * the allow-list here prevents unrelated public methods from becoming web
     * endpoints by accident.
     *
     * @return array<string,array<int,string>> Request names mapped to allowed verbs.
     */
    protected function getRoutes(): array
    {
        return [
            'AllskyStatus'   => ['get'],
            'AllskyControl'  => ['post'],
            'CPULoad'        => ['get'],
            'CPUTemp'        => ['get'],
            'DayNightStatus' => ['get'],
            'DirectoryBrowserList' => ['get'],
            'ListFileTypeContent' => ['get'],
            'MemoryUsed'     => ['get'],
            'Multiple'       => ['post'],
            'ThrottleStatus' => ['get'],
            'Uptime'         => ['get'],
        ];
    }

    /**
     * Configure the endpoint to return plain HTML/text fragments by default.
     *
     * Most UIUTIL routes are polled by dashboard widgets that insert the
     * response directly into the DOM.  JSON routes call sendResponse()
     * explicitly when they need structured output.
     */
    public function __construct()
    {
        $this->jsonResponse = false;
    }

    /**
     * Read a value from the global settings array prepared by initialize_variables().
     * Optionally swap spaces with a given character for filename-ish values.
     *
     * @param string $name Setting key to read from the Allsky settings array.
     * @param string $swapSpaces Replacement for literal spaces; leave empty to preserve spaces.
     *
     * @return mixed The configured value, or the historical fallback used by this UI.
     */
    private function getSetting(string $name, string $swapSpaces = '')
    {
        /** @var array $settings_array */
        global $settings_array;
        $val = getVariableOrDefault($settings_array, $name, 'overlay.json');
        if ($swapSpaces !== '') $val = str_replace(' ', $swapSpaces, (string)$val);
        return $val;
    }

    /**
     * Return a short remote Website version suffix for the header status block.
     *
     * The local WebUI can manage a separately installed remote Website.  When
     * that Website reports a different Allsky version, this method returns a
     * pre-escaped suffix such as `&nbsp; (version 2026.xx.xx)`.  Matching
     * versions and missing/unreadable config files intentionally return an empty
     * string so the status display remains compact.
     *
     * @return string HTML-safe version suffix, or an empty string when no suffix is needed.
     */
    private function getRemoteWebsiteVersionText(): string
    {
        $configFile = getRemoteWebsiteConfigFile();
        if (!file_exists($configFile)) {
            return '';
        }

        $retMsg = '';
        $config = get_decoded_json_file($configFile, true, '', $retMsg);
        if (!is_array($config)) {
            return '';
        }

        $remoteWebsiteVersion = getVariableOrDefault($config, 'AllskyVersion', null);
        if ($remoteWebsiteVersion === null) {
            return '';
        }
        if ($remoteWebsiteVersion == ALLSKY_VERSION) {
            return '';
        }

        return '&nbsp; (version ' . htmlspecialchars((string)$remoteWebsiteVersion, ENT_QUOTES, 'UTF-8') . ')';
    }
        
    /**
     * Build a bootstrap progress bar with safe output.
     *
     * @param mixed       $x                (unused placeholder maintained for compatibility)
     * @param string      $data             Label shown inside the bar
     * @param float|int   $min              Lower bound for clamping
     * @param float|int   $current          Current numeric value
     * @param float|int   $max              Upper bound for clamping
     * @param float|int   $danger           Threshold for red (>=)
     * @param float|int   $warning          Threshold for yellow (>=)
     * @param string      $status_override  Force bar state ('success'|'warning'|'danger'|...)
     *
     * @return string HTML <div> for a progress-bar-* element
     */
    private function displayProgress($x, $data, $min, $current, $max, $danger, $warning, $status_override): string
    {
        // Choose a state: explicit override wins; otherwise decide from thresholds
        $myStatus = $status_override ?: (
            $current >= $danger ? 'danger' :
            ($current >= $warning ? 'warning' : 'success')
        );

        // Keep values sane and compute width
        $current = max($min, min($current, $max));
        $width = (($current - $min) / ($max - $min)) * 100;

        // Return a single progress bar segment with accessible attributes
        return sprintf(
            "<div class='progress-bar progress-bar-not-animated progress-bar-%s' ".
            "role='progressbar' title='current: %s, min: %s, max: %s' ".
            "aria-valuenow='%s' aria-valuemin='%s' aria-valuemax='%s' ".
            "style='width: %.2f%%;'><span class='nowrap'>%s</span></div>",
            htmlspecialchars($myStatus, ENT_QUOTES, 'UTF-8'),
            $current, $min, $max, $current, $min, $max, $width, $data
        );
    }

    /**
     * Render the overall Allsky system status header fragment.
     *
     * This combines the status HTML produced by functions.php with local and
     * remote Website badges.  The response is sent directly as an HTML fragment
     * because callers insert it into the page.
     */
    public function getAllskyStatus(): void
    {
        global $useLocalWebsite, $useRemoteWebsite, $remoteWebsiteURL;

        $localWebsiteBadgeClass = $useLocalWebsite ? 'label-success' : 'label-default';
        $localWebsiteBadgeText = $useLocalWebsite ? 'Enabled' : 'Disabled';
        $remoteWebsiteBadgeClass = $useRemoteWebsite ? 'label-success' : 'label-default';
        $remoteWebsiteBadgeText = $useRemoteWebsite ? 'Enabled' : 'Disabled';
        $remoteWebsiteVersion = $this->getRemoteWebsiteVersionText();
		// Make sure the "external" icons line up.
		if ($remoteWebsiteVersion !== "") $remoteWebsiteVersion = " $remoteWebsiteVersion";
        $localWebsiteLink = $useLocalWebsite
            ? "<a external='true' target='_blank' rel='noopener noreferrer' href='allsky/index.php'>View</a>"
            : "";
        $remoteWebsiteLink = $useRemoteWebsite
            ? "<a external='true' target='_blank' rel='noopener noreferrer' href='{$remoteWebsiteURL}'>View{$remoteWebsiteVersion}</a>"
            : "";
        $websiteHtml = "<div class='header-status-row'><span class='header-status-row-label'>Local:</span><span class='header-status-row-value'><span class='label {$localWebsiteBadgeClass}'>{$localWebsiteBadgeText}</span> {$localWebsiteLink}</span></div><div class='header-status-row'><span class='header-status-row-label'>Remote:</span><span class='header-status-row-value'><span class='label {$remoteWebsiteBadgeClass}'>{$remoteWebsiteBadgeText}</span> {$remoteWebsiteLink}</span></div>";

        $result = output_allsky_status("", $websiteHtml);
        $this->sendHTTPResponse($result);
    }

    /**
     * Request a start, stop, or restart of the Allsky systemd service.
     *
     * The request body must be JSON with an `action` value of `start`, `stop`,
     * or `restart`.  The command is executed without a shell via runProcess().
     * On success or failure, the method sends a JSON response and exits.
     */
    public function postAllskyControl(): void
    {
        $input = file_get_contents('php://input');
        $data = json_decode($input ?: '{}', true);
        if (!is_array($data)) {
            $this->send500('Invalid request payload.');
        }

        $action = strtolower(trim((string)($data['action'] ?? '')));
        if (!in_array($action, ['start', 'stop', 'restart'], true)) {
            $this->send400('Invalid action.');
        }

        $result = $this->runProcess(['sudo', '-n', '/bin/systemctl', $action, 'allsky']);
        if ($result['error']) {
            $message = trim((string)$result['message']);
            if ($message === '') {
                $message = 'Unable to ' . $action . ' Allsky service.';
            }
            $this->sendResponse([
                'ok' => false,
                'action' => $action,
                'message' => $message,
            ]);
        }

        if ($action === 'stop') {
            update_allsky_status(ALLSKY_STATUS_NOT_RUNNING);
        }

        $this->sendResponse([
            'ok' => true,
            'action' => $action,
            'message' => 'Allsky ' . $action . ' requested.',
        ]);
    }

    /**
     * Return current CPU load as a Bootstrap progress-bar fragment.
     *
     * When called by postMultiple(), the fragment is returned to the caller.
     * When called directly as a route, it is sent immediately as plain HTML.
     *
     * @return string|null HTML progress bar when batching; otherwise no return.
     */
    public function getCPULoad()
    {
        $cpuLoad = (float)getCPULoad(1);
        $bar = $this->displayProgress('', "$cpuLoad%", 0, $cpuLoad, 100, 90, 75, '');

        if ($this->returnValues) {
            return $bar;
        }

        $this->sendHTTPResponse($bar);
    }

    /**
     * Return CPU temperature as a Bootstrap progress-bar fragment.
     *
     * Temperature status colors are supplied by getCPUTemp() in functions.php,
     * so this method only formats the final HTML and handles direct-vs-batch
     * response behavior.
     *
     * @return string|null HTML progress bar when batching; otherwise no return.
     */
    public function getCPUTemp()
    {
        $data = getCPUTemp(); // ['temperature' => float, 'display_temperature' => '...', 'temperature_status' => 'success|warning|danger']
        $temp = (float)$data['temperature'];
        $bar = $this->displayProgress(
            '',
            $data['display_temperature'],
            0,
            $temp,
            100,
            70,
            60,
            $data['temperature_status']
        );

        if ($this->returnValues) {
            return $bar;
        }

        $this->sendHTTPResponse($bar);
    }

    /**
     * Return memory usage as a Bootstrap progress-bar fragment.
     *
     * The bar uses the same threshold colors as CPU load and can be either
     * returned to the Multiple batch endpoint or sent directly to the browser.
     *
     * @return string|null HTML progress bar when batching; otherwise no return.
     */
    public function getMemoryUsed()
    {
        $used = (float)getMemoryUsed();
        $bar = $this->displayProgress('', "$used%", 0, $used, 100, 90, 75, '');

        if ($this->returnValues) {
            return $bar;
        }

        $this->sendHTTPResponse($bar);
    }

    /**
     * Return Raspberry Pi throttle status as a colored progress-bar fragment.
     *
     * The status text and severity come from functions.php.  The displayed text
     * is escaped before being placed in the HTML fragment.
     *
     * @return string|null HTML progress bar when batching; otherwise no return.
     */
    public function getThrottleStatus()
    {
        $data = getThrottleStatus(); // e.g. ['throttle' => '...','throttle_status' => 'success|warning|danger']
        $bar = $this->displayProgress(
            '',
            htmlspecialchars($data['throttle'], ENT_QUOTES),
            0,
            100,
            100,
            -1,
            -1,
            $data['throttle_status']
        );

        if ($this->returnValues) {
            return $bar;
        }

        $this->sendHTTPResponse($bar);
    }

    /**
     * Return the system uptime as escaped text.
     *
     * This method mirrors the other small dashboard getters: it returns the text
     * when called by the Multiple endpoint and sends it directly when called as
     * an individual route.
     *
     * @return string|null Escaped uptime when batching; otherwise no return.
     */
    public function getUptime()
    {
        $uptime = htmlspecialchars(getUptime(), ENT_QUOTES);

        if ($this->returnValues) {
            return $uptime;
        }

        $this->sendHTTPResponse($uptime);
    }

    /**
     * Render capture mode and upcoming day/night transition information.
     *
     * The current day/night state is combined with capture and save settings to
     * choose a success, warning, or danger label.  The returned HTML includes a
     * dropdown with the day's transition times for use in the header.
     *
     * @return string|null HTML card when batching; otherwise no return.
     */
    public function getDayNightStatus()
    {
        $status = getDayNightStatus();
        $state = $status['state'];
        $display = htmlspecialchars($status['display'], ENT_QUOTES);

        $labelClass = 'label-default';
        if ($state === 'day' || $state === 'night') {
            $captureSetting = $state === 'day' ? 'takedaytimeimages' : 'takenighttimeimages';
            $saveSetting = $state === 'day' ? 'savedaytimeimages' : 'savenighttimeimages';

            $isCapturing = toBool((string)$this->getSetting($captureSetting));
            $isSaving = toBool((string)$this->getSetting($saveSetting));

            if ($isCapturing && $isSaving) {
                $labelClass = 'label-success';
            } else if ($isCapturing && !$isSaving) {
                $labelClass = 'label-warning';
            } else {
                $labelClass = 'label-danger';
            }
        }

        $labelText = ucfirst($state);
        if ($state === 'unknown') {
            $labelText = 'Unknown';
        }

        $nextStateText = htmlspecialchars(ucfirst($status['nextState'] ?? 'unknown'), ENT_QUOTES);
        $transitionDuration = htmlspecialchars($status['transitionDuration'] ?? '--', ENT_QUOTES);
        $nextTransitionTime = htmlspecialchars($status['nextTransitionTime'] ?? '--:--', ENT_QUOTES);
        $dawn = htmlspecialchars($status['dawn'] ?? '--:--', ENT_QUOTES);
        $sunrise = htmlspecialchars($status['sunrise'] ?? '--:--', ENT_QUOTES);
        $midday = htmlspecialchars($status['midday'] ?? '--:--', ENT_QUOTES);
        $sunset = htmlspecialchars($status['sunset'] ?? '--:--', ENT_QUOTES);
        $dusk = htmlspecialchars($status['dusk'] ?? '--:--', ENT_QUOTES);

        $html = sprintf(
            "<div class='header-daynight-card dropdown'><div class='header-status-heading'><span class='header-status-title'>Capture Mode</span><button type='button' class='btn btn-default btn-xs header-daynight-toggle' data-toggle='dropdown' aria-expanded='false'><i class='fa-solid fa-chevron-down'></i></button></div><div class='header-status-row'><span class='header-status-row-label'>Mode:</span><span class='header-status-row-value'><span class='label %s'>%s</span></span></div><div class='header-status-row'><span class='header-status-row-label'>Transition in:</span><span class='header-status-row-value'>%s</span></div><ul class='dropdown-menu dropdown-menu-right header-daynight-menu'><li class='dropdown-header'>Transition Times</li><li><div class='header-daynight-menu-body'><div class='header-daynight-menu-row'><span>Dawn</span><strong>%s</strong></div><div class='header-daynight-menu-row'><span>Sunrise</span><strong>%s</strong></div><div class='header-daynight-menu-row'><span>Midday</span><strong>%s</strong></div><div class='header-daynight-menu-row'><span>Sunset</span><strong>%s</strong></div><div class='header-daynight-menu-row'><span>Dusk</span><strong>%s</strong></div><div class='header-daynight-menu-divider'></div><div class='header-daynight-menu-row'><span>Next Transition</span><strong>%s</strong></div></div></li></ul></div>",
            $labelClass,
            htmlspecialchars($labelText, ENT_QUOTES),
            $transitionDuration,
            $dawn,
            $sunrise,
            $midday,
            $sunset,
            $dusk,
            $nextTransitionTime
        );

        if ($this->returnValues) {
            return $html;
        }

        $this->sendHTTPResponse($html);
    }

    /**
     * Render the reusable image/video listing fragment.
     *
     * Query parameters mirror renderListFileTypeContent(): directory, filename
     * prefix, display name, media type, day, and thumbnail/list options.  This
     * endpoint exists so pages can lazy-load or refresh media grids without
     * duplicating the rendering logic in JavaScript.
     */
    public function getListFileTypeContent(): void
    {
        $dir = (string)($_GET['dir'] ?? '');
        $imageFileName = (string)($_GET['imageFileName'] ?? '');
        $formalImageTypeName = (string)($_GET['formalImageTypeName'] ?? 'Files');
        $type = (string)($_GET['type'] ?? '');
        $chosenDay = (string)($_GET['day'] ?? '');
        $listNames = in_array(strtolower((string)($_GET['listNames'] ?? '0')), ['1', 'true', 'yes'], true);
        $useThumbnails = in_array(strtolower((string)($_GET['useThumbnails'] ?? '1')), ['1', 'true', 'yes'], true);

        if (!in_array($type, ['picture', 'video'], true)) {
            $this->send400('Invalid file type.');
        }

        $html = renderListFileTypeContent($dir, $imageFileName, $formalImageTypeName, $type, $listNames, $chosenDay, [
            'useThumbnails' => $useThumbnails,
        ]);
        $this->sendHTTPResponse($html);
    }

    /**
     * Return one level of child directories for the helper directory browser.
     *
     * The browser passes a configured base folder, a relative path under that
     * base, the currently selected directory, and an optional maximum navigation
     * depth.  This method validates that all resolved paths remain under the
     * allowed images tree before returning JSON.
     */
    public function getDirectoryBrowserList(): void
    {
        $baseFolder = trim((string)($_GET['baseFolder'] ?? ''));
        $relativePath = trim((string)($_GET['path'] ?? ''));
        $currentDirectory = trim((string)($_GET['currentDirectory'] ?? ''));
        $maxDepth = $this->directoryBrowserMaxDepth($_GET['maxDepth'] ?? null);

        if ($baseFolder === '') {
            $this->send400('Base folder is required.');
        }
        if (preg_match('/[\x00-\x1F\x7F]/', $baseFolder . $relativePath . $currentDirectory) === 1) {
            $this->send400('Invalid path.');
        }

        $basePath = $this->resolveDirectoryBrowserBase($baseFolder);
        if ($basePath === null) {
            $this->send400('Invalid base folder.');
        }

        $directory = $this->resolveDirectoryBrowserPath($basePath, $relativePath);
        if ($directory === null) {
            $this->send400('Invalid path.');
        }

        $currentPath = $this->resolveDirectoryBrowserCurrentPath($basePath, $currentDirectory, $maxDepth);

        $this->sendResponse([
            'ok' => true,
            'path' => $this->relativeDirectoryBrowserPath($basePath, $directory),
            'fullPath' => $directory,
            'currentPath' => $currentPath,
            'maxDepth' => $maxDepth,
            'directories' => $this->listDirectoryBrowserDirectories($basePath, $directory, $maxDepth),
        ]);
    }

    /**
     * Resolve and validate the directory browser base folder.
     *
     * The special base value `images` maps to ALLSKY_IMAGES.  Absolute paths are
     * accepted only if they resolve inside ALLSKY_IMAGES, which prevents the UI
     * from being used to browse arbitrary server directories.
     *
     * @param string $baseFolder Configured base folder or the special value `images`.
     *
     * @return string|null Canonical base path, or null when invalid/unavailable.
     */
    private function resolveDirectoryBrowserBase(string $baseFolder): ?string
    {
        $allowedBase = realpath(ALLSKY_IMAGES);
        if ($allowedBase === false || !is_dir($allowedBase)) {
            return null;
        }

        $baseFolder = $baseFolder === 'images' ? ALLSKY_IMAGES : $baseFolder;
        $basePath = realpath($baseFolder);
        if ($basePath === false || !is_dir($basePath)) {
            return null;
        }

        if (!$this->isDirectoryBrowserPathInside($allowedBase, $basePath)) {
            return null;
        }

        return $basePath;
    }

    /**
     * Resolve a browser path under an already validated base path.
     *
     * The client sends paths relative to the base folder.  The resolved directory
     * must exist and remain inside the base after symlinks and `..` segments are
     * resolved by realpath().
     *
     * @param string $basePath Canonical base path returned by resolveDirectoryBrowserBase().
     * @param string $relativePath Relative child path requested by the browser.
     *
     * @return string|null Canonical directory path, or null when invalid.
     */
    private function resolveDirectoryBrowserPath(string $basePath, string $relativePath): ?string
    {
        $relativePath = trim($relativePath, "/\\");
        $candidate = $relativePath === '' ? $basePath : $basePath . DIRECTORY_SEPARATOR . $relativePath;
        $realPath = realpath($candidate);
        if ($realPath === false || !is_dir($realPath)) {
            return null;
        }

        if (!$this->isDirectoryBrowserPathInside($basePath, $realPath)) {
            return null;
        }

        return $realPath;
    }

    /**
     * Normalize the current input value into a relative directory-browser path.
     *
     * Current values may be absolute paths or relative paths.  Values outside
     * the base directory, non-directories, or values deeper than maxDepth are
     * ignored so the client does not preselect an invalid item.
     *
     * @param string $basePath Canonical browser base path.
     * @param string $currentDirectory Current form input value from the browser.
     * @param int|null $maxDepth Optional maximum selectable depth below the base.
     *
     * @return string Relative current path, or an empty string when no valid current path exists.
     */
    private function resolveDirectoryBrowserCurrentPath(string $basePath, string $currentDirectory, ?int $maxDepth): string
    {
        if ($currentDirectory === '') {
            return '';
        }

        $realPath = realpath($currentDirectory);
        if ($realPath === false) {
            $realPath = realpath($basePath . DIRECTORY_SEPARATOR . trim($currentDirectory, "/\\"));
        }

        if ($realPath === false || !is_dir($realPath) || !$this->isDirectoryBrowserPathInside($basePath, $realPath)) {
            return '';
        }

        $relativePath = $this->relativeDirectoryBrowserPath($basePath, $realPath);
        if ($maxDepth !== null && $this->directoryBrowserDepth($relativePath) > $maxDepth) {
            return '';
        }

        return $relativePath === '' ? '' : $relativePath;
    }

    /**
     * List immediate child directories for the directory browser.
     *
     * Hidden dot directories are skipped by readDirectoryBrowserDirectory().
     * Symlinked entries are resolved and only included if they still point under
     * the configured base.  When the requested directory is already at maxDepth,
     * no children are returned.
     *
     * @param string $basePath Canonical browser base path.
     * @param string $directory Canonical directory whose children should be listed.
     * @param int|null $maxDepth Optional maximum navigation depth.
     *
     * @return array<int,array{name:string,path:string,fullPath:string}> Sorted directory rows.
     */
    private function listDirectoryBrowserDirectories(string $basePath, string $directory, ?int $maxDepth): array
    {
        if ($maxDepth !== null && $this->directoryBrowserDepth($this->relativeDirectoryBrowserPath($basePath, $directory)) >= $maxDepth) {
            return [];
        }

        $items = [];
        foreach ($this->readDirectoryBrowserDirectory($directory) as $entry) {
            $path = $directory . DIRECTORY_SEPARATOR . $entry;
            $realPath = realpath($path);
            if ($realPath === false || !is_dir($realPath) || !$this->isDirectoryBrowserPathInside($basePath, $realPath)) {
                continue;
            }

            $items[] = [
                'name' => $entry,
                'path' => $this->relativeDirectoryBrowserPath($basePath, $realPath),
                'fullPath' => $realPath,
            ];
        }

        usort($items, fn($a, $b) => strnatcasecmp($a['name'], $b['name']));
        return $items;
    }

    /**
     * Parse the optional maxDepth query parameter.
     *
     * Empty, missing, or invalid values mean "unlimited".  Valid integers are
     * clamped to zero or greater.
     *
     * @param mixed $value Raw query parameter value.
     *
     * @return int|null Parsed maximum depth, or null for unlimited.
     */
    private function directoryBrowserMaxDepth($value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        $depth = filter_var($value, FILTER_VALIDATE_INT);
        if ($depth === false) {
            return null;
        }

        return max(0, $depth);
    }

    /**
     * Read visible entries from a directory.
     *
     * This is a thin wrapper around scandir() that hides `.`/`..` and dotfiles,
     * and returns an empty list if the directory cannot be read.
     *
     * @param string $directory Directory to scan.
     *
     * @return array<int,string> Visible entry names.
     */
    private function readDirectoryBrowserDirectory(string $directory): array
    {
        $entries = scandir($directory);
        if (!is_array($entries)) {
            return [];
        }

        return array_values(array_filter($entries, function ($entry) {
            return $entry !== '.' && $entry !== '..' && strpos($entry, '.') !== 0;
        }));
    }

    /**
     * Determine whether a path resolves inside a base directory.
     *
     * Both paths are normalized with trailing directory separators before the
     * prefix check, so sibling directories with similar names are not accepted.
     *
     * @param string $basePath Canonical base directory.
     * @param string $path Canonical candidate directory.
     *
     * @return bool True when the candidate is inside the base directory.
     */
    private function isDirectoryBrowserPathInside(string $basePath, string $path): bool
    {
        $basePath = rtrim($basePath, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
        $path = rtrim($path, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;

        return strpos($path, $basePath) === 0;
    }

    /**
     * Convert an absolute image directory path into a slash-separated relative path.
     *
     * The caller is responsible for validating that the path is inside the base
     * before calling this helper.
     *
     * @param string $basePath Canonical base directory.
     * @param string $path Canonical path under the base.
     *
     * @return string Relative path suitable for browser requests.
     */
    private function relativeDirectoryBrowserPath(string $basePath, string $path): string
    {
        return ltrim(str_replace('\\', '/', substr($path, strlen(rtrim($basePath, DIRECTORY_SEPARATOR)))), '/');
    }

    /**
     * Count how many directory levels a relative path is below the browser base.
     *
     * The base itself has depth 0, a direct child has depth 1, and so on.
     *
     * @param string $relativePath Slash-separated path relative to the browser base.
     *
     * @return int Relative depth below the base directory.
     */
    private function directoryBrowserDepth(string $relativePath): int
    {
        $relativePath = trim($relativePath, '/');
        if ($relativePath === '') {
            return 0;
        }

        return substr_count($relativePath, '/') + 1;
    }

    /**
     * Batch endpoint: accept a JSON array describing which getters to run,
     * call each one, and return a JSON object of results.
     *
     * Input format (example):
     * [
     *   {"data":"CPULoad"},
     *   {"data":"CPUTemp"},
     *   {"data":"Uptime"}
     * ]
     *
     * Response:
     * {
     *   "CPULoad": "<div class='progress-bar ...'>...</div>",
     *   "CPUTemp": "<div class='progress-bar ...'>...</div>",
     *   "Uptime":  "1 day 02:33:10"
     * }
     *
     * Security/robustness:
     * - Hard size limit (1 MB) on the JSON body
     * - Only methods whitelisted in getRoutes() and actually implemented are called
     * - Method names derived from user input are sanitized to [a-zA-Z0-9_]
     * - Errors in an individual call return an error string for that key; the batch continues
     *
     * The method sends the JSON response directly and exits.
     */
    public function postMultiple(): void
    {
        $input = file_get_contents('php://input');
        if (strlen($input) > 1000000) {
            $this->send500('Request too large.');
        }

        try {
            $data = json_decode($input, true, 10, JSON_THROW_ON_ERROR);
        } catch (Throwable $e) {
            $this->send500('Invalid JSON payload.');
        }

        if (!is_array($data)) {
            $this->send500('Invalid request format.');
        }

        $this->returnValues = true;

        $result = [];

        foreach ($data as $key => $value) {
            if (!isset($value['data'])) continue;

            // Build a safe method name like "getCPULoad"
            $methodName = 'get' . preg_replace('/[^a-zA-Z0-9_]/', '', $value['data']);

            if (method_exists($this, $methodName)) {
                try {
                    // Call the method and capture its return value (if any).
                    // Most getters here directly send output; returned values are included when present.
                    $result[$value['data']] = call_user_func([$this, $methodName]);
                } catch (Throwable $e) {
                    $result[$value['data']] = 'Error: ' . $e->getMessage();
                }
            } else {
                $result[$value['data']] = 'Invalid method.';
            }
        }

        // For the batch endpoint we do respond with JSON
        $this->sendResponse($result);
    }
}

// Script entrypoint
$uiUtil = new UIUTIL();
$uiUtil->run();
