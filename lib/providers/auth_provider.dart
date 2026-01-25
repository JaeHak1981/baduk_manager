import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// 인증 상태 관리 Provider
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  /// 현재 로그인된 사용자
  UserModel? get currentUser => _currentUser;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 로그인 여부
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _init();
  }

  /// 초기화 - 인증 상태 변경 리스너 등록
  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        // 로그인된 경우 Firestore에서 사용자 정보 가져오기
        _currentUser = await _authService.getUserData(
          user.uid,
          email: user.email,
        );
      } else {
        // 로그아웃된 경우
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  /// 개발자 계정 생성
  Future<void> createDeveloperAccount({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.createDeveloperAccount(
        email: email,
        password: password,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// 이메일/비밀번호 로그인
  Future<void> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// 에러 메시지 설정
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 에러 메시지 초기화
  void _clearError() {
    _errorMessage = null;
  }
}
