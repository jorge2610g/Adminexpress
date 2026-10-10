import 'package:flutter/material.dart';

/// Visual tokens for the Admin Express redesign.
///
/// Keep this file presentation-only. Business rules, environment guards,
/// Supabase calls and permissions must not depend on these values.
abstract final class AdminColors {
  static const bg = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8FAFC);
  static const border = Color(0xFFDDE6F0);
  static const borderStrong = Color(0xFFD0D5DD);
  static const divider = Color(0xFFEEF1F5);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF98A2B3);
  static const sidebar = Color(0xFF0B1424);
  static const sidebarSoft = Color(0xFF142037);
  static const sidebarActive = Color(0xFF1B2B47);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEAF2FF);
  static const cyan = Color(0xFF22D3EE);
  static const ok = Color(0xFF14804A);
  static const okSoft = Color(0xFFE8F8EF);
  static const warn = Color(0xFFB54708);
  static const warnSoft = Color(0xFFFFF7E6);
  static const danger = Color(0xFFD92D20);
  static const dangerSoft = Color(0xFFFFE4E8);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFEDE5FF);
  static const orange = Color(0xFFD97706);
  static const orangeSoft = Color(0xFFFFEED0);
}

abstract final class AdminSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AdminRadius {
  static const control = 10.0;
  static const card = 16.0;
  static const hero = 20.0;
  static const pill = 999.0;
}

abstract final class AdminBreakpoints {
  static const phone = 600.0;
  static const tablet = 1024.0;
  static const compactNavigation = 1180.0;
}

abstract final class AdminText {
  static const pageTitle = TextStyle(
    color: AdminColors.ink,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    letterSpacing: -.3,
  );

  static const sectionTitle = TextStyle(
    color: AdminColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  static const body = TextStyle(
    color: AdminColors.ink,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const muted = TextStyle(
    color: AdminColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const label = TextStyle(
    color: AdminColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}
