import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ucp/teachers/teacher_models.dart';
import 'package:ucp/teachers/teacher_service.dart';
import 'package:ucp/screens/teachers.dart';
import 'package:ucp/theme/palette.dart';
import 'package:ucp/widgets/common.dart';

void main() {
  group('Teacher models', () {
    test('fromJson parses parsed scrape shape', () {
      final t = Teacher.fromJson({
        'slug': 'usman-aamer',
        'name': 'Usman Aamer',
        'designation': 'Lecturer',
        'department_code': 'foit',
        'department_name': 'Faculty of Information and Technology',
        'department_id': 3,
        'image_url': 'https://ucp.edu.pk/x.jpg',
        'overall_rating': 4.7,
        'review_count': 50,
        'grading_pct': 94,
        'leniency_pct': 94,
        'subject_pct': 94,
        'avg_grading': 4.7,
        'avg_leniency': 4.7,
        'avg_subject': 4.7,
      });
      expect(t.slug, 'usman-aamer');
      expect(t.overallRating, 4.7);
      expect(t.gradingPct, 94);
    });

    test('review average is mean of 3 dims', () {
      const r = TeacherReview(
        id: 1,
        teacherSlug: 'usman-aamer',
        studentName: 'Coco Luna',
        comment: 'Great Sir',
        ratingGrading: 3,
        ratingLeniency: 3,
        ratingSubject: 5,
      );
      expect(r.average.toStringAsFixed(2), '3.67');
    });
  });

  group('FakeTeacherService', () {
    test('filters by dept and query', () async {
      final svc = FakeTeacherService();
      final all = await svc.fetchTeachers();
      expect(all.length, 3);
      final foit = await svc.fetchTeachers(dept: 'foit');
      expect(foit.length, 3);
      final fol = await svc.fetchTeachers(dept: 'fol');
      expect(fol, isEmpty);
      final q = await svc.fetchTeachers(query: 'usman');
      expect(q.length, 1);
      svc.dispose();
    });

    test('submitRating prepends review', () async {
      final svc = FakeTeacherService();
      await svc.submitRating(
        slug: 'usman-aamer',
        grading: 5,
        leniency: 5,
        subject: 5,
        comment: 'Nice',
      );
      final (_, reviews) = await svc.fetchDetail('usman-aamer');
      expect(reviews.first.comment, 'Nice');
      svc.dispose();
    });
  });

  group('NodeTeacherService (mocked backend)', () {
    NodeTeacherService service(MockClient client) => NodeTeacherService(
          baseUrl: 'https://api.test',
          sessionOf: () => 'sid-1',
          client: client,
        );

    test('list + detail map JSON', () async {
      final svc = service(MockClient((req) async {
        expect(req.headers['x-ucp-session'], 'sid-1');
        if (req.url.path == '/api/teachers') {
          return http.Response(
            '{"teachers":[{"slug":"usman-aamer","name":"Usman Aamer",'
            '"designation":"Lecturer","department_code":"foit",'
            '"overall_rating":4.7,"review_count":50,"grading_pct":94,'
            '"leniency_pct":94,"subject_pct":94}]}',
            200,
          );
        }
        return http.Response(
          '{"teacher":{"slug":"usman-aamer","name":"Usman Aamer",'
          '"overall_rating":4.7,"review_count":1},'
          '"reviews":[{"id":1,"teacher_slug":"usman-aamer",'
          '"student_name":"Coco","comment":"Great",'
          '"rating_grading":5,"rating_leniency":5,"rating_subject":5}]}',
          200,
        );
      }));
      final list = await svc.fetchTeachers();
      expect(list.first.name, 'Usman Aamer');
      final (teacher, reviews) = await svc.fetchDetail('usman-aamer');
      expect(teacher.slug, 'usman-aamer');
      expect(reviews.first.comment, 'Great');
      svc.dispose();
    });

    test('server error surfaces message', () async {
      final svc = service(MockClient((_) async => http.Response(
            '{"error":"teacher not found"}',
            404,
          )));
      await expectLater(
        svc.fetchDetail('nope'),
        throwsA(isA<TeacherException>().having(
          (e) => e.message,
          'message',
          contains('teacher not found'),
        )),
      );
      svc.dispose();
    });
  });

  group('TeachersScreen', () {
    testWidgets('null service shows setup notice', (tester) async {
      final colors = AppColors.of(AppPalette.skater, false);
      await tester.pumpWidget(
        AppScope(
          colors: colors,
          palette: AppPalette.skater,
          child: const MaterialApp(
            home: Scaffold(body: TeachersScreen(service: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teacher backend not connected'), findsOneWidget);
      expect(find.text('Teachers'), findsOneWidget);
    });

    testWidgets('fake service renders photo cards + dials', (tester) async {
      final colors = AppColors.of(AppPalette.skater, false);
      final svc = FakeTeacherService();
      await tester.pumpWidget(
        AppScope(
          colors: colors,
          palette: AppPalette.skater,
          child: MaterialApp(
            home: Scaffold(
              body: TeachersScreen(service: svc, myEmail: 't@ucp.edu.pk'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Usman Aamer'), findsWidgets);
      expect(find.textContaining('G 94%'), findsWidgets);
      svc.dispose();
    });
  });
}
