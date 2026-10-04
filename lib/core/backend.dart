import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';

class SchoolBackend {
  const SchoolBackend(this.client);
  final SupabaseClient client;
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publicKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get configured => url.isNotEmpty && publicKey.isNotEmpty;
  Future<SchoolUser> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    try {
      return await currentProfile();
    } catch (_) {
      await client.auth.signOut();
      rethrow;
    }
  }

  Future<SchoolUser> currentProfile() async {
    final row = await client
        .from('school_members')
        .select()
        .eq('user_id', client.auth.currentUser!.id)
        .single();
    return SchoolUser.fromJson(row);
  }

  Future<List<SchoolRecord>> load() async {
    final rows = await client.rpc('load_school_records');
    return (rows as List)
        .map((r) => SchoolRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<SchoolRecord>> save(List<SchoolRecord> records) async {
    final rows = await client
        .from('school_records')
        .upsert(records.map((r) => r.toJson()).toList())
        .select();
    return rows.map(SchoolRecord.fromJson).toList();
  }

  Future<SchoolRecord> reviewAttempt(
    SchoolRecord attempt,
    Map<String, num> marks,
    String feedback,
    bool publish,
  ) async {
    final row = await client.rpc(
      'review_attempt',
      params: {
        'attempt_id': attempt.id,
        'written_marks': marks,
        'teacher_feedback': feedback,
        'publish_result': publish,
      },
    );
    return SchoolRecord.fromJson(Map<String, dynamic>.from(row));
  }

  Future<SchoolRecord> examAction(
    String action,
    String examId, [
    Map<String, dynamic>? answers,
  ]) async {
    final row = await client.rpc(
      'exam_action',
      params: {
        'action_name': action,
        'exam_id': examId,
        'submitted_answers': answers ?? {},
      },
    );
    return SchoolRecord.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> createExam(
    SchoolRecord exam,
    Map<String, int> keys, {
    bool saveToBank = false,
  }) async {
    await client.rpc(
      'create_exam',
      params: {
        'exam_record': exam.toJson(),
        'answer_keys': keys,
        'save_bank': saveToBank,
      },
    );
  }

  Future<void> notifyUpdates(List<SchoolRecord> records) async {
    if (!const bool.fromEnvironment('ENABLE_PUSH')) return;
    for (final r in records.where(
      (r) => [
        'attendance',
        'mark',
        'attempt',
        'homework',
        'exam',
        'notice',
        'resource',
        'leave',
      ].contains(r.kind),
    )) {
      if (['mark', 'attempt'].contains(r.kind) && !r.flag('published')) {
        continue;
      }
      final response = await client.functions.invoke(
        'send-notification',
        body: {'record_id': r.id},
      );
      if (response.status >= 400) {
        throw StateError(
          'A record was saved, but its notification could not be delivered.',
        );
      }
    }
  }

  Future<void> registerNotifications() async {
    if (kIsWeb || !const bool.fromEnvironment('ENABLE_PUSH')) {
      throw StateError(
        'Push notifications need a configured Android or iOS build.',
      );
    }
    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) {
      await client.from('device_tokens').upsert({
        'user_id': client.auth.currentUser!.id,
        'token': token,
      }, onConflict: 'user_id,token');
    }
  }
}
