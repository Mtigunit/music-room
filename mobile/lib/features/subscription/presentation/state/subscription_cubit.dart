import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({required ApiClient apiClient})
    : _apiClient = apiClient,
      super(const SubscriptionInitial());

  final ApiClient _apiClient;

  /// Fetch the current user's subscription tier from the profile endpoint.
  Future<void> loadSubscription() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConfig.myProfileEndpoint,
      );
      final body = response.data;
      final tier = body?['subscriptionTier'] as String?;
      if (tier != null) {
        emit(SubscriptionLoaded(tier: tier));
      } else {
        emit(const SubscriptionLoaded(tier: 'BASIC'));
      }
    } on Object {
      // Default to BASIC if we can't determine the tier.
      emit(const SubscriptionLoaded(tier: 'BASIC'));
    }
  }

  /// Update the local state after a subscription mutation succeeds.
  void updateTier(String tier) {
    emit(SubscriptionLoaded(tier: tier));
  }

  /// Reset to initial state on logout.
  void reset() {
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
