using Toybox.Graphics;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Application;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.UserProfile;

var locale = {};
var localeArrays = [];
var halfPast = true;
var updateCount = 0;
var fonts = new [7];
var lineHeight, iconHeight;
var prevTime, prevIcons;
var width, height, shape, device;
var canBurnIn = false;
var upTop = true;
var inLowPower =false;
// vertical compression of lines (decrease line spacing)
var linePack = 1.5; 
var isCjk = false;

enum {
  tiny,
  small,
  medium,
  large,
  mega,
  icons,
  icons_large
}

var bgColor = Graphics.COLOR_BLACK;
var textColor = Graphics.COLOR_WHITE;
var dataColor = Graphics.COLOR_LT_GRAY;

var fontIcons = {
  :alarm => "0",
  :batteryAlert => "1",
  :batteryCharging => "2",
  :batteryWarning => "3",
  :disconnected => "5",
  :sleep  => "6",
  :notification => "7"
};

class AboutTimeView extends WatchUi.WatchFace {
  function initialize() {
    WatchFace.initialize();
    Math.srand(System.getTimer());
    //check if burn in protection needed
    var sysSettings = System.getDeviceSettings();
    //first check if the setting is availe on the current device
    if(sysSettings has :requiresBurnInProtection) {
      //get the state of the setting
      canBurnIn = sysSettings.requiresBurnInProtection;
    }
  }

  function onLayout(dc) {

    readLocale();
    device = System.getDeviceSettings();
    height = dc.getHeight();
    width = dc.getWidth();
    shape = device.screenShape;
    fonts[tiny] = WatchUi.loadResource(@Rez.Fonts.id_font_tiny);
    fonts[small] = WatchUi.loadResource(@Rez.Fonts.id_font_small);
    fonts[medium] = WatchUi.loadResource(@Rez.Fonts.id_font_medium);
    fonts[large] = WatchUi.loadResource(@Rez.Fonts.id_font_large);
    if (smallerFont == false) {
      fonts[mega] = WatchUi.loadResource(@Rez.Fonts.id_font_extralarge);
    }

    // ugly hack: use system fonts for languages with unsupported glyphs
    if ((locale[:hours][1].find("一") != null) ||
        (locale[:hours][1].find("하나") != null)) {
      isCjk = true;
      fonts[tiny] = Graphics.FONT_SMALL;
      fonts[small] = Graphics.FONT_MEDIUM;
      fonts[medium] = Graphics.FONT_SYSTEM_LARGE;
      fonts[large] = Graphics.FONT_SYSTEM_LARGE;
      // fonts[mega] = fonts[large];
      // no vertical compression for system fonts
      linePack = 1;
    }

    if (smallerFont == false) {
      fonts[icons] = WatchUi.loadResource(@Rez.Fonts.id_iconFontLarge);
    }
    else {
      fonts[icons] = WatchUi.loadResource(@Rez.Fonts.id_iconFont);
    }
    lineHeight = Graphics.getFontHeight(fonts[tiny]) / 2;
    iconHeight = Graphics.getFontHeight(fonts[icons]);
  }

  function onPartialUpdate(dc) {
    var clockTime = System.getClockTime();
    var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    var piggy = piggyState(clockTime.hour, clockTime.min, today.day_of_week);
    if (dataField == exactTime || piggy[:showDigital]) {
      WatchUi.requestUpdate();
    }
    else if (clockTime.sec == 30) {
      WatchUi.requestUpdate();
    }
  }

  function onExitSleep() {
    inLowPower = false;
    WatchUi.requestUpdate();
  }

  function onEnterSleep() {
    inLowPower = true;
    WatchUi.requestUpdate();
  }

