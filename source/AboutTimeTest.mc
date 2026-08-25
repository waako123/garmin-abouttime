using Toybox.System;
using Toybox.Test;

(:test)
class AboutTimeTest {

  // 时间短语映射（模板层，special=null）。比对 middle/bottom 文本。
  (:test)
  function testTemplateStrings(logger) {
    var view = new AboutTimeView();
    view.readLocale();
    var cases = [
      [0, 0, "零点整", ""],
      [12, 0, "十二点整", ""],
      [1, 5, "一点", "过五分"],
      [1, 10, "一点", "过十分"],
      [1, 15, "一点", "一刻"],
      [1, 20, "一点", "过二十分"],
      [1, 25, "快到", "一点半咯"],
      [1, 30, "一点半", ""],
      [1, 35, "一点", "三十五分"],
      [1, 40, "差二十分钟", "两点"],
      [1, 45, "差一刻", "两点"],
      [1, 50, "差十分钟", "两点"],
      [1, 55, "差五分钟", "两点"],
      [11, 40, "差二十分钟", "十二点"],
      [23, 55, "差五分钟", "零点"]
    ];
    for (var i = 0; i < cases.size(); i++) {
      var c = cases[i];
      var cur = view.localize();
      var d = view.prepareStrings(c[0], c[1], cur, null);
      if (d[:middle] != c[2] || d[:bottom] != c[3]) {
        logger.warning("h=" + c[0] + " m=" + c[1] + " expect=[ " + c[2] + " | " + c[3] + " ] got=[ " + d[:middle] + " | " + d[:bottom] + " ]");
        return false;
      }
    }
    return true;
  }

  // 时间短语映射（特殊短语层：中午啦/半夜啦 单行）
  (:test)
  function testNoonMidnightSpecial(logger) {
    var view = new AboutTimeView();
    view.readLocale();
    var cur = view.localize();
    var d = view.prepareStrings(12, 0, cur, locale[:noon]);
    if (d[:middle] != "中午啦" || d[:bottom] != "") { return false; }
    d = view.prepareStrings(0, 0, cur, locale[:midnight]);
    if (d[:middle] != "半夜啦" || d[:bottom] != "") { return false; }
    return true;
  }

  // 猪猪时刻：工作日 + 特殊短语窗口 + 数字时间窗口 + 周末不触发
  (:test)
  function testPiggyState(logger) {
    var view = new AboutTimeView();
    var s;
    s = view.piggyState(8, 20, 5);  // 周五 8:20
    if (s[:special] != "workIn") { logger.warning("8:20 Fri special=" + s[:special]); return false; }
    s = view.piggyState(8, 45, 5);  // 周五 8:45 -> 数字时间窗内
    if (s[:showDigital] != true || s[:special] != null) { return false; }
    s = view.piggyState(16, 45, 5); // 周五 16:45
    if (s[:special] != "workOff15" || !s[:showDigital]) { return false; }
    s = view.piggyState(17, 0, 5);  // 周五 17:00
    if (s[:special] != "workOff") { return false; }
    s = view.piggyState(15, 30, 5); // 非工作窗口
    if (s[:special] != null || s[:showDigital]) { return false; }
    s = view.piggyState(8, 20, 1);  // 周日 8:20 不触发
    if (s[:special] != null) { return false; }
    s = view.piggyState(16, 30, 5); // 16:30 数字时间窗口边界（含）
    if (!s[:showDigital]) { return false; }
    s = view.piggyState(17, 31, 5); // 17:31 出窗口
    if (s[:showDigital]) { return false; }
    return true;
  }
}
