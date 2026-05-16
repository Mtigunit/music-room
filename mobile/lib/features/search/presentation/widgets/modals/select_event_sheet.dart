import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';

class SelectEventSheet extends StatefulWidget {
  const SelectEventSheet({super.key});

  @override
  State<SelectEventSheet> createState() => _SelectEventSheetState();
}

class _SelectEventSheetState extends State<SelectEventSheet> {
  final IEventRemoteDataSource _eventDs =
      InjectionContainer().eventRemoteDataSource;

  List<MyEventItemModel> _events = const <MyEventItemModel>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch hosted and invited events in parallel to reduce load time.
      final results = await Future.wait<List<MyEventItemModel>>([
        _eventDs.fetchHostedEvents(),
        _eventDs.fetchInvitedEvents(),
      ]);
      final hosted = results[0];
      final invited = results[1];
      if (!mounted) return;
      setState(() {
        _events = [...hosted, ...invited];
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      setState(() {
        _isLoading = false;
        _error = message ?? 'Unable to load events.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load events.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context);
    final bottomInset = insets.viewInsets.bottom + 16;
    final sheetHeight = insets.size.height * 0.6;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to event',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _events.isEmpty
                  ? const Center(
                      child: Text(
                        'You are not hosting or invited to any '
                        'events.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: _events.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final e = _events[index];
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.7),
                            ),
                            child: e.coverImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      e.coverImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.event,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                          ),
                          title: Text(e.name),
                          subtitle: Text(e.hostName),
                          onTap: () =>
                              Navigator.of(context).pop<MyEventItemModel>(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
