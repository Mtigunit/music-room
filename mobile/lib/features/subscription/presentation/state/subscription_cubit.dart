import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';

const _validTiers = {'BASIC', 'PREMIUM'};

String _normalizeTier(String? raw) {
  if (raw == null) return 'BASIC';
  final upper = raw.toUpperCase();
  return _validTiers.contains(upper) ? upper : 'BASIC';
}

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const SubscriptionInitial());

  final ApiClient _apiClient;
  int _loadToken = 0;

  /// Fetch the current user's subscription tier from the profile endpoint.
  Future<void> loadSubscription() async {
    final token = ++_loadToken;
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConfig.myProfileEndpoint,
      );
      if (isClosed || token != _loadToken) return;
      final body = response.data;
      final tier = _normalizeTier(body?['subscriptionTier'] as String?);
      emit(SubscriptionLoaded(tier: tier));
    } on Object {
      if (isClosed || token != _loadToken) return;
      emit(const SubscriptionLoaded(tier: 'BASIC'));
    }
  }

  /// Update the local state after a subscription mutation succeeds.
  void updateTier(String tier) {
    emit(SubscriptionLoaded(tier: _normalizeTier(tier)));
  }

  /// Reset to initial state on logout.
  void reset() {
    _loadToken++;
    emit(const SubscriptionInitial());
  }
}

abstract class SubscriptionState {
  const SubscriptionState();
}

class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

class SubscriptionLoaded extends SubscriptionState {
  const SubscriptionLoaded({required this.tier});

  final String tier;

  bool get isPremium => tier.toUpperCase() == 'PREMIUM';
  bool get isBasic => tier.toUpperCase() == 'BASIC';
}
