using Toybox.Application;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

var view;

// data field values, corresponds to settingConfig list of
// propertyKey @Properties.dataField in resources/settings.xml
enum {
  hide,
  battery,
  date,
  distance,
  steps,
  stepGoal,
  exactTime,
  activeMinutes,
  heartRate
}
var dataField = date;

var smallerFont = false;

var showIcons = true;

var piggyTime = true;

var showBattery = true;

var batteryWarn = 30;
var batteryAlert = 10;

enum {
  normal,   // white on black
  inverted  // black on white
}
var colorScheme = normal;

class AboutTime extends Application.AppBase {

  function initialize() {
    AppBase.initialize();
  }

  function onStart(state) {
    var app = Application.getApp();
    var storedDataField = app.getProperty("dataField");
    if (storedDataField != null) {
      dataField = storedDataField;
    }
    colorScheme = app.getProperty("colorScheme");

    smallerFont = app.getProperty("smallerFont");
    if (smallerFont != true) {
      smallerFont = false;
    }

    showIcons = app.getProperty("showIcons");
    if (showIcons != false) {
      showIcons = true;
    }

    piggyTime = app.getProperty("piggyTime");
    if (piggyTime != false) {
      piggyTime = true;
    }

    showBattery = app.getProperty("showBattery");
    if (showBattery != false) {
      showBattery = true;
    }

    var storedBatteryWarn = app.getProperty("batteryWarn");
    if (storedBatteryWarn != null) {
      batteryWarn = storedBatteryWarn;
    }
    var storedBatteryAlert = app.getProperty("batteryAlert");
    if (storedBatteryAlert != null) {
      batteryAlert = storedBatteryAlert;
    }

  }

  function onStop(state) {
    var app = Application.getApp();
    app.setProperty("dataField", dataField);
    app.setProperty("colorScheme", colorScheme);

    app.setProperty("smallerFont", smallerFont);
    app.setProperty("showIcons", showIcons);
    app.setProperty("piggyTime", piggyTime);
    app.setProperty("showBattery", showBattery);

    app.setProperty("batteryWarn", batteryWarn);
    app.setProperty("batteryAlert", batteryAlert);
  }

  function getInitialView() {
    view = new AboutTimeView();
    if( WatchUi has :WatchFaceDelegate ) {
      return [view, new AboutTimeDelegate()];
    } else {
      return [view];
    }
  }

  function onSettingsChanged() {
    var app = Application.getApp();

    dataField = app.getProperty("dataField");
    colorScheme = app.getProperty("colorScheme");

    smallerFont = app.getProperty("smallerFont");
    showIcons = app.getProperty("showIcons");
    piggyTime = app.getProperty("piggyTime");
    showBattery = app.getProperty("showBattery");

    batteryWarn = app.getProperty("batteryWarn");
    batteryAlert = app.getProperty("batteryAlert");

    WatchUi.requestUpdate();
  }

}
