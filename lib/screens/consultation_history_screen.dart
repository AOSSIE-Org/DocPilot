import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../core/healthcare/healthcare_services_manager.dart';
import '../core/healthcare/healthcare_widgets.dart';
import '../models/health_models.dart';
import '../theme/app_theme.dart';

class ConsultationHistoryScreen extends StatefulWidget {
  final void Function(ConsultationSession session)? onSessionSelected;

  const ConsultationHistoryScreen({
    super.key,
    this.onSessionSelected,
  });

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  final HealthcareServicesManager _services = HealthcareServicesManager();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _playingSessionId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _totalDuration = duration);
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playingSessionId = null;
            _currentPosition = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(ConsultationSession session) async {
    if (!session.hasAudio) return;

    try {
      if (_playingSessionId == session.id && _isPlaying) {
        await _audioPlayer.pause();
      } else if (_playingSessionId == session.id) {
        await _audioPlayer.play();
      } else {
        // Use setFilePath for local files
        await _audioPlayer.setFilePath(session.audioUrl!);
        setState(() => _playingSessionId = session.id);
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to play audio: ${e.toString()}'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _playingSessionId = null;
      _currentPosition = Duration.zero;
    });
  }

  Future<void> _deleteSession(ConsultationSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.mediumRadius,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.sm),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppTheme.dangerColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.md),
            const Text('Delete Recording'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this consultation recording?',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.md),
            Container(
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: AppTheme.smallRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.patientName,
                    style: AppTheme.labelLarge,
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    DateFormat('MMM d, yyyy • HH:mm').format(session.createdAt),
                    style: AppTheme.bodySmall,
                  ),
                  if (session.hasAudio) ...[
                    const SizedBox(height: AppTheme.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.mic,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.formattedDuration,
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              'This action cannot be undone.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.dangerColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Stop audio if playing this session
      if (_playingSessionId == session.id) {
        await _stopAudio();
      }

      try {
        await _services.deleteConsultation(session);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording deleted successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    }
  }

  void _showSessionDetails(ConsultationSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SessionDetailSheet(
        session: session,
        isPlaying: _playingSessionId == session.id && _isPlaying,
        currentPosition: _playingSessionId == session.id ? _currentPosition : Duration.zero,
        totalDuration: _playingSessionId == session.id ? _totalDuration : Duration.zero,
        onPlay: () => _playAudio(session),
        onStop: _stopAudio,
        onSelect: () {
          Navigator.pop(context);
          Navigator.pop(context);
          widget.onSessionSelected?.call(session);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteSession(session);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = _services.currentDoctorId;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Recording History'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: doctorId.isEmpty
          ? const HealthcareEmptyState(
              icon: Icons.login,
              title: 'Not Signed In',
              description: 'Please sign in to view your recording history.',
            )
          : StreamBuilder<List<ConsultationSession>>(
              stream: _services.firestore.watchConsultationHistory(
                doctorId: doctorId,
                limit: 100,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final sessions = snapshot.data ?? const <ConsultationSession>[];

                if (sessions.isEmpty) {
                  return const HealthcareEmptyState(
                    icon: Icons.mic_off,
                    title: 'No Recordings',
                    description: 'Your voice recordings will appear here after you record a consultation.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.lg),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isCurrentlyPlaying = _playingSessionId == session.id;

                    return _ConsultationCard(
                      session: session,
                      isPlaying: isCurrentlyPlaying && _isPlaying,
                      currentPosition: isCurrentlyPlaying ? _currentPosition : Duration.zero,
                      totalDuration: isCurrentlyPlaying ? _totalDuration : Duration.zero,
                      onTap: () => _showSessionDetails(session),
                      onPlay: session.hasAudio ? () => _playAudio(session) : null,
                      onDelete: () => _deleteSession(session),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final ConsultationSession session;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback onDelete;

  const _ConsultationCard({
    required this.session,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onTap,
    required this.onPlay,
    required this.onDelete,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with patient info
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.lg, AppTheme.lg, AppTheme.md),
            child: Row(
              children: [
                // Patient avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Center(
                    child: Text(
                      session.patientName.isNotEmpty
                          ? session.patientName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                // Patient name and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.patientName,
                        style: AppTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, yyyy • HH:mm').format(session.createdAt),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Delete recording',
                ),
              ],
            ),
          ),

          // Audio player section (if has audio)
          if (session.hasAudio) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: isPlaying
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : AppTheme.surfaceVariant,
                borderRadius: AppTheme.smallRadius,
              ),
              child: Row(
                children: [
                  // Play/Pause button
                  GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: isPlaying ? Colors.white : AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  // Progress bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: totalDuration.inMilliseconds > 0
                                ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                                : 0,
                            backgroundColor: AppTheme.dividerColor,
                            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isPlaying ? _formatDuration(currentPosition) : '00:00',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              session.formattedDuration,
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.md),
          ],

          // Summary preview
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.summarize,
                      size: 14,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Summary',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.summary.isNotEmpty
                      ? session.summary
                      : 'No summary available',
                  style: AppTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {
  final ConsultationSession session;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _SessionDetailSheet({
    required this.session,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlay,
    required this.onStop,
    required this.onSelect,
    required this.onDelete,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppTheme.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    child: Center(
                      child: Text(
                        session.patientName.isNotEmpty
                            ? session.patientName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.patientName,
                          style: AppTheme.headingSmall,
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy • HH:mm').format(session.createdAt),
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Audio player (if has audio)
            if (session.hasAudio)
              Container(
                margin: const EdgeInsets.all(AppTheme.lg),
                padding: const EdgeInsets.all(AppTheme.lg),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mic,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.sm),
                        Text(
                          'Audio Recording',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          session.formattedDuration,
                          style: AppTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.md),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onPlay,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.md),
                        Expanded(
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  trackHeight: 4,
                                  activeTrackColor: AppTheme.primaryColor,
                                  inactiveTrackColor: AppTheme.dividerColor,
                                  thumbColor: AppTheme.primaryColor,
                                ),
                                child: Slider(
                                  value: totalDuration.inMilliseconds > 0
                                      ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                                      : 0,
                                  onChanged: (value) {
                                    // Seeking not implemented for simplicity
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(currentPosition),
                                    style: AppTheme.labelSmall,
                                  ),
                                  Text(
                                    _formatDuration(totalDuration),
                                    style: AppTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isPlaying)
                          IconButton(
                            onPressed: onStop,
                            icon: const Icon(Icons.stop, color: AppTheme.primaryColor),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            // Content tabs
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryColor,
                      tabs: const [
                        Tab(text: 'Transcript'),
                        Tab(text: 'Summary'),
                        Tab(text: 'Prescription'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _ContentTab(
                            content: session.transcript,
                            emptyMessage: 'No transcript available',
                          ),
                          _ContentTab(
                            content: session.summary,
                            emptyMessage: 'No summary available',
                          ),
                          _ContentTab(
                            content: session.prescription,
                            emptyMessage: 'No prescription available',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(color: AppTheme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                      label: const Text('Delete', style: TextStyle(color: AppTheme.dangerColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.dangerColor),
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.mediumRadius,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onSelect,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Load in Assistant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.mediumRadius,
                        ),
                      ),
                    ),
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

class _ContentTab extends StatelessWidget {
  final String content;
  final String emptyMessage;

  const _ContentTab({
    required this.content,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textTertiary,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: AppTheme.mediumRadius,
        ),
        child: SelectableText(
          content,
          style: AppTheme.bodyMedium,
        ),
      ),
    );
  }
}
