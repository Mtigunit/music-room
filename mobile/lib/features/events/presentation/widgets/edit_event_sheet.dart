import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/models/tag_option.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/presentation/state/edit_event_cubit.dart';
import 'package:music_room/features/events/presentation/validation/create_event_form_validator.dart';
import 'package:music_room/features/events/presentation/widgets/step_1_details.dart';
import 'package:music_room/features/events/presentation/widgets/step_2_genre.dart';
import 'package:music_room/features/events/presentation/widgets/step_3_music.dart';
import 'package:music_room/features/events/presentation/widgets/step_4_access.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';

class EditEventSheet extends StatefulWidget {
  const EditEventSheet({required this.event, required this.tracks, super.key});

  final EventDetailModel event;
  final List<EventTrackModel> tracks;

  @override
  State<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<EditEventSheet> {
  final PageController _pageController = PageController();
  late final EditEventCubit _editEventCubit;
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Global Form State
  late String eventName;
  late String eventDescription;
  XFile? eventCover;
  String? initialImageUrl;

  late List<TagOption<String>> selectedGenres;
  late List<TrackModel> selectedTracks;

  late String visibility;
  late String votingRule;

  EventLocation? allowedLocation;
  double allowedRadius = 10;
  bool isRestricted = false;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;
  late DateTime scheduledStartTime;

  bool _showValidationErrors = false;
  Map<String, String> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _editEventCubit = EditEventCubit(
      remoteDataSource: InjectionContainer().eventRemoteDataSource,
    );

    eventName = widget.event.name;
    eventDescription = widget.event.description ?? '';
    initialImageUrl = widget.event.coverImage;

    selectedGenres = widget.event.tags.map((tagString) {
      return TagGenreNormalizer.allTags.firstWhere(
        (e) => e.backendValue == tagString || e.label == tagString,
        orElse: () => TagOption<String>(value: tagString, label: tagString),
      );
    }).toList();

    // Reconstruct tracks into Create flow's TrackModel
    selectedTracks = widget.tracks
        .where(
          (t) => t.providerTrackId.isNotEmpty && t.status != 'PLAYED',
        )
        .map(
          (t) => TrackModel(
            providerTrackId: t.providerTrackId,
            title: t.title,
            artist: t.artist,
            durationMs: t.durationMs,
            thumbnailUrl: t.thumbnailUrl,
          ),
        )
        .toList();

    // visibility matching
    visibility = widget.event.visibility.toUpperCase() == 'PRIVATE'
        ? 'Private'
        : 'Public';

    // voting rules
    votingRule = 'Everyone';
    if (widget.event.policies.invitingOnly) {
      votingRule = 'Invited Only';
    } else if (widget.event.policies.locationAndTime ||
        widget.event.locationLat != null) {
      votingRule = 'Location & Time';
    }

    if (widget.event.locationLat != null && widget.event.locationLng != null) {
      isRestricted = true;
      allowedLocation = EventLocation(
        widget.event.locationLat!,
        widget.event.locationLng!,
      );
    }

    if (widget.event.policies.startDate != null) {
      isRestricted = true;
      final start = widget.event.policies.startDate!.toLocal();
      startDate = start;
      startTime = TimeOfDay.fromDateTime(start);
    }

    if (widget.event.policies.endDate != null) {
      isRestricted = true;
      final end = widget.event.policies.endDate!.toLocal();
      endDate = end;
      endTime = TimeOfDay.fromDateTime(end);
    }

    scheduledStartTime = widget.event.startDate?.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    unawaited(_editEventCubit.close());
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
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
      _editEventCubit.submitEdit(
        eventId: widget.event.id,
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
      value: _editEventCubit,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: theme.colorScheme.surface,
          height: MediaQuery.sizeOf(context).height * 0.9,
          child: Column(
            children: [
              Container(
                color: theme.colorScheme.surface,
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 4 : 8,
                  8,
                  isCompact ? 4 : 8,
                  0,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    EditEventHeader(
                      onBack: _prevStep,
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                      isCompact: isCompact,
                      sideSlotWidth: sideSlotWidth,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding - (isCompact ? 4 : 8),
                        16,
                        horizontalPadding - (isCompact ? 4 : 8),
                        16,
                      ),
                      child: EditEventStepper(
                        currentStep: _currentStep,
                        totalSteps: _totalSteps,
                        stepLabelStyle: (index) =>
                            _stepLabelStyle(index, theme),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _contentMaxWidth(size),
                    ),
                    child: EditEventPages(
                      pageController: _pageController,
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                      onPageChanged: (index) {
                        setState(() {
                          _currentStep = index;
                        });
                      },
                      eventName: eventName,
                      eventDescription: eventDescription,
                      eventCover: eventCover,
                      initialImageUrl: initialImageUrl,
                      scheduledStartTime: scheduledStartTime,
                      selectedGenres: selectedGenres,
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
                      onNameChanged: (val) =>
                          _setFieldState(() => eventName = val),
                      onDescriptionChanged: (val) =>
                          _setFieldState(() => eventDescription = val),
                      onCoverChanged: (file) =>
                          _setFieldState(() => eventCover = file),
                      onScheduledStartTimeChanged: (val) =>
                          _setFieldState(() => scheduledStartTime = val),
                      onGenresChanged: (val) =>
                          _setFieldState(() => selectedGenres = val),
                      onTracksChanged: (val) =>
                          _setFieldState(() => selectedTracks = val),
                      onVisibilityChanged: (val) {
                        _setFieldState(() {
                          visibility = val;
                          if (val == 'Private' && votingRule == 'Everyone') {
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
                      step1Valid: step1Valid,
                      step2Valid: step2Valid,
                      step3Valid: step3Valid,
                      submitValidation: submitValidation,
                      validationErrors: _validationErrors,
                      onNext: _nextStep,
                      onSubmit: _submitEvent,
                      step4ValidationError: _step4ValidationError(formInput),
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

class EditEventHeader extends StatelessWidget {
  const EditEventHeader({
    required this.onBack,
    required this.currentStep,
    required this.totalSteps,
    required this.isCompact,
    required this.sideSlotWidth,
    super.key,
  });

  final VoidCallback onBack;
  final int currentStep;
  final int totalSteps;
  final bool isCompact;
  final double sideSlotWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: sideSlotWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppBackButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Edit Event',
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
            '${currentStep + 1} / $totalSteps',
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
    );
  }
}

class EditEventStepper extends StatelessWidget {
  const EditEventStepper({
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabelStyle,
    super.key,
  });

  final int currentStep;
  final int totalSteps;
  final TextStyle Function(int index) stepLabelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index == totalSteps - 1 ? 0 : 8.0,
                ),
                height: 4,
                decoration: BoxDecoration(
                  color: index <= currentStep
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
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
                  child: Text('Details', style: stepLabelStyle(0)),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Genre', style: stepLabelStyle(1)),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Music', style: stepLabelStyle(2)),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Access', style: stepLabelStyle(3)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class EditEventPages extends StatelessWidget {
  const EditEventPages({
    required this.pageController,
    required this.currentStep,
    required this.totalSteps,
    required this.onPageChanged,
    required this.eventName,
    required this.eventDescription,
    required this.eventCover,
    required this.initialImageUrl,
    required this.scheduledStartTime,
    required this.selectedGenres,
    required this.selectedTracks,
    required this.visibility,
    required this.votingRule,
    required this.isRestricted,
    required this.allowedLocation,
    required this.allowedRadius,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onCoverChanged,
    required this.onScheduledStartTimeChanged,
    required this.onGenresChanged,
    required this.onTracksChanged,
    required this.onVisibilityChanged,
    required this.onVotingRuleChanged,
    required this.onRestrictedChanged,
    required this.onLocationChanged,
    required this.onRadiusChanged,
    required this.onStartDateChanged,
    required this.onStartTimeChanged,
    required this.onEndDateChanged,
    required this.onEndTimeChanged,
    required this.step1Valid,
    required this.step2Valid,
    required this.step3Valid,
    required this.submitValidation,
    required this.validationErrors,
    required this.onNext,
    required this.onSubmit,
    required this.step4ValidationError,
    super.key,
  });

  final PageController pageController;
  final int currentStep;
  final int totalSteps;
  final ValueChanged<int> onPageChanged;

  final String eventName;
  final String eventDescription;
  final XFile? eventCover;
  final String? initialImageUrl;
  final DateTime scheduledStartTime;
  final List<TagOption<String>> selectedGenres;
  final List<TrackModel> selectedTracks;
  final String visibility;
  final String votingRule;
  final bool isRestricted;
  final EventLocation? allowedLocation;
  final double allowedRadius;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<XFile?> onCoverChanged;
  final ValueChanged<DateTime> onScheduledStartTimeChanged;
  final ValueChanged<List<TagOption<String>>> onGenresChanged;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String> onVotingRuleChanged;
  final ValueChanged<bool> onRestrictedChanged;
  final ValueChanged<EventLocation?> onLocationChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;

  final bool step1Valid;
  final bool step2Valid;
  final bool step3Valid;
  final CreateEventValidationResult submitValidation;
  final Map<String, String> validationErrors;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final String? step4ValidationError;

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: onPageChanged,
      children: [
        Step1Details(
          eventName: eventName,
          eventDescription: eventDescription,
          eventCover: eventCover,
          initialImageUrl: initialImageUrl,
          scheduledStartTime: scheduledStartTime,
          onNameChanged: onNameChanged,
          onDescriptionChanged: onDescriptionChanged,
          onCoverChanged: onCoverChanged,
          onScheduledStartTimeChanged: onScheduledStartTimeChanged,
          canContinue: step1Valid,
          nameError: validationErrors[CreateEventValidationField.name],
          onNext: onNext,
        ),
        Step2Genre(
          selectedGenres: selectedGenres,
          onGenresChanged: onGenresChanged,
          canContinue: step2Valid,
          errorText: validationErrors[CreateEventValidationField.tags],
          onNext: onNext,
        ),
        Step3Music(
          selectedTracks: selectedTracks,
          onTracksChanged: onTracksChanged,
          canContinue: step3Valid,
          errorText: validationErrors[CreateEventValidationField.tracks],
          onNext: onNext,
        ),
        BlocConsumer<EditEventCubit, EditEventState>(
          listenWhen: (_, state) =>
              state is EditEventError || state is EditEventSuccess,
          listener: (context, state) {
            if (state is EditEventError) {
              AppSnackbar.showError(context, state.message);
              return;
            }
            if (state is EditEventSuccess) {
              Navigator.of(context).pop(true);
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
              onVisibilityChanged: onVisibilityChanged,
              onVotingRuleChanged: onVotingRuleChanged,
              onRestrictedChanged: onRestrictedChanged,
              onLocationChanged: onLocationChanged,
              onRadiusChanged: onRadiusChanged,
              onStartDateChanged: onStartDateChanged,
              onStartTimeChanged: onStartTimeChanged,
              onEndDateChanged: onEndDateChanged,
              onEndTimeChanged: onEndTimeChanged,
              onSubmit: onSubmit,
              canSubmit: submitValidation.isValid,
              submitErrorText: step4ValidationError,
              isSubmitting: state is EditEventSubmitting,
            );
          },
        ),
      ],
    );
  }
}
