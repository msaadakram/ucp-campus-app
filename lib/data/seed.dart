import 'package:flutter/material.dart';

enum CourseTone { teal, clay, dust, board }

class Course {
  final String code;
  final String title;
  final String prof;
  final String room;
  final String time;
  final int credits;
  final int progress;
  final String grade;
  final CourseTone tone;
  const Course({
    required this.code, required this.title, required this.prof,
    required this.room, required this.time, required this.credits,
    required this.progress, required this.grade, required this.tone,
  });
}

const List<Course> courses = [
  Course(code: 'CS 214', title: 'Data Structures', prof: 'Dr. Amina Qureshi', room: 'Block C · 204', time: 'Mon · Wed 09:00', credits: 4, progress: 72, grade: 'A-', tone: CourseTone.teal),
  Course(code: 'MA 201', title: 'Linear Algebra', prof: 'Prof. Daniel Ruiz', room: 'Science Hall 11', time: 'Tue · Thu 11:30', credits: 3, progress: 58, grade: 'B+', tone: CourseTone.clay),
  Course(code: 'DS 150', title: 'Intro to Design Thinking', prof: 'Ms. Hana Ito', room: 'Studio 3', time: 'Fri 14:00', credits: 2, progress: 89, grade: 'A', tone: CourseTone.board),
  Course(code: 'EN 110', title: 'Academic Writing', prof: 'Dr. Leo Brandt', room: 'Arts 402', time: 'Wed 15:30', credits: 2, progress: 41, grade: 'B', tone: CourseTone.dust),
];

Color toneBg(CourseTone t, dynamic c) {
  if (t == CourseTone.teal) return c.teal as Color;
  if (t == CourseTone.clay) return c.clay as Color;
  if (t == CourseTone.board) return c.board as Color;
  return c.dust as Color;
}

Color toneFg(CourseTone t, dynamic c) {
  if (t == CourseTone.board) return c.tealInk as Color;
  return Colors.white;
}

// ---- Timetable ----
class Slot {
  final int day;
  final double start;
  final double end;
  final String code;
  final String kind;
  const Slot(this.day, this.start, this.end, this.code, this.kind);
}

const List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const List<String> dayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const List<Slot> slots = [
  Slot(0, 9, 10.5, 'CS 214', 'Lecture'), Slot(0, 13, 15, 'CS 214', 'Lab'),
  Slot(1, 11.5, 13, 'MA 201', 'Lecture'), Slot(1, 15, 16, 'MA 201', 'Tutorial'),
  Slot(2, 9, 10.5, 'CS 214', 'Lecture'), Slot(2, 15.5, 17, 'EN 110', 'Lecture'),
  Slot(3, 11.5, 13, 'MA 201', 'Lecture'), Slot(3, 14, 15, 'EN 110', 'Tutorial'),
  Slot(4, 10, 11, 'CS 214', 'Tutorial'), Slot(4, 14, 17, 'DS 150', 'Lab'),
];

String fmtHour(double h) {
  final hh = h.floor().toString().padLeft(2, '0');
  final mm = (h % 1 == 0) ? '00' : '30';
  return '$hh:$mm';
}

// ---- Leaderboard ----
class BoardEntry {
  final String name;
  final int score;
  final int streak;
  final int move;
  final bool me;
  const BoardEntry(this.name, this.score, this.streak, this.move, {this.me = false});
}

const List<String> lbNames = ['Sara Malik', 'Omar Khan', 'Hana Ito', 'Leo Brandt', 'Zainab Raza', 'Ali Hassan', 'Mina Park', 'Daniyal Shah', 'Aisha Noor', 'Ravi Patel', 'Emma Cole'];

