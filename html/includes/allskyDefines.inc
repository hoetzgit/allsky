<?php

// These values are updated during installation.
define('ALLSKY_HOME',    '/home/pi/allsky');
define('ALLSKY_CONFIG',  '/home/pi/allsky/config');
define('ALLSKY_SCRIPTS', '/home/pi/allsky/scripts');
define('ALLSKY_IMAGES',  '/home/pi/allsky/images');
define('ALLSKY_MESSAGES',  '/home/pi/allsky/tmp/messages.txt');
define('ALLSKY_WEBUI',  '/home/pi/allsky/html');
define('ALLSKY_WEBSITE',  '/var/www/html/allsky-website');
define('ALLSKY_WEBSITE_LOCAL_CONFIG_NAME',  'configuration.json');
define('ALLSKY_WEBSITE_REMOTE_CONFIG_NAME',  'remote_configuration.json');
define('ALLSKY_WEBSITE_LOCAL_CONFIG',  '/var/www/html/allsky-website/configuration.json');
define('ALLSKY_WEBSITE_REMOTE_CONFIG',  '/home/pi/allsky/config/remote_configuration.json');
define('ALLSKY_OWNER', 'pi');
define('ALLSKY_GROUP', 'pi');
define('WEBSERVER_GROUP', 'www-data');
define('ALLSKY_REPO',  '/home/pi/allsky/config_repo');
define('ALLSKY_VERSION',  'v2022.MM.DD_tbd');
define('RASPI_CONFIG',   '/home/pi/allsky/config');

// Split the placeholder so it doesn't get replaced.
if (ALLSKY_HOME == "XX_ALLSKY_HOME" . "_XX") {
	// This file hasn't been updated yet after installation.
	// This would only happen if they updated this file and not the whole Allsky release,
	// which is hard since we only come out with releases.
	echo "<div style='font-size: 200%;'>";
	echo "<span style='color: red'>";
	echo "Please run the following from the 'allsky' directory before using the WebUI:";
	echo "</span>";
	echo "<code>   ./install.sh --update</code>";
	echo "</div>";
	exit;
}

?>
