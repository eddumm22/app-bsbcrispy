import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/user_profile_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService, this._userProfileService) {
    _authSubscription = _authService.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final AuthService _authService;
  final UserProfileService _userProfileService;
  late final StreamSubscription<User?> _authSubscription;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _errorTimer;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print(
        'FirebaseAuthException (signIn): code=${e.code}, message=${e.message}, plugin=${e.plugin}',
      );
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          _setError('Usuário ou senha incorretos.');
          break;
        case 'invalid-email':
          _setError('Email inválido.');
          break;
        default:
          _setError('Não foi possível entrar. Tente novamente.');
      }
    } catch (_) {
      _setError('Não foi possível entrar. Tente novamente.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String gender,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;

      if (uid != null) {
        try {
          await _userProfileService.createUserProfile(
            uid: uid,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: gender,
            email: email,
          );
        } catch (e) {
          // ignore: avoid_print
          print('Erro ao salvar perfil no Firestore: $e');
        }
      }

      // Após cadastro bem-sucedido, encerra qualquer sessão automática
      // para forçar o usuário a fazer login manualmente.
      await _authService.signOut();

    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print(
        'FirebaseAuthException (register): code=${e.code}, message=${e.message}, plugin=${e.plugin}',
      );
      _setError(e.message ?? 'Falha ao cadastrar. Tente novamente.');
    } catch (_) {
      _setError('Falha ao cadastrar. Tente novamente.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signOut();
    } catch (_) {
      _setError('Falha ao sair. Tente novamente.');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();

    _errorTimer?.cancel();
    if (message != null) {
      _errorTimer = Timer(const Duration(seconds: 4), () {
        if (_errorMessage != null) {
          _errorMessage = null;
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }
}