List<BoardEntry> board(String code, String metric) {
  int s = (code + metric).split('').fold<int>(7, (n, ch) => (n * 31 + ch.codeUnitAt(0)) & 0xFFFFFFFF);
  int rnd() {
    s = ((s * 1103515245 + 12345) & 0xFFFFFFFF);
    return s % 1000;
  }
  final list = lbNames.map((name) {
    final score = 62 + (rnd() / 1000 * 36).round();
    final streak = (rnd() / 1000 * 14).round();
    final move = (rnd() / 1000 * 6 - 3).round();
    return BoardEntry(name, score, streak, move);
  }).toList();
  list.add(BoardEntry('Ayaan Warraich', 70 + (rnd() / 1000 * 24).round(), 6, 2, me: true));
  list.sort((a, b) => b.score.compareTo(a.score));
  return list;
}

// ---- Community ----
class CComment {
  final String id;
  final String author;
  final String text;
  final String time;
  int score;
  int vote;
  final List<CComment> replies;
  CComment({required this.id, required this.author, required this.text, required this.time, required this.score, this.vote = 0, List<CComment>? replies}) : replies = replies ?? [];
}

class Post {
  final String id;
  final String author;
  final String flair;
  final String title;
  final String body;
  final String time;
  final int age;
  int score;
  int vote;
  bool saved;
  final String? imageUrl;
  final List<CComment> comments;
  Post({required this.id, required this.author, required this.flair, required this.title, required this.body, required this.time, required this.age, required this.score, this.vote = 0, this.saved = false, this.imageUrl, List<CComment>? comments}) : comments = comments ?? [];
}

int countComments(List<CComment> cs) => cs.fold(0, (n, x) => n + 1 + countComments(x.replies));

// ---- Groups ----
class GroupInfo {
  final String name;
  final String last;
  final int unread;
  final String meta;
  final CourseTone tone;
  final bool joined;
  const GroupInfo({required this.name, required this.last, required this.unread, required this.meta, required this.tone, required this.joined});
}

const List<GroupInfo> groupList = [
  GroupInfo(name: 'DS Midterm Squad', last: 'Sara: Pinned the plan for this week', unread: 3, meta: 'CS 214 · 18 members', tone: CourseTone.teal, joined: true),
  GroupInfo(name: 'Linear Algebra Help', last: 'Omar: anyone got Q4 of the sheet?', unread: 0, meta: 'MA 201 · 42 members', tone: CourseTone.clay, joined: false),
  GroupInfo(name: 'Campus Skaters', last: 'Leo: session at the plaza 6pm', unread: 0, meta: 'Club · 27 members', tone: CourseTone.board, joined: false),
  GroupInfo(name: 'Design Studio Crew', last: 'Hana: moodboards due Friday!', unread: 1, meta: 'DS 150 · 12 members', tone: CourseTone.dust, joined: true),
];

// ---- Fee ----
class Challan {
  final String id;
  final String term;
  final String due;
  final List<MapEntry<String, int>> items;
  final String? paid;
  const Challan({required this.id, required this.term, required this.due, required this.items, this.paid});
}

int challanTotal(Challan c) => c.items.fold(0, (s, e) => s + e.value);

const Challan currentChallan = Challan(
  id: 'FC-2026-0918-4471', term: 'Fall 2026 · Installment 2', due: '15 Oct 2026',
  items: [MapEntry('Tuition fee (11 cr)', 88000), MapEntry('Lab charges', 6500), MapEntry('Library & IT', 3500), MapEntry('Student activities', 2000), MapEntry('Merit scholarship (−15%)', -13200)],
);

const List<Challan> challanHistory = [
  Challan(id: 'FC-2026-0801-3920', term: 'Fall 2026 · Installment 1', due: '20 Aug 2026', items: [MapEntry('Total', 86800)], paid: '18 Aug 2026'),
  Challan(id: 'FC-2026-0302-2218', term: 'Spring 2026 · Installment 2', due: '15 Mar 2026', items: [MapEntry('Total', 84300)], paid: '12 Mar 2026'),
  Challan(id: 'FC-2026-0110-1107', term: 'Spring 2026 · Installment 1', due: '20 Jan 2026', items: [MapEntry('Total', 84300)], paid: '24 Jan 2026 · late'),
];

String rs(int n) => 'Rs ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
