import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/presentation/widgets/step_1_details.dart';
import 'package:music_room/features/events/presentation/widgets/step_2_genre.dart';
import 'package:music_room/features/events/presentation/widgets/step_3_music.dart';
import 'package:music_room/features/events/presentation/widgets/step_4_access.dart';
import 'package:music_room/features/events/presentation/widgets/step_5_summary.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Global Form State
  String eventName = '';
  String eventDescription = '';
  XFile? eventCover;

  List<String> selectedGenres = [];

  List<String> selectedTracks = []; // Or specific track model

  String visibility = 'Public'; // Public, Private
  String votingRule = 'Everyone'; // Everyone, Invited Only, Location & Time

  EventLocation? allowedLocation;
  double allowedRadius = 10;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  List<String> invitedUsers = [];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
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
    // Event submission wiring will be added with backend integration.
    Navigator.of(context).pop();
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            onPressed: _prevStep,
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
        title: Text(
          'Create Event',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Center(
              child: Text(
                '${_currentStep + 1} / $_totalSteps',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
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
                    Text('Invite', style: _stepLabelStyle(4, theme)),
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
                    onNameChanged: (val) => setState(() => eventName = val),
                    onDescriptionChanged: (val) =>
                        setState(() => eventDescription = val),
                    onCoverChanged: (file) => setState(() => eventCover = file),
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
                  Step4Access(
                    visibility: visibility,
                    votingRule: votingRule,
                    allowedLocation: allowedLocation,
                    allowedRadius: allowedRadius,
                    startDate: startDate,
                    startTime: startTime,
                    endDate: endDate,
                    endTime: endTime,
                    onVisibilityChanged: (val) =>
                        setState(() => visibility = val),
                    onVotingRuleChanged: (val) =>
                        setState(() => votingRule = val),
                    onLocationChanged: (val) =>
                        setState(() => allowedLocation = val),
                    onRadiusChanged: (val) =>
                        setState(() => allowedRadius = val),
                    onStartDateChanged: (val) =>
                        setState(() => startDate = val),
                    onStartTimeChanged: (val) =>
                        setState(() => startTime = val),
                    onEndDateChanged: (val) => setState(() => endDate = val),
                    onEndTimeChanged: (val) => setState(() => endTime = val),
                    onNext: _nextStep,
                  ),
                  Step5Summary(
                    eventName: eventName,
                    selectedGenres: selectedGenres,
                    visibility: visibility,
                    votingRule: votingRule,
                    trackCount: selectedTracks.length,
                    invitedUsers: invitedUsers,
                    onInvitesChanged: (val) =>
                        setState(() => invitedUsers = val),
                    onSubmit: _submitEvent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