  function onUpdate(dc) {

    var time = System.getClockTime();
    var fuzzyHour = time.hour;
    var fuzzyMinutes = ((time.min + 2) / 5) * 5;
    if (fuzzyMinutes > 55) {
      fuzzyMinutes = 0;
      fuzzyHour += 1;
      if (fuzzyHour > 23) {
        fuzzyHour = 0;
      }
    }

    var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    var piggy = piggyState(time.hour, time.min, today.day_of_week);

    // noon/midnight standalone + piggy special phrases (override normal template)
    var special = null;
    if (fuzzyMinutes == 0 && fuzzyHour == 12) {
      special = locale[:noon];
    }
    else if (fuzzyMinutes == 0 && fuzzyHour == 0) {
      special = locale[:midnight];
    }
    else if (piggy[:special] != null) {
      special = locale[piggy[:special]];
    }

    var iconString = getIconString();
    
/*
 * It seems we need to redraw the screen anyway. Just returning from
 * onUpdate() may cause the screen to appear blank on real devices
 * (although it works fine in the simulator)
 *
 * See https://github.com/samuelmr/garmin-abouttime/issues/13
 *
    var thisTime = fuzzyHour.format("%d") + ":" + fuzzyMinutes.format("%02d");
    if (thisTime.equals(prevTime) && iconString.equals(prevIcons)) {
      // time and status haven't really changed, no need to update
      // System.println(thisTime + " – " + iconString);
      return;
    }
    prevTime = thisTime;
    prevIcons = iconString;
    // var thisTime = fuzzyHour.format("%d") + ":" + fuzzyMinutes.format("%02d");
    // System.println(thisTime + " – " + iconString);
*/

    if (colorScheme == inverted) {
      bgColor = Graphics.COLOR_WHITE;
      textColor = Graphics.COLOR_BLACK;
      dataColor = Graphics.COLOR_DK_GRAY;
    }

    dc.setColor(bgColor, bgColor);
    dc.clear();
    var timeSpace = drawTimeStrings(dc, fuzzyHour, fuzzyMinutes, special);

    var x = width/2;
    if (WatchUi has :getSubscreen && WatchUi.getSubscreen() != null) {
      // stupid hard coded value just for descentg1 and instinct2
      x -= 20;
    }

    // top: battery centered (state icons just below it, also centered) -- keeps everything inside the round screen
    var statusY = iconHeight + 22;
    if (showBattery) {
      var batteryStr = (System.getSystemStats().battery + 0.5).toNumber().format("%d") + "%";
      drawString(dc, x, statusY, Graphics.FONT_XTINY, dataColor, Graphics.TEXT_JUSTIFY_CENTER, batteryStr);
    }
    if (showIcons && (iconString.length() > 0)) {
      var iconsY = statusY + Graphics.getFontHeight(Graphics.FONT_XTINY) / 2 + Graphics.getFontHeight(fonts[icons]) / 2 + 8;
      if (timeSpace[:top] >= iconsY) {
        drawString(dc, x, iconsY, fonts[icons], textColor, Graphics.TEXT_JUSTIFY_CENTER, iconString);
      }
    }

    // bottom: date+weekday (extra small, moved up to stay inside the round screen)
    var dateString = Lang.format(locale["dateFormat"], [today.year, today.month, today.day, locale["week" + today.day_of_week]]);
    var dateY = height - 45;
    // digital time (piggy windows) right above the date, same extra-small font
    if (piggy[:showDigital]) {
      var digitalString = time.hour.format("%d") + ":" + time.min.format("%02d");
      var digitalY = dateY - Graphics.getFontHeight(Graphics.FONT_XTINY) - 20;
      if (digitalY - Graphics.getFontHeight(Graphics.FONT_XTINY) / 2 > timeSpace[:bottom]) {
        drawString(dc, width/2, digitalY, Graphics.FONT_XTINY, dataColor, Graphics.TEXT_JUSTIFY_CENTER, digitalString);
      }
    }
    if (dateY - Graphics.getFontHeight(Graphics.FONT_XTINY) / 2 > timeSpace[:bottom]) {
      drawString(dc, width/2, dateY, Graphics.FONT_XTINY, dataColor, Graphics.TEXT_JUSTIFY_CENTER, dateString);
    }

  }

  function getIconString() {

    var settings = System.getDeviceSettings();
    var profile = UserProfile.getProfile();
    var stats = System.getSystemStats();

    var now = Time.now();
    var today = Time.today();
    var isSleepTime = now.greaterThan(today.add(profile.sleepTime)) ||
                      now.lessThan(today.add(profile.wakeTime));

    var doNotDisturb = false;
    if (settings has :doNotDisturb) {
      doNotDisturb = settings.doNotDisturb;
    }

    var iconString = "";
    if (!settings.phoneConnected) {
      iconString += fontIcons[:disconnected];
    }
    if (settings.alarmCount > 0) {
      iconString += fontIcons[:alarm];
    }
    if (settings.notificationCount > 0) {
      iconString += fontIcons[:notification];
    }
    if (stats has :charging && stats.charging) {
      iconString += fontIcons[:batteryCharging];
    }
    else if ((stats.battery + 0.5).toNumber() < batteryAlert) {
      iconString += fontIcons[:batteryAlert];
    }
    else if ((stats.battery + 0.5).toNumber() < batteryWarn) {
      iconString += fontIcons[:batteryWarning];
    }
    if (isSleepTime || doNotDisturb) {
      iconString += fontIcons[:sleep];
    }
    return iconString;

  }

