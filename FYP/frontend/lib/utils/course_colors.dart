import 'package:flutter/material.dart';

class CourseColorItem {
  final Color primary;
  final Color background;
  final Color border;
  final String googleColorId; // Google Calendar colorId 1-11
  final String name;

  const CourseColorItem({
    required this.primary,
    required this.background,
    required this.border,
    required this.googleColorId,
    required this.name,
  });
}

class CourseColors {
  static const List<CourseColorItem> palette = [
    // 0: Blueberry / Sapphire Blue
    CourseColorItem(
      primary: Color(0xFF3B82F6),
      background: Color(0x1F3B82F6),
      border: Color(0x663B82F6),
      googleColorId: "9",
      name: "Sapphire Blue",
    ),
    // 1: Basil / Emerald Green
    CourseColorItem(
      primary: Color(0xFF10B981),
      background: Color(0x1F10B981),
      border: Color(0x6610B981),
      googleColorId: "10",
      name: "Emerald Green",
    ),
    // 2: Grape / Electric Purple
    CourseColorItem(
      primary: Color(0xFF8B5CF6),
      background: Color(0x1F8B5CF6),
      border: Color(0x668B5CF6),
      googleColorId: "3",
      name: "Electric Purple",
    ),
    // 3: Tangerine / Amber Orange
    CourseColorItem(
      primary: Color(0xFFF59E0B),
      background: Color(0x1FF59E0B),
      border: Color(0x66F59E0B),
      googleColorId: "6",
      name: "Amber Orange",
    ),
    // 4: Flamingo / Rose Pink
    CourseColorItem(
      primary: Color(0xFFEC4899),
      background: Color(0x1FEC4899),
      border: Color(0x66EC4899),
      googleColorId: "4",
      name: "Rose Pink",
    ),
    // 5: Peacock / Cyan Teal
    CourseColorItem(
      primary: Color(0xFF06B6D4),
      background: Color(0x1F06B6D4),
      border: Color(0x6606B6D4),
      googleColorId: "7",
      name: "Cyan Teal",
    ),
    // 6: Tomato / Coral Red
    CourseColorItem(
      primary: Color(0xFFEF4444),
      background: Color(0x1FEF4444),
      border: Color(0x66EF4444),
      googleColorId: "11",
      name: "Coral Red",
    ),
    // 7: Lavender / Indigo
    CourseColorItem(
      primary: Color(0xFF6366F1),
      background: Color(0x1F6366F1),
      border: Color(0x666366F1),
      googleColorId: "1",
      name: "Lavender Indigo",
    ),
  ];

  /// Get color item by index
  static CourseColorItem getByIndex(int index) {
    return palette[index % palette.length];
  }

  /// Get deterministic color item by courseId string (e.g. "UCCD1024")
  static CourseColorItem getByCourseId(String courseId) {
    if (courseId.isEmpty) return palette[0];
    int hash = 0;
    for (int i = 0; i < courseId.length; i++) {
      hash = (hash * 31 + courseId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }
}
