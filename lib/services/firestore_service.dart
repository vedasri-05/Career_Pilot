import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/job_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // USER PROFILE
  // ============================================================

  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return UserModel.fromMap(document.data()!);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // ============================================================
  // SAVED JOBS
  // ============================================================

  CollectionReference<Map<String, dynamic>> _savedJobsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_jobs');
  }

  Future<void> saveJob(String uid, JobModel job) async {
    final jobMap = job.toMap();
    jobMap['isSaved'] = true;
    jobMap['savedAt'] = DateTime.now().toIso8601String();
    await _savedJobsRef(uid).doc(job.id).set(jobMap);
  }

  Future<void> removeSavedJob(String uid, String jobId) async {
    await _savedJobsRef(uid).doc(jobId).delete();
  }

  Future<bool> isJobSaved(String uid, String jobId) async {
    final doc = await _savedJobsRef(uid).doc(jobId).get();
    return doc.exists;
  }

  Stream<List<JobModel>> getSavedJobsStream(String uid) {
    return _savedJobsRef(uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => JobModel.fromMap(doc.data())).toList(),
        );
  }

  Future<List<JobModel>> getSavedJobs(String uid) async {
    final snapshot = await _savedJobsRef(uid).get();
    return snapshot.docs.map((doc) => JobModel.fromMap(doc.data())).toList();
  }

  // ============================================================
  // CAREER ROADMAP
  // ============================================================

  DocumentReference<Map<String, dynamic>> _roadmapRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('roadmap')
        .doc('current');
  }

  Future<void> saveRoadmap(String uid, Map<String, dynamic> roadmapData) async {
    roadmapData['updatedAt'] = DateTime.now().toIso8601String();
    await _roadmapRef(uid).set(roadmapData, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getSavedRoadmap(String uid) async {
    final doc = await _roadmapRef(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return doc.data();
  }

  // ============================================================
  // MOCK INTERVIEWS
  // ============================================================

  CollectionReference<Map<String, dynamic>> _mockInterviewsRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('mock_interviews');
  }

  Future<void> saveMockInterview(
    String uid,
    String interviewId,
    Map<String, dynamic> interviewData,
  ) async {
    await _mockInterviewsRef(uid).doc(interviewId).set(interviewData);
  }

  Stream<List<Map<String, dynamic>>> getMockInterviewsStream(String uid) {
    return _mockInterviewsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getMockInterviews(String uid) async {
    final snapshot = await _mockInterviewsRef(
      uid,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
