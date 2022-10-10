<?php
include_once('includes/functions.php');

$cameraTypeName = "cameraType";        // json setting name
$cameraModelName = "cameraModel";    // json setting name

$settings_file = getSettingsFile();
$options_file = getOptionsFile();

$options_str = file_get_contents($options_file, true);
$options_array = json_decode($options_str, true);

// Determine if the advanced settings should always be shown.
$camera_settings_str = file_get_contents($settings_file, true);
$camera_settings_array = json_decode($camera_settings_str, true);
$cameraType = getVariableOrDefault($camera_settings_array, $cameraTypeName, "unknown");
$cameraModel = getVariableOrDefault($camera_settings_array, $cameraModelName, "unknown");
$initial_display = $camera_settings_array['alwaysshowadvanced'] == 1 ? "table-row" : "none";
// TODO: make it better
$osname = explode('=', shell_exec("grep '^NAME' /etc/os-release"));
$osversion = explode('=',shell_exec("grep '^VERSION=' /etc/os-release"));
$os = str_replace('"','',($osname[1]." ".$osversion[1]));
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <link rel="shortcut icon" type="image/png" href="img/allsky-favicon.png">
    <!-- Bootstrap Core CSS -->
    <link href="bower_components/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Make messages look nicer, and align the "x" with the message. -->
    <style>
        .x {line-height: 150%;}
        @media (min-width: 992px) {.col-md-6 { width: 75%; }}
    </style>
    <!-- Font Awesome -->
    <script defer src="js/all.min.js"></script>
    <!-- Custom CSS -->
    <link href="dist/css/custom.css" rel="stylesheet">
    <!-- jQuery -->
    <script src="bower_components/jquery/dist/jquery.min.js"></script>
    <!-- Bootstrap Core JavaScript -->
    <script src="bower_components/bootstrap/dist/js/bootstrap.min.js"></script>
</head>
<body>
    <div class="row" style="margin-right: 20px;margin-left: 20px;">
        <div class="col-lg-12" style="padding: 0px 5px 0px 5px;">
            <div class="panel panel-primary">
                <div class="panel-heading"><i class="fa fa-camera fa-fw"></i> My current configure settings for <b><?php echo "$cameraType $cameraModel";?> Camera</b>&nbsp;&nbsp;-&nbsp;&nbsp;<?php echo $os;?></div>
                <!-- /.panel-heading -->
                    <div class="panel-body" style="padding: 5px;">
