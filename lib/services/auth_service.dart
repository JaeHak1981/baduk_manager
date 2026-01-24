import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Firebase Authentication 서비스
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;

  /// 인증 상태 변경 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 개발자 계정 생성
  ///
  /// [email] 개발자 이메일
  /// [password] 비밀번호
  ///
  /// Returns: 생성된 UserModel
  /// Throws: Exception with detailed error message
  Future<UserModel> createDeveloperAccount({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase Authentication에 사용자 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('사용자 생성 실패');
      }

      // Firestore에 사용자 정보 저장
      final userModel = UserModel(
        uid: user.uid,
        email: email,
        role: UserRole.developer,
        createdAt: DateTime.now(),
      );

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toFirestore());
      } catch (firestoreError) {
        // Firestore 저장 실패 시 더 자세한 에러 메시지
        throw Exception(
          'Firestore 저장 실패: $firestoreError\n\n'
          'Firebase Console에서 Firestore Database를 활성화해주세요.\n'
          '1. Build → Firestore Database\n'
          '2. 데이터베이스 만들기 (테스트 모드)',
        );
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException during account creation: ${e.code}, ${e.message}',
      );
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected error during account creation: $e');
      throw Exception('계정 생성 중 오류 발생: $e');
    }
  }

  /// 이메일/비밀번호 로그인
  ///
  /// [email] 이메일
  /// [password] 비밀번호
  ///
  /// Returns: UserModel
  /// Throws: FirebaseAuthException
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase Authentication 로그인
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('로그인 실패');
      }

      // Firestore에서 사용자 정보 가져오기
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      return UserModel.fromFirestore(userDoc);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException during sign in: ${e.code}, ${e.message}',
      );
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      throw Exception('로그인 중 오류 발생: $e');
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Firestore에서 사용자 정보 가져오기
  ///
  /// [uid] 사용자 UID
  ///
  /// Returns: UserModel 또는 null
  Future<UserModel?> getUserData(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return null;
      }

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      debugPrint('사용자 정보 가져오기 실패: $e');
      return null;
    }
  }

  /// FirebaseAuthException 처리
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'user-not-found':
        return '사용자를 찾을 수 없습니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      default:
        return '인증 오류: ${e.message ?? e.code}';
    }
  }
}
