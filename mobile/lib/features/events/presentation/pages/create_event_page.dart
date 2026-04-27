import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';
import 'package:music_room/features/events/presentation/state/create_event_cubit.dart';
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

    if (_currentStep < _totalSteps - 1) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    }
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

  TextStyle _stepLabelStyle(int index, ThemeData theme) {
    final isPastOrCurrent = index <= _currentStep;
    return theme.textTheme.labelSmall!.copyWith(
      color: isPastOrCurrent
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      fontWeight: isPastOrCurrent ? FontWeight.bold : FontWeight.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${_currentStep + 1} / $_totalSteps',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Details', style: _stepLabelStyle(0, theme)),
                      Text('Genre', style: _stepLabelStyle(1, theme)),
                      Text('Music', style: _stepLabelStyle(2, theme)),
                      Text('Access', style: _stepLabelStyle(3, theme)),
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
                      onNameChanged: (val) => setState(() => eventName = val),
                      onDescriptionChanged: (val) =>
                          setState(() => eventDescription = val),
                      onCoverChanged: (file) =>
                          setState(() => eventCover = file),
                      onScheduledStartTimeChanged: (val) =>
                          setState(() => scheduledStartTime = val),
                      onNext: _nextStep,
                    ),
                    Step2Genre(
                      selectedGenres: selectedGenres,
                      onGenresChanged: (val) =>
                          setState(() => selectedGenres = val),
                      onNext: _nextStep,
                    ),
                    Step3Music(
                      selectedTracks: selectedTracks,
                      onTracksChanged: (val) =>
                          setState(() => selectedTracks = val),
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
                            setState(() {
                              visibility = val;
                              // If Private, force Everyone can vote to false
                              // which means force Invited Only to true
                              if (val == 'Private' &&
                                  votingRule == 'Everyone') {
                                votingRule = 'Invited Only';
                              }
                            });
                          },
                          onVotingRuleChanged: (val) =>
                              setState(() => votingRule = val),
                          onRestrictedChanged: (val) =>
                              setState(() => isRestricted = val),
                          onLocationChanged: (val) =>
                              setState(() => allowedLocation = val),
                          onRadiusChanged: (val) =>
                              setState(() => allowedRadius = val),
                          onStartDateChanged: (val) =>
                              setState(() => startDate = val),
                          onStartTimeChanged: (val) =>
                              setState(() => startTime = val),
                          onEndDateChanged: (val) =>
                              setState(() => endDate = val),
                          onEndTimeChanged: (val) =>
                              setState(() => endTime = val),
                          onSubmit: _submitEvent,
                          isSubmitting: state is CreateEventSubmitting,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
