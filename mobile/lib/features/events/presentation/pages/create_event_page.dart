import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';
import 'package:music_room/features/events/presentation/state/create_event_cubit.dart';
import 'package:music_room/features/events/presentation/validation/create_event_form_validator.dart';
import 'package:music_room/features/events/presentation/widgets/step_1_details.dart';
import 'package:music_room/features/events/presentation/widgets/step_2_genre.dart';
import 'package:music_room/features/events/presentation/widgets/step_3_music.dart';
import 'package:music_room/features/events/presentation/widgets/step_4_access.dart';
import 'package:music_room/routes/route_names.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final PageController _pageController = PageController();
  late final CreateEventCubit _createEventCubit;
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Global Form State
  String eventName = '';
  String eventDescription = '';
  XFile? eventCover;

  List<EventTag> selectedGenres = [];

  List<TrackModel> selectedTracks = []; // Use actual TrackModel

  String visibility = 'Public'; // Public, Private
  String votingRule = 'Everyone'; // Everyone, Invited Only, Location & Time

  EventLocation? allowedLocation;
  double allowedRadius = 10;
  bool isRestricted = false;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;
  DateTime scheduledStartTime = DateTime.now();

  bool _showValidationErrors = false;
  Map<String, String> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _createEventCubit = CreateEventCubit(
      remoteDataSource: InjectionContainer().eventRemoteDataSource,
    );
  }

  @override
  void dispose() {
    unawaited(_createEventCubit.close());
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Dismiss the soft keyboard before advancing so it doesn't linger
    // across steps regardless of which text field was last focused.
    FocusManager.instance.primaryFocus?.unfocus();

    if (_currentStep >= _totalSteps - 1) return;

    final stepValidation = CreateEventFormValidator.validateStep(
      _currentInput(),
      _currentStep,
    );
    if (!stepValidation.isValid) {
      setState(() {
        _showValidationErrors = true;
        _validationErrors = CreateEventFormValidator.validateForSubmit(
          _currentInput(),
        ).errors;
      });
      AppSnackbar.showError(
        context,
        stepValidation.firstError ?? 'Please check this step.',
      );
      return;
    }

    unawaited(
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  void _prevStep() {
    if (_currentStep > 0) {
      unawaited(
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _submitEvent() {
    FocusManager.instance.primaryFocus?.unfocus();

    final submitValidation = CreateEventFormValidator.validateForSubmit(
      _currentInput(),
    );
    if (!submitValidation.isValid) {
      setState(() {
        _showValidationErrors = true;
        _validationErrors = submitValidation.errors;
      });
      AppSnackbar.showError(
        context,
        submitValidation.firstError ?? 'Please check event details.',
      );
      return;
    }

    unawaited(
      _createEventCubit.submitEvent(
        name: eventName,
        description: eventDescription,
        coverImage: eventCover,
        selectedTags: selectedGenres,
        selectedTracks: selectedTracks,
        visibility: visibility,
        votingRule: votingRule,
        isRestricted: isRestricted,
        allowedLocation: allowedLocation,
        allowedRadius: allowedRadius,
        startDate: startDate,
        startTime: startTime,
        endDate: endDate,
        endTime: endTime,
        scheduledStartTime: scheduledStartTime,
      ),
    );
  }

  CreateEventFormInput _currentInput() {
    return CreateEventFormInput(
      name: eventName,
      description: eventDescription,
      selectedTags: selectedGenres,
      selectedTracks: selectedTracks,
      visibility: visibility,
      votingRule: votingRule,
      isRestricted: isRestricted,
      allowedLocation: allowedLocation,
      allowedRadius: allowedRadius,
      startDate: startDate,
      startTime: startTime,
      endDate: endDate,
      endTime: endTime,
      scheduledStartTime: scheduledStartTime,
    );
  }

  void _setFieldState(VoidCallback updater) {
    setState(() {
      updater();
      if (_showValidationErrors) {
        _validationErrors = CreateEventFormValidator.validateForSubmit(
          _currentInput(),
        ).errors;
      }
    });
  }

  String? _step4ValidationError(CreateEventFormInput input) {
    const keys = [
      CreateEventValidationField.visibility,
      CreateEventValidationField.allowedLocation,
      CreateEventValidationField.allowedRadius,
      CreateEventValidationField.accessWindow,
    ];

    final sourceErrors = _showValidationErrors
        ? _validationErrors
        : CreateEventFormValidator.validateStep(
            input,
            CreateEventFormValidator.accessStep,
          ).errors;

    for (final key in keys) {
      final error = sourceErrors[key];
      if (error != null) {
        return error;
      }
    }

    return null;
  }

  TextStyle _stepLabelStyle(int index, ThemeData theme) {
    final isPastOrCurrent = index <= _currentStep;
    return theme.textTheme.labelSmall!.copyWith(
      color: isPastOrCurrent
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      fontWeight: isPastOrCurrent ? FontWeight.bold : FontWeight.normal,
    );
  }

  double _contentMaxWidth(ScreenSize size) {
    return switch (size) {
      ScreenSize.compact => double.infinity,
      ScreenSize.medium => 860,
      ScreenSize.expanded => 980,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final size = ResponsiveLayout.resolveSize(width);
    final isCompact = size == ScreenSize.compact;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final sideSlotWidth = isCompact ? 48.0 : 60.0;
    final formInput = _currentInput();
    final step1Valid = CreateEventFormValidator.validateStep(
      formInput,
      CreateEventFormValidator.detailsStep,
    ).isValid;
    final step2Valid = CreateEventFormValidator.validateStep(
      formInput,
      CreateEventFormValidator.genreStep,
    ).isValid;
    final step3Valid = CreateEventFormValidator.validateStep(
      formInput,
      CreateEventFormValidator.musicStep,
    ).isValid;
    final submitValidation = CreateEventFormValidator.validateForSubmit(
      formInput,
    );

    return BlocProvider.value(
      value: _createEventCubit,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
            child: Row(
              children: [
                SizedBox(
                  width: sideSlotWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBackButton(
                      onPressed: _prevStep,
                      padding: EdgeInsets.zero,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Create Event',
                    textAlign: TextAlign.center,
                    style:
                        (isCompact
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.titleLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                  ),
                ),
                SizedBox(
                  width: sideSlotWidth,
                  child: Text(
                    '${_currentStep + 1} / $_totalSteps',
                    textAlign: TextAlign.right,
                    style:
                        (isCompact
                                ? theme.textTheme.titleSmall
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                  ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(isCompact ? 56 : 60),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isCompact ? 16 : 24,
                horizontalPadding,
                16,
              ),
              child: Column(
                children: [
                  Row(
                    children: List.generate(_totalSteps, (index) {
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index == _totalSteps - 1 ? 0 : 8.0,
                          ),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _currentStep
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Details',
                              style: _stepLabelStyle(0, theme),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Genre',
                              style: _stepLabelStyle(1, theme),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Music',
                              style: _stepLabelStyle(2, theme),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Access',
                              style: _stepLabelStyle(3, theme),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _contentMaxWidth(size),
                    ),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentStep = index;
                        });
                      },
                      children: [
                        Step1Details(
                          eventName: eventName,
                          eventDescription: eventDescription,
                          eventCover: eventCover,
                          scheduledStartTime: scheduledStartTime,
                          onNameChanged: (val) =>
                              _setFieldState(() => eventName = val),
                          onDescriptionChanged: (val) =>
                              _setFieldState(() => eventDescription = val),
                          onCoverChanged: (file) =>
                              _setFieldState(() => eventCover = file),
                          onScheduledStartTimeChanged: (val) =>
                              _setFieldState(() => scheduledStartTime = val),
                          canContinue: step1Valid,
                          nameError:
                              _validationErrors[CreateEventValidationField
                                  .name],
                          onNext: _nextStep,
                        ),
                        Step2Genre(
                          selectedGenres: selectedGenres,
                          onGenresChanged: (val) =>
                              _setFieldState(() => selectedGenres = val),
                          canContinue: step2Valid,
                          errorText:
                              _validationErrors[CreateEventValidationField
                                  .tags],
                          onNext: _nextStep,
                        ),
                        Step3Music(
                          selectedTracks: selectedTracks,
                          onTracksChanged: (val) =>
                              _setFieldState(() => selectedTracks = val),
                          canContinue: step3Valid,
                          errorText:
                              _validationErrors[CreateEventValidationField
                                  .tracks],
                          onNext: _nextStep,
                        ),
                        BlocConsumer<CreateEventCubit, CreateEventState>(
                          listenWhen: (_, state) =>
                              state is CreateEventError ||
                              state is CreateEventSuccess,
                          listener: (context, state) {
                            if (state is CreateEventError) {
                              AppSnackbar.showError(context, state.message);
                              return;
                            }

                            if (state is CreateEventSuccess) {
                              unawaited(
                                Navigator.of(context).pushReplacementNamed(
                                  RouteNames.preEvent,
                                  arguments: state.eventId,
                                ),
                              );
                            }
                          },
                          builder: (context, state) {
                            return Step4Access(
                              visibility: visibility,
                              votingRule: votingRule,
                              isRestricted: isRestricted,
                              allowedLocation: allowedLocation,
                              allowedRadius: allowedRadius,
                              startDate: startDate,
                              startTime: startTime,
                              endDate: endDate,
                              endTime: endTime,
                              onVisibilityChanged: (val) {
                                _setFieldState(() {
                                  visibility = val;
                                  if (val == 'Private' &&
                                      votingRule == 'Everyone') {
                                    votingRule = 'Invited Only';
                                  }
                                });
                              },
                              onVotingRuleChanged: (val) =>
                                  _setFieldState(() => votingRule = val),
                              onRestrictedChanged: (val) =>
                                  _setFieldState(() => isRestricted = val),
                              onLocationChanged: (val) =>
                                  _setFieldState(() => allowedLocation = val),
                              onRadiusChanged: (val) =>
                                  _setFieldState(() => allowedRadius = val),
                              onStartDateChanged: (val) =>
                                  _setFieldState(() => startDate = val),
                              onStartTimeChanged: (val) =>
                                  _setFieldState(() => startTime = val),
                              onEndDateChanged: (val) =>
                                  _setFieldState(() => endDate = val),
                              onEndTimeChanged: (val) =>
                                  _setFieldState(() => endTime = val),
                              onSubmit: _submitEvent,
                              canSubmit: submitValidation.isValid,
                              submitErrorText: _step4ValidationError(formInput),
                              isSubmitting: state is CreateEventSubmitting,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