<?php
    // Allow for "advanced" options that aren't displayed by default to avoid
    // confusing novice users.
    $numAdvanced = 0;
    echo "<table border='0'>";
        foreach($options_array as $option) {
            // Should this setting be displayed?
            $display = getVariableOrDefault($option, 'display', true);
            if (! $display) continue;
             $minimum = getVariableOrDefault($option, 'minimum', "");
            $maximum = getVariableOrDefault($option, 'maximum', "");
            $advanced = getVariableOrDefault($option, 'advanced', 0);
            if ($advanced == 1) {
                $numAdvanced++;
                $advClass = "advanced";
                $advStyle = "display: $initial_display";
            } else {
                $advClass = "";
                $advStyle = "";
            }
            $label = getVariableOrDefault($option, 'label', "");
            $name = $option['name'];
            $default = getVariableOrDefault($option, 'default', "");
            $type = getVariableOrDefault($option, 'type', "");    // should be a type
            if ($type == "header") {
                $value = "";
            } else {
                $value = getVariableOrDefault($camera_settings_array, $name, $default);
                $nullOK = getVariableOrDefault($option, 'nullOK', true);
                $nullOKbg = "";
                $nullOKmsg = "";
                // Numbers can never be mising; certain text can't either.
                if ($value === "" && ($nullOK === 0 || $type == "number")) {
                    $nullOKbg = "background-color: red";
                    $nullOKmsg = "<span style='color: red'>This field cannot be empty.</span><br>";
                }
                // Allow single quotes in values (for string values).
                // &apos; isn't supported by all browsers so use &#x27.
                $value = str_replace("'", "&#x27;", $value);
                $default = str_replace("'", "&#x27;", $default);
            }
            $description = getVariableOrDefault($option, 'description', "");
            // "widetext" should have the label spanning 2 rows,
            // a wide input box on the top row spanning the 2nd and 3rd columns,
            // and the description on the bottom row in the 3rd column.
            // This way, all descriptions are in the 3rd column.
            $class="";
            if ($type !== "widetext" && $name !== 'camera' && $name !== 'lens' && $type != "header") $class = "rowSeparator";
            echo "\n";    // to make it easier to read web source when debugging
             // Put some space before and after headers.  This next line is the "before":
            if ($type == "header") {
                echo "<tr style='height: 10px'><td colspan='3'></td></tr>";
                echo "<td colspan='3' style='padding: 8px 0px;' class='settingsHeader'>$description</td>";
                echo "<tr class='rowSeparator' style='height: 10px'><td colspan='3'></td></tr>";
            } else {
                echo "<tr class='form-group $advClass $class' style='margin-bottom: 0px; $advStyle'>";
                // Show the default in a popup
                if ($type == "checkbox") {
                    if ($default == "0") $default = "No";
                    else $default = "Yes";
                } elseif ($type == "select") {
                    foreach($option['options'] as $opt) {
                        $val = $opt['value'];
                        if ($val != $default) continue;
                        $default = $opt['label'];
                        break;
                    }
                }
                if ($default !== "")
                    $popup = "Default=$default";
                else
                    $popup = "";
                if ($minimum !== "") $popup .= "\nMinimum=$minimum";
                if ($maximum !== "") $popup .= "\nMaximum=$maximum";
                 $span="";
                if ($type == "widetext") $span="rowspan='2'";
                echo "<td $span valign='middle' style='padding: 2px 0px'>";
                echo "<label style='padding-right: 3px;'>$label</label>";
                echo "</td>";
                 if ($type == "widetext") $span="colspan='2'";
                else $span="";
                echo "<td $span style='padding: 5px 0px;'>";
                // The popup gets in the way of seeing the value a little.
                // May want to consider having a symbol next to the field
                // that has the popup.
                echo "<span title='$popup'>";
                $readonly = 'disabled';
                if ($type == "widetext") {
                    echo "<input class='form-control boxShadow' type='text'" .
                        " name='$name' value='$value'" .
                           " style='padding: 6px 5px; $nullOKbg'". ($readonly != "" ? (" ".$readonly) : ""). ">";
                } else if ($type == "text" || $type == "number" || $type == "readonly"){
                    if ($type == "readonly") {
                        $readonly = "disabled";
                        $t = "text";
                    } else {
                        // $readonly = "";
                        // Browsers put the up/down arrows for numbers which moves the
                        // numbers to the left, and they don't line up with text.
                        // Plus, they don't accept decimal points in "number".
                        if ($type == "number") $type = "text";
                        $t = $type;
                    }
                    echo "<input $readonly class='form-control boxShadow' type='$t'" .
                         " name='$name' value='$value'" .
                         " style='padding: 0px 3px 0px 0px; text-align: right; width: 120px; $nullOKbg". ($readonly != "" ? (" ".$readonly) : ""). ">";
                } else if ($type == "select"){
                    // text-align for <select> works on Firefox but not Chrome or Edge
                    echo "<select class='form-control boxShadow' name='$name' title='Select an item'" .
                           " style='width: 120px; margin-right: 20px; text-align: right; padding: 0px 3px 0px 0px;'". ($readonly != "" ? (" ".$readonly) : ""). ">";
                    foreach($option['options'] as $opt){
                        $val = $opt['value'];
                        $lab = $opt['label'];
                        if ($value == $val){
                            echo "<option value='$val' selected>$lab</option>";
                        } else {
                            echo "<option value='$val'>$lab</option>";
                        }
                    }
                    echo "</select>";
                } else if ($type == "checkbox"){
                    echo "<div class='switch-field boxShadow' style='margin-bottom: -3px; border-radius: 4px;'>";
                        echo "<input id='switch_no_".$name."' class='form-control' type='radio' ".
                            "name='$name' value='0' ".
                            ($value == 0 ? " checked " : ""). ($readonly != "" ? (" ".$readonly) : ""). ">";
                        echo "<label style='margin-bottom: 0px;' for='switch_no_".$name."'>No</label>";
                        echo "<input id='switch_yes_".$name."' class='form-control' type='radio' ".
                            "name='$name' value='1' ".
                            ($value == 1 ? " checked " : ""). ($readonly != "" ? (" ".$readonly) : ""). ">";
                        echo "<label style='margin-bottom: 0px;' for='switch_yes_".$name."'>Yes</label>";
                    echo "</div>";
                }
                echo "</span>";

                // dummy
                echo "<input type='hidden'>";

                echo "</td>";
                if ($type == "widetext")
                    echo "</tr><tr class='rowSeparator $advClass' style='$advStyle'><td></td>";
                echo "<td>$nullOKmsg$description</td>";
            }
            echo "</tr>";
         }
    echo "</table>";
?>
                    </div><!-- ./ Panel body -->
                </div><!-- /.panel-heading -->
            </div><!-- /.panel-primary -->
        </div><!-- /.col-lg-12 -->
    </div><!-- /.row -->
</body>