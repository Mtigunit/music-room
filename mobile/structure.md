music-room/
    .....
    mobile
│  ├─ lib/
│  │  ├─ core/
│  │  │  ├─ config/
│  │  │  │  └─ app_config.dart
│  │  │  ├─ error/
│  │  │  │  ├─ app_exception.dart
│  │  │  │  └─ failure.dart
│  │  │  ├─ network/
│  │  │  │  └─ api_client.dart
│  │  │  ├─ realtime/
│  │  │  │  ├─ socket_client.dart
│  │  │  │  └─ socket_events.dart
│  │  │  ├─ services/
│  │  │  │  ├─ onboarding_service.dart
│  │  │  │  └─ storage_service.dart
│  │  │  ├─ theme/
│  │  │  │  └─ app_theme.dart
│  │  │  ├─ utils/
│  │  │  │  └─ logger.dart
│  │  │  └─ widgets/
│  │  │     ├─ app_scaffold.dart
│  │  │     ├─ feature_chip.dart
│  │  │     ├─ page_indicator.dart
│  │  │     └─ primary_button.dart
│  │  ├─ di/
│  │  │  └─ injection_container.dart
│  │  ├─ features/
│  │  │  ├─ auth/
│  │  │  │  ├─ data/
│  │  │  │  │  ├─ datasources/
│  │  │  │  │  │  └─ auth_remote_datasource.dart
│  │  │  │  │  ├─ models/
│  │  │  │  │  │  └─ auth_model.dart
│  │  │  │  │  └─ repositories/
│  │  │  │  │     └─ auth_repository_impl.dart
│  │  │  │  ├─ domain/
│  │  │  │  │  ├─ entities/
│  │  │  │  │  │  └─ auth_entity.dart
│  │  │  │  │  ├─ repositories/
│  │  │  │  │  │  └─ auth_repository.dart
│  │  │  │  │  └─ usecases/
│  │  │  │  │     └─ auth_usecase.dart
│  │  │  │  └─ presentation/
│  │  │  │     ├─ pages/
│  │  │  │     │  ├─ auth_page.dart
│  │  │  │     │  ├─ forgot_password_page.dart
│  │  │  │     │  ├─ onboarding_page.dart
│  │  │  │     │  ├─ sign_in_page.dart
│  │  │  │     │  └─ sign_up_page.dart
│  │  │  │     ├─ state/
│  │  │  │     │  ├─ auth_bloc.dart
│  │  │  │     │  ├─ auth_event.dart
│  │  │  │     │  └─ auth_state.dart
│  │  │  │     └─ widgets/
│  │  │  │        ├─ auth_text_input_field.dart
│  │  │  │        ├─ auth_view.dart
│  │  │  │        ├─ onboarding_slide.dart
│  │  │  │        ├─ otp_verification_modal.dart
│  │  │  │        └─ social_login_button.dart
│  │  │  ├─ home/
│  │  │  │  ├─ data/
│  │  │  │  │  ├─ datasources/
│  │  │  │  │  │  └─ home_remote_datasource.dart
│  │  │  │  │  ├─ models/
│  │  │  │  │  │  └─ home_model.dart
│  │  │  │  │  └─ repositories/
│  │  │  │  │     └─ home_repository_impl.dart
│  │  │  │  ├─ domain/
│  │  │  │  │  ├─ entities/
│  │  │  │  │  │  └─ home_entity.dart
│  │  │  │  │  ├─ repositories/
│  │  │  │  │  │  └─ home_repository.dart
│  │  │  │  │  └─ usecases/
│  │  │  │  │     └─ home_usecase.dart
│  │  │  │  └─ presentation/
│  │  │  │     ├─ pages/
│  │  │  │     │  └─ home_page.dart
│  │  │  │     ├─ state/
│  │  │  │     │  ├─ home_bloc.dart
│  │  │  │     │  ├─ home_event.dart
│  │  │  │     │  └─ home_state.dart
│  │  │  │     └─ widgets/
│  │  │  │        └─ home_view.dart
│  │  │  ├─ music_control/
│  │  │  │  ├─ data/
│  │  │  │  │  ├─ datasources/
│  │  │  │  │  │  └─ music_control_remote_datasource.dart
│  │  │  │  │  ├─ models/
│  │  │  │  │  │  └─ music_control_model.dart
│  │  │  │  │  └─ repositories/
│  │  │  │  │     └─ music_control_repository_impl.dart
│  │  │  │  ├─ domain/
│  │  │  │  │  ├─ entities/
│  │  │  │  │  │  └─ music_control_entity.dart
│  │  │  │  │  ├─ repositories/
│  │  │  │  │  │  └─ music_control_repository.dart
│  │  │  │  │  └─ usecases/
│  │  │  │  │     └─ music_control_usecase.dart
│  │  │  │  └─ presentation/
│  │  │  │     ├─ pages/
│  │  │  │     │  └─ music_control_page.dart
│  │  │  │     ├─ state/
│  │  │  │     │  ├─ music_control_bloc.dart
│  │  │  │     │  ├─ music_control_event.dart
│  │  │  │     │  └─ music_control_state.dart
│  │  │  │     └─ widgets/
│  │  │  │        └─ music_control_view.dart
│  │  │  ├─ music_vote/
│  │  │  │  ├─ data/
│  │  │  │  │  ├─ datasources/
│  │  │  │  │  │  └─ music_vote_remote_datasource.dart
│  │  │  │  │  ├─ models/
│  │  │  │  │  │  └─ music_vote_model.dart
│  │  │  │  │  └─ repositories/
│  │  │  │  │     └─ music_vote_repository_impl.dart
│  │  │  │  ├─ domain/
│  │  │  │  │  ├─ entities/
│  │  │  │  │  │  └─ music_vote_entity.dart
│  │  │  │  │  ├─ repositories/
│  │  │  │  │  │  └─ music_vote_repository.dart
│  │  │  │  │  └─ usecases/
│  │  │  │  │     └─ music_vote_usecase.dart
│  │  │  │  └─ presentation/
│  │  │  │     ├─ pages/
│  │  │  │     │  └─ music_vote_page.dart
│  │  │  │     ├─ state/
│  │  │  │     │  ├─ music_vote_bloc.dart
│  │  │  │     │  ├─ music_vote_event.dart
│  │  │  │     │  └─ music_vote_state.dart
│  │  │  │     └─ widgets/
│  │  │  │        └─ music_vote_view.dart
│  │  │  ├─ playlist/
│  │  │  │  ├─ data/
│  │  │  │  │  ├─ datasources/
│  │  │  │  │  │  └─ playlist_remote_datasource.dart
│  │  │  │  │  ├─ models/
│  │  │  │  │  │  └─ playlist_model.dart
│  │  │  │  │  └─ repositories/
│  │  │  │  │     └─ playlist_repository_impl.dart
│  │  │  │  ├─ domain/
│  │  │  │  │  ├─ entities/
│  │  │  │  │  │  └─ playlist_entity.dart
│  │  │  │  │  ├─ repositories/
│  │  │  │  │  │  └─ playlist_repository.dart
│  │  │  │  │  └─ usecases/
│  │  │  │  │     └─ playlist_usecase.dart
│  │  │  │  └─ presentation/
│  │  │  │     ├─ pages/
│  │  │  │     │  └─ playlist_page.dart
│  │  │  │     ├─ state/
│  │  │  │     │  ├─ playlist_bloc.dart
│  │  │  │     │  ├─ playlist_event.dart
│  │  │  │     │  └─ playlist_state.dart
│  │  │  │     └─ widgets/
│  │  │  │        └─ playlist_view.dart
│  │  │  └─ profile/
│  │  │     ├─ data/
│  │  │     │  ├─ datasources/
│  │  │     │  │  └─ profile_remote_datasource.dart
│  │  │     │  ├─ models/
│  │  │     │  │  └─ profile_model.dart
│  │  │     │  └─ repositories/
│  │  │     │     └─ profile_repository_impl.dart
│  │  │     ├─ domain/
│  │  │     │  ├─ entities/
│  │  │     │  │  └─ profile_entity.dart
│  │  │     │  ├─ repositories/
│  │  │     │  │  └─ profile_repository.dart
│  │  │     │  └─ usecases/
│  │  │     │     └─ profile_usecase.dart
│  │  │     └─ presentation/
│  │  │        ├─ pages/
│  │  │        │  └─ profile_page.dart
│  │  │        ├─ state/
│  │  │        │  ├─ profile_bloc.dart
│  │  │        │  ├─ profile_event.dart
│  │  │        │  └─ profile_state.dart
│  │  │        └─ widgets/
│  │  │           └─ profile_view.dart
│  │  ├─ routes/
│  │  │  ├─ app_router.dart
│  │  │  └─ route_names.dart
│  │  ├─ app.dart
│  │  └─ main.dart
│  ├─ test/
│  │  └─ .gitkeep
│  ├─ web/
│  │  ├─ icons/
│  │  │  ├─ Icon-192.png
│  │  │  ├─ Icon-512.png
│  │  │  ├─ Icon-maskable-192.png
│  │  │  └─ Icon-maskable-512.png
│  │  ├─ favicon.png
│  │  ├─ index.html
│  │  └─ manifest.json
│  ├─ .flutter-plugins-dependencies
│  ├─ .gitignore
│  ├─ .metadata
│  ├─ analysis_options.yaml
│  ├─ pubspec.lock
│  ├─ pubspec.yaml
│  ├─ README.md
│  └─ structure.md