  function drawString(dc, x, y, font, color, alignment, string) {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, font, string, alignment | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  function drawTimeStrings(dc, fuzzyHour, fuzzyMinutes, special) {

    var timeSpace = {};

    var currentLocale = localize();
    var strings = prepareStrings(fuzzyHour, fuzzyMinutes, currentLocale, special);
    var top = strings[:top];
    var topFont = strings[:topFont];
    var middle = strings[:middle];
    var middleFont = strings[:middleFont];
    var bottom = strings[:bottom];
    var bottomFont = strings[:bottomFont];

    // System.println(strings[:top] + strings[:middle] + strings[:bottom]);

    topFont = scaleFont(dc, topFont, top, :top);
    middleFont = scaleFont(dc, middleFont, middle, :middle);
    bottomFont = scaleFont(dc, bottomFont, bottom, :bottom);

    var topHeight = Graphics.getFontHeight(topFont) / linePack;
    var middleHeight = Graphics.getFontHeight(middleFont) / linePack;
    var bottomHeight = Graphics.getFontHeight(bottomFont) / linePack;
    var totalHeight = topHeight + middleHeight + bottomHeight;

    var x = width / 2;
    // two-line phrases sit visually low: shift the whole block up by half a small line
    var lineShift = 0;
    if (middle.length() > 0 && bottom.length() > 0) {
      lineShift = -bottomHeight / 2;
    }
    var topY = height / 2 - totalHeight / 2 + topHeight / 2 + lineShift;
    if (WatchUi has :getSubscreen && WatchUi.getSubscreen() != null) {
      // stupid hard coded value just for descentg1 and instinct2
      topY += 20;
    }
    var middleY = topY + topHeight / 2 + middleHeight / 2;
    var bottomY = middleY + middleHeight / 2 + bottomHeight / 2;    
    if (inLowPower && canBurnIn) {
      // move by 1 pixel to prevent burn-in
      x += upTop ? 1 : 0;
      topY += upTop ? 1 : 0;
      middleY += upTop ? 1 : 0;
      bottomY += upTop ? 1 : 0;
      upTop = !upTop;
    }

    var color = textColor;

    drawString(dc, x, topY, topFont, color, Graphics.TEXT_JUSTIFY_CENTER, top);
    drawString(dc, x, middleY, middleFont, color, Graphics.TEXT_JUSTIFY_CENTER, middle);
    drawString(dc, x, bottomY, bottomFont, color, Graphics.TEXT_JUSTIFY_CENTER, bottom);

    timeSpace[:top] = topY - topHeight/2;
    timeSpace[:bottom] = bottomY + bottomHeight/2;

    return timeSpace;

  }

  // piggy time (工作提醒): workday-only special phrases + digital time windows.
  // Returns { :showDigital => Boolean, :special => String-key-or-null }.
  function piggyState(hour, min, dow) {
    var state = { :showDigital => false, :special => null };
    if (!piggyTime || dow < 2 || dow > 6) {
      return state;
    }
    var mins = hour * 60 + min;
    if (mins >= 8 * 60 + 10 && mins <= 8 * 60 + 35) { state[:showDigital] = true; }
    if (mins >= 16 * 60 + 50 && mins <= 17 * 60 + 5) { state[:showDigital] = true; }
    if (mins >= 8 * 60 + 20 && mins <= 8 * 60 + 30) { state[:special] = "workIn"; }
    else if (mins >= 16 * 60 + 40 && mins <= 16 * 60 + 44) { state[:special] = "workOff20"; }
    else if (mins >= 16 * 60 + 45 && mins <= 16 * 60 + 49) { state[:special] = "workOff15"; }
    else if (mins >= 16 * 60 + 50 && mins <= 16 *60 + 54) { state[:special] = "workOff10"; }
    else if (mins >= 16 * 60 + 55 && mins <= 16 * 60 + 59) { state[:special] = "workOffAlmost"; }
    else if (mins >= 17 * 60 && mins <= 17 * 60 + 4) { state[:special] = "workOff"; }
    return state;
  }

  function scaleFont(dc, font, string, position) {

    var lineWidth = width;
    if ((shape == System.SCREEN_SHAPE_ROUND) && (position != :middle)) {
      lineWidth = 0.9 * width;
    }
    if ((position == :top) && (WatchUi has :getSubscreen) && (WatchUi.getSubscreen() == null)) {
      lineWidth = 0.7 * width;
    }

    var strWidth = dc.getTextWidthInPixels(string, font);
    var fontIndex = medium;

    if (fonts has :indexOf) {
      fontIndex = fonts.indexOf(font);
    }

    if ((smallerFont == false) && (lineWidth > 180) && (string.length() <= 9)) {
      if (fontIndex < (fonts.size() - 1)) {
        fontIndex += 1;
        try {
          font = fonts[fontIndex];
          strWidth = dc.getTextWidthInPixels(string, font);
        }
        catch (e instanceof Toybox.Lang.Exception) {
          System.println("Error when trying to set font to " + fontIndex.format("%d") + "/" + fonts.size().format("%d"));
          System.println(e.getErrorMessage());
        }
     }
    }
    while ((strWidth > lineWidth) && (fontIndex > 0)) {
      fontIndex -= 1;
      font = fonts[fontIndex];
      strWidth = dc.getTextWidthInPixels(string, font);
    }
    return font;

  }

  function readLocale() {
    locale = {
      "min0" => WatchUi.loadResource(Rez.Strings.min0),
      "min5" => WatchUi.loadResource(Rez.Strings.min5),
      "min10" => WatchUi.loadResource(Rez.Strings.min10),
      "min15" => WatchUi.loadResource(Rez.Strings.min15),
      "min20" => WatchUi.loadResource(Rez.Strings.min20),
      "min25" => WatchUi.loadResource(Rez.Strings.min25),
      "min30" => WatchUi.loadResource(Rez.Strings.min30),
      "min35" => WatchUi.loadResource(Rez.Strings.min35),
      "min40" => WatchUi.loadResource(Rez.Strings.min40),
      "min45" => WatchUi.loadResource(Rez.Strings.min45),
      "min50" => WatchUi.loadResource(Rez.Strings.min50),
      "min55" => WatchUi.loadResource(Rez.Strings.min55),
      :hours => [
        "",
        WatchUi.loadResource(Rez.Strings.hour1),
        WatchUi.loadResource(Rez.Strings.hour2),
        WatchUi.loadResource(Rez.Strings.hour3),
        WatchUi.loadResource(Rez.Strings.hour4),
        WatchUi.loadResource(Rez.Strings.hour5),
        WatchUi.loadResource(Rez.Strings.hour6),
        WatchUi.loadResource(Rez.Strings.hour7),
        WatchUi.loadResource(Rez.Strings.hour8),
        WatchUi.loadResource(Rez.Strings.hour9),
        WatchUi.loadResource(Rez.Strings.hour10),
        WatchUi.loadResource(Rez.Strings.hour11)
      ],
      :noon => WatchUi.loadResource(Rez.Strings.noon),
      :midnight => WatchUi.loadResource(Rez.Strings.midnight),
      :hour12Word => WatchUi.loadResource(Rez.Strings.hour12Word),
      :hourZeroWord => WatchUi.loadResource(Rez.Strings.hourZeroWord),
      "workIn" => WatchUi.loadResource(Rez.Strings.workIn),
      "workOff20" => WatchUi.loadResource(Rez.Strings.workOff20),
      "workOff15" => WatchUi.loadResource(Rez.Strings.workOff15),
      "workOff10" => WatchUi.loadResource(Rez.Strings.workOff10),
      "workOffAlmost" => WatchUi.loadResource(Rez.Strings.workOffAlmost),
      "workOff" => WatchUi.loadResource(Rez.Strings.workOff),
      "week1" => WatchUi.loadResource(Rez.Strings.week1),
      "week2" => WatchUi.loadResource(Rez.Strings.week2),
      "week3" => WatchUi.loadResource(Rez.Strings.week3),
      "week4" => WatchUi.loadResource(Rez.Strings.week4),
      "week5" => WatchUi.loadResource(Rez.Strings.week5),
      "week6" => WatchUi.loadResource(Rez.Strings.week6),
      "week7" => WatchUi.loadResource(Rez.Strings.week7),
      "dateFormat" => WatchUi.loadResource(Rez.Strings.dateFormat),
    };
    var keys = locale.keys();
    for (var i=0; i<keys.size(); i++) {
      var key = keys[i];
      locale[key] = strToArray(locale[key]);
      if (key != :hours && locale[key] instanceof Toybox.Lang.Array) {
        localeArrays.add({:name => key, :size => locale[key].size()});
      }
    }
    for (var i=0; i<locale[:hours].size(); i++) {
      locale[:hours][i] = strToArray(locale[:hours][i]);
      if (locale[:hours][i] instanceof Toybox.Lang.Array) {
        localeArrays.add({:name => i, :size => locale[:hours][i].size()});
      }
    }
  }

  function localize() {
    var currentLocale = cloneDictionary(locale);
    var i;
    for (i=0; i<localeArrays.size(); i++) {
      var it = localeArrays[i];
      var r = Math.rand() % it[:size];
      var key = it[:name];
      if (key instanceof Toybox.Lang.Number) {
        currentLocale[:hours][key] = locale[:hours][key][r];
      }
      else {
        currentLocale[key] = locale[key][r];
      }
    }
    return currentLocale;
  }

  function prepareStrings(fuzzyHour, fuzzyMinutes, currentLocale, special) {
    var top = "";
    var middle = "";
    var bottom = "";

    var nextHour = fuzzyHour + 1;

    if (fuzzyHour == 0) {
      fuzzyHour = currentLocale[:hourZeroWord];
    }
    else if (fuzzyHour == 12) {
      fuzzyHour = currentLocale[:hour12Word];
    }
    else {
      fuzzyHour = currentLocale[:hours][fuzzyHour % 12];
    }

    if (nextHour == 24) {
      nextHour = currentLocale[:hourZeroWord];
    }
    else if (nextHour == 12) {
      nextHour = currentLocale[:hour12Word];
    }
    else {
      nextHour = currentLocale[:hours][nextHour % 12];
    }

    var lineString = locale["min" + fuzzyMinutes];
    if (special != null) {
      lineString = special;
    }
    var lines = new [3];
    var firstIndex = lineString.find("	");
    if (firstIndex == null) {
      lines[0] = "";
      lines[1] = lineString;
      lines[2] = "";
    }
    else {
      lines[0] = "";
      lines[1] = lineString.substring(0, firstIndex);
      lines[2] = lineString.substring(firstIndex + 1, lineString.length());
      var secondIndex = lines[2].find("	");
      if (secondIndex != null) {
        lines[0] = lines[1];
        lines[1] = lines[2].substring(0, secondIndex);
        lines[2] = lines[2].substring(secondIndex + 1, lines[2].length());
      }
    }

    var topFont = fonts[small];
    var middleFont = fonts[medium];
    var bottomFont = fonts[large];

    if (lines[0].find("$") != null) {
      topFont = fonts[large];
      middleFont = fonts[small];
      bottomFont = fonts[medium];
    }
    else if ((lines[1].find("$") != null) && (lines[2].length() > 0)) {
      topFont = fonts[small];
      middleFont = fonts[large];
      bottomFont = fonts[medium];
    }
    else if (lines[1].find("$") != null) {
      topFont = fonts[medium];
      middleFont = fonts[large];
      bottomFont = fonts[tiny];
    }

    if (lines[0].length() == 0) {
      topFont = fonts[tiny];
    }

    if (lines[2].length() == 0) {
      bottomFont = fonts[tiny];
    }

    var params = [fuzzyHour, nextHour];

    top = Lang.format(lines[0], params);
    middle = Lang.format(lines[1], params);
    bottom = Lang.format(lines[2], params);

    return {
      :bottom => bottom,
      :bottomFont => bottomFont,
      :middle => middle,
      :middleFont => middleFont,
      :top => top,
      :topFont => topFont
    };
  }

  function strToArray(str) {
    if (str instanceof Toybox.Lang.String != true) {
      return str;
    }

    if (str.find("|")) {
      var arr = [];
      while (str.find("|")) {
        var splitIndex = str.find("|");
        // if (! arr has :add) { // epix doesn't support array.add()
        //   return str.substring(0, splitIndex);
        // }
        arr.add(str.substring(0, splitIndex));
        str = str.substring(splitIndex+1, str.length());
      }
      arr.add(str);
     return arr;
    }
    return str;
  }

  function cloneDictionary(source) {
    var target = {};
    var keys = source.keys();
    for (var i=0; i<keys.size(); i++) {
      if (source[keys[i]] instanceof Toybox.Lang.Array) {
        target[keys[i]] = cloneArray(source[keys[i]]);
      }
      else {
        target[keys[i]] = source[keys[i]];
      }
    }
    return target;
  }

  function cloneArray(source) {
    var target = new [source.size()];
    for (var i=0; i<source.size(); i++) {
      target[i] = source[i];
    }
    return target;
  }

}


class AboutTimeDelegate extends WatchUi.WatchFaceDelegate {

  function initialize() {
    WatchFaceDelegate.initialize();
  }
  function onPowerBudgetExceeded(powerInfo) {
    System.println( "Average execution time: " + powerInfo.executionTimeAverage );
    System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
  }
}
