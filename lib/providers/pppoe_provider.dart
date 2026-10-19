import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/pppoe_user.dart';
import 'connection_provider.dart';

/// Reads and manages PPPoE secrets through the active RouterOS REST session.
class PppoeProvider with ChangeNotifier {
  ConnectionProvider _connectionProvider;

  List<PppoeUser> _users = [];
  bool _isLoading = false;
  bool _disposed = false;
  String _errorMessage = '';

  PppoeProvider(this._connectionProvider);

  void updateConnectionProvider(ConnectionProvider connectionProvider) {
    if (identical(_connectionProvider, connectionProvider)) return;
    _connectionProvider = connectionProvider;
  }

  List<PppoeUser> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> fetchUsers() async {
    final dio = _connectionProvider.dio;
    if (dio == null) {
      _errorMessage = 'اتصل بالراوتر أولاً.';
      _safeNotifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    _safeNotifyListeners();

    try {
      final response = await dio.get<dynamic>('/ppp/secret');
      if (response.statusCode == 200 && response.data is List) {
        final items = response.data as List<dynamic>;
        _users = items
            .whereType<Map>()
            .map((item) => PppoeUser.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false);
      } else {
        _errorMessage = 'استجابة غير متوقعة من الراوتر عند جلب مشتركي PPPoE.';
      }
    } on DioException catch (error) {
      _errorMessage = _messageForDioError(error);
      debugPrint('PPPoE fetch failed: HTTP ${error.response?.statusCode ?? 'no response'}');
    } catch (error) {
      _errorMessage = 'تعذر قراءة قائمة مشتركي PPPoE.';
      debugPrint('PPPoE fetch failed: $error');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Toggles a secret's disabled flag. currentState is the current disabled value.
  Future<bool> toggleUserStatus(String id, bool currentState) async {
    final dio = _connectionProvider.dio;
    if (dio == null || id.trim().isEmpty) {
      _errorMessage = dio == null ? 'اتصل بالراوتر أولاً.' : 'معرّف المشترك غير صالح.';
      _safeNotifyListeners();
      return false;
    }

    try {
      _errorMessage = '';
      final encodedId = Uri.encodeComponent(id.trim());
      await dio.patch<dynamic>(
        '/ppp/secret/$encodedId',
        data: <String, dynamic>{'disabled': (!currentState).toString()},
      );
      await fetchUsers();
      return _errorMessage.isEmpty;
    } on DioException catch (error) {
      _errorMessage = _messageForDioError(error);
      debugPrint('PPPoE status update failed: HTTP ${error.response?.statusCode ?? 'no response'}');
      _safeNotifyListeners();
      return false;
    } catch (error) {
      _errorMessage = 'تعذر تغيير حالة المشترك.';
      debugPrint('PPPoE status update failed: $error');
      _safeNotifyListeners();
      return false;
    }
  }

  Future<bool> addUser(String name, String password, String profile) async {
    final dio = _connectionProvider.dio;
    if (dio == null) {
      _errorMessage = 'اتصل بالراوتر أولاً.';
      _safeNotifyListeners();
      return false;
    }

    final cleanName = name.trim();
    final cleanProfile = profile.trim();
    if (cleanName.isEmpty || password.isEmpty || cleanProfile.isEmpty) {
      _errorMessage = 'أدخل اسم المستخدم وكلمة المرور والباقة.';
      _safeNotifyListeners();
      return false;
    }

    try {
      _errorMessage = '';
      await dio.put<dynamic>(
        '/ppp/secret',
        data: <String, dynamic>{
          'name': cleanName,
          'password': password,
          'profile': cleanProfile,
          'service': 'pppoe',
        },
      );
      await fetchUsers();
      return _errorMessage.isEmpty;
    } on DioException catch (error) {
      _errorMessage = _messageForDioError(error);
      debugPrint('PPPoE user creation failed: HTTP ${error.response?.statusCode ?? 'no response'}');
      _safeNotifyListeners();
      return false;
    } catch (error) {
      _errorMessage = 'تعذر إضافة مشترك PPPoE.';
      debugPrint('PPPoE user creation failed: $error');
      _safeNotifyListeners();
      return false;
    }
  }

  String _messageForDioError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'رفض الراوتر العملية؛ تحقق من بيانات الدخول وصلاحيات المستخدم.';
    }
    if (status == 404) {
      return 'لم يعثر الراوتر على المشترك أو مسار API المطلوب.';
    }
    if (status != null) {
      return 'فشلت العملية على الراوتر (HTTP $status).';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'انتهت مهلة الاتصال بالراوتر.';
    }
    return 'تعذر الوصول إلى الراوتر؛ تحقق من الاتصال.';
  }

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
