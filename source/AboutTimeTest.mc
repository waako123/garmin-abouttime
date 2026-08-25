using Toybox.System;
using Toybox.Test;

(:test)
class AboutTimeTest {

  // 时间短语模板：单行/两行结构 + 小时词来自资源（避免硬编码中文）
  (:test)
  function testTemplateStructure(logger) {
    var view = new AboutTimeView();
    view.readLocale();
    var single = [ [0,0], [12,0], [1,30] ];   // 整点/半点 -> 单行(middle 非空, bottom 空)
    for (var i = 0; i < single.size(); i++) {
      var c = single[i];
      var cur = view.localize();
      var d = view.prepareStrings(c[0], c[1], cur, null);
      if (d[:middle].length() == 0 || d[:bottom].length() != 0) {
        logger.warning("single fail h=" + c[0] + " m=" + c[1]);
        return false;
      }
    }
    var two = [ [1,5], [1,40], [11,25] ];     // 两行 -> middle 和 bottom 都非空
    for (var i = 0; i < two.size(); i++) {
      var c = two[i];
      var cur = view.localize();
      var d = view.prepareStrings(c[0], c[1], cur, null);
      if (d[:middle].length() == 0 || d[:bottom].length() == 0) {
        logger.warning("two fail h=" + c[0] + " m=" + c[1]);
        return false;
      }
    }
    // 0 点整 = 零点 + 整（小时词来自资源，验证替换正确）
    var cur2 = view.localize();
    var d0 = view.prepareStrings(0, 0, cur2, null);
    if (d0[:middle].find(cur2[:hourZeroWord]) != 0) { return false; }
    // 1 点=一点 出现在整点中
    var cur3 = view.localize();
    var d1 = view.prepareStrings(1, 0, cur3, null);
    if (d1[:middle].find(cur3[:hours][1]) != 0) { return false; }
    return true;
  }

  // 中午/半夜 整点特殊短语
  (:test)
  function testNoonMidnight(logger) {
    var view = new AboutTimeView();
    view.readLocale();
    var cur = view.localize();
    var d = view.prepareStrings(12, 0, cur, locale[:noon]);
    if (d[:middle].find(locale[:noon]) != 0) { return false; }
    d = view.prepareStrings(0, 0, cur, locale[:midnight]);
    if (d[:middle].find(locale[:midnight]) != 0) { return false; }
    return true;
  }

  // 猪猪时刻：工作日 + 特殊短语窗口 + 数字时间窗口 + 周末不触发
  (:test)
  function testPiggy(logger) {
    var view = new AboutTimeView();
    logger.warning("DBG piggyTime=" + (piggyTime ? "T" : "F"));
    var s;
    s = view.piggyState(8, 30, 5);   // 周五 8:30 上班打卡 + 数字时间
    logger.warning("DBG 8:30 special=[" + s[:special] + "] digital=[" + s[:showDigital] + "]");
    if (s[:special] != "workIn" || !s[:showDigital]) { return false; }
    s = view.piggyState(16, 45, 5);  // 16:45 差一刻下班 + 数字时间
    if (s[:special] != "workOff15" || !s[:showDigital]) { logger.warning("16:45"); return false; }
    s = view.piggyState(17, 0, 5);   // 17:00 下班！
    if (s[:special] != "workOff") { logger.warning("17:00"); return false; }
    s = view.piggyState(15, 30, 5);  // 非工作窗口
    if (s[:special] != null || s[:showDigital]) { logger.warning("15:30"); return false; }
    s = view.piggyState(8, 20, 1);   // 周日 不触发
    if (s[:special] != null) { logger.warning("sunday"); return false; }
    s = view.piggyState(17, 31, 5);  // 出数字时间窗口
    if (s[:showDigital]) { logger.warning("17:31"); return false; }
    return true;
  }
}
