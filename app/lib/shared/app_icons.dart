import 'package:flutter/material.dart';

/// One glyph per concept, all from the Material *outlined* family so icons
/// share stroke weight and visual size everywhere. Use these instead of picking
/// `Icons.*` inline, so the same action always looks the same.
class AppIcons {
  AppIcons._();

  // Navigation tabs (outlined = unselected, filled = selected).
  static const home = Icons.home_outlined;
  static const homeSelected = Icons.home;
  static const academics = Icons.school_outlined;
  static const academicsSelected = Icons.school;
  static const finance = Icons.account_balance_wallet_outlined;
  static const financeSelected = Icons.account_balance_wallet;
  static const services = Icons.widgets_outlined;
  static const servicesSelected = Icons.widgets;

  // Academics.
  static const results = Icons.insights_outlined;
  static const attendance = Icons.fact_check_outlined;
  static const marks = Icons.assignment_outlined;
  static const grades = Icons.grading_outlined;
  static const routine = Icons.calendar_view_week_outlined;
  static const calendar = Icons.calendar_month_outlined;
  static const exams = Icons.event_note_outlined;
  static const notices = Icons.campaign_outlined;
  static const advising = Icons.playlist_add_check_outlined;
  static const sections = Icons.view_agenda_outlined;
  static const courseRequests = Icons.swap_horiz_outlined;
  static const fyp = Icons.groups_outlined;
  static const transcript = Icons.description_outlined;
  static const degree = Icons.workspace_premium_outlined;
  static const credits = Icons.library_books_outlined;
  static const course = Icons.menu_book_outlined;
  static const lab = Icons.science_outlined;

  // Finance.
  static const dues = Icons.receipt_outlined;
  static const payments = Icons.receipt_long_outlined;
  static const invoices = Icons.request_quote_outlined;
  static const pay = Icons.payment_outlined;
  static const installments = Icons.payments_outlined;
  static const waiver = Icons.percent_outlined;

  // Services / tools.
  static const gpaTool = Icons.calculate_outlined;
  static const tuitionTool = Icons.price_check_outlined;
  static const faculty = Icons.badge_outlined;
  static const transport = Icons.directions_bus_outlined;
  static const gym = Icons.fitness_center_outlined;
  static const evaluation = Icons.rate_review_outlined;
  static const password = Icons.lock_reset_outlined;
  static const simulator = Icons.auto_awesome_mosaic_outlined;

  // People / identity.
  static const profile = Icons.person_outline;
  static const advisor = Icons.support_agent_outlined;
  static const settings = Icons.settings_outlined;
  static const logout = Icons.logout;
  static const id = Icons.badge_outlined;
  static const email = Icons.mail_outline;
  static const phone = Icons.call_outlined;
  static const room = Icons.meeting_room_outlined;
  static const birthday = Icons.cake_outlined;
  static const bloodGroup = Icons.bloodtype_outlined;
  static const family = Icons.family_restroom_outlined;
  static const device = Icons.phone_android_outlined;
  static const seat = Icons.event_seat_outlined;

  // Actions.
  static const refresh = Icons.refresh;
  static const search = Icons.search;
  static const clear = Icons.close;
  static const add = Icons.add;
  static const remove = Icons.remove;
  static const chevron = Icons.chevron_right;
  static const chevronLeft = Icons.chevron_left;
  static const back = Icons.arrow_back;
  static const forward = Icons.arrow_forward;
  static const external = Icons.open_in_new;
  static const export = Icons.ios_share_outlined;
  static const download = Icons.download_outlined;
  static const expand = Icons.expand_more;
  static const filter = Icons.filter_list;
  static const check = Icons.check;
  static const selected = Icons.check_circle;
  static const unselected = Icons.radio_button_unchecked;
  static const visibility = Icons.visibility_outlined;
  static const visibilityOff = Icons.visibility_off_outlined;
  static const delete = Icons.delete_outline;
  static const reminder = Icons.notifications_outlined;
  static const reminderOn = Icons.notifications_active_outlined;
  static const time = Icons.schedule_outlined;
  static const today = Icons.today_outlined;
  static const upcoming = Icons.event_outlined;

  // Status.
  static const info = Icons.info_outline;
  static const success = Icons.check_circle_outline;
  static const warning = Icons.warning_amber_outlined;
  static const error = Icons.error_outline;
  static const offline = Icons.cloud_off_outlined;
  static const empty = Icons.inbox_outlined;
  static const locked = Icons.lock_outline;
  static const pending = Icons.hourglass_empty;
  static const server = Icons.dns_outlined;
  static const storage = Icons.sd_storage_outlined;
  static const appearance = Icons.palette_outlined;
  static const update = Icons.system_update_alt_outlined;
  static const code = Icons.code;
  static const link = Icons.link;
  static const privacy = Icons.shield_outlined;
  static const trendUp = Icons.trending_up;
  static const trendDown = Icons.trending_down;
  static const light = Icons.light_mode_outlined;
  static const dark = Icons.dark_mode_outlined;
  static const black = Icons.contrast;
}
