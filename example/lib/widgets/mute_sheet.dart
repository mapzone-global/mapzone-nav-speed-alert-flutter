import 'package:flutter/material.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';
import 'package:provider/provider.dart';

import '../state/alert_controller.dart';

/// Voice configuration: playback owner, voice mode, speed and per-category mute.
///
/// A switch that is ON means the category is announced. The groups follow the
/// rules the SDK enforces:
///  * speed-limit and speeding cues cannot be muted (locked row);
///  * muting a camera or toll category also hides its sign;
///  * muting a restriction category silences the voice only — the sign stays,
///    because it is a rule the driver is bound by.
class MuteSheet extends StatelessWidget {
  const MuteSheet({super.key});

  static const Map<VoiceAlertType, String> _withSign = {
    VoiceAlertType.speedCamera: 'Camera tốc độ',
    VoiceAlertType.trafficEnforcementCamera: 'Camera phạt nguội',
    VoiceAlertType.redLightCamera: 'Camera đèn đỏ',
    VoiceAlertType.aiCamera: 'Camera AI',
    VoiceAlertType.toll: 'Trạm thu phí',
  };

  static const Map<VoiceAlertType, String> _restriction = {
    VoiceAlertType.noParking: 'Cấm đỗ xe',
    VoiceAlertType.noStopping: 'Cấm dừng đỗ',
    VoiceAlertType.roadClosed: 'Đường đóng',
    VoiceAlertType.vehicleRestricted: 'Cấm loại xe',
    VoiceAlertType.buildupAreaStart: 'Bắt đầu khu dân cư',
    VoiceAlertType.buildupAreaEnd: 'Hết khu dân cư',
  };

  static const Map<VoiceAlertType, String> _other = {
    VoiceAlertType.noOvertaking: 'Cấm vượt',
    VoiceAlertType.noOvertakingEnd: 'Hết cấm vượt',
    VoiceAlertType.restStation: 'Trạm dừng nghỉ',
    VoiceAlertType.noLeftTurn: 'Cấm rẽ trái',
    VoiceAlertType.noRightTurn: 'Cấm rẽ phải',
    VoiceAlertType.noUturn: 'Cấm quay đầu',
    VoiceAlertType.noStraight: 'Cấm đi thẳng',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AlertController>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Cấu hình voice',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: p.unmuteAll,
                  child: const Text('Bật tất cả'),
                ),
                TextButton(
                  onPressed: p.muteAll,
                  child: const Text('Tắt tất cả'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              children: [
                _header(theme, 'Cách phát'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<VoiceMode>(
                    segments: const [
                      ButtonSegment(
                        value: VoiceMode.full,
                        label: Text('Đọc câu'),
                        icon: Icon(Icons.record_voice_over),
                      ),
                      ButtonSegment(
                        value: VoiceMode.ding,
                        label: Text('Chỉ ding'),
                        icon: Icon(Icons.notifications_active),
                      ),
                    ],
                    selected: {p.voiceMode},
                    onSelectionChanged: (s) => p.setVoiceMode(s.first),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  value: p.appPlaysVoice,
                  onChanged: p.setAppPlaysVoice,
                  title: const Text('App tự phát voice (onVoice)'),
                  subtitle: const Text('Tắt: SDK phát bằng trình phát có sẵn'),
                ),
                ListTile(
                  dense: true,
                  enabled: !p.appPlaysVoice,
                  title: Text('Tốc độ đọc ${p.voiceSpeed.toStringAsFixed(1)}×'),
                  subtitle: Slider(
                    value: p.voiceSpeed,
                    min: 0.5,
                    max: 2,
                    divisions: 6,
                    onChanged: p.appPlaysVoice ? null : p.setVoiceSpeed,
                  ),
                ),
                _header(theme, 'Cảnh báo tốc độ'),
                const SwitchListTile(
                  dense: true,
                  value: true,
                  onChanged: null,
                  secondary: Icon(Icons.lock_outline),
                  title: Text('Giới hạn tốc độ & vượt tốc'),
                  subtitle: Text('Luôn bật — SDK không cho tắt cảnh báo này'),
                ),
                _header(
                  theme,
                  'Camera & Trạm thu phí',
                  note: 'Tắt tiếng sẽ ẩn luôn biển tương ứng trên màn hình',
                ),
                ..._withSign.entries.map((e) => _tile(p, e.key, e.value)),
                _header(
                  theme,
                  'Biển hạn chế',
                  note: 'Chỉ tắt tiếng — biển vẫn hiện vì là luật đường',
                ),
                ..._restriction.entries.map((e) => _tile(p, e.key, e.value)),
                _header(theme, 'Khác', note: 'Biển rẽ hiện chưa có voice'),
                ..._other.entries.map((e) => _tile(p, e.key, e.value)),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, String title, {String? note}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(note, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _tile(AlertController p, VoiceAlertType type, String label) {
    return SwitchListTile(
      dense: true,
      title: Text(label),
      value: !p.isMuted(type),
      onChanged: (_) => p.toggleMute(type),
    );
  }
}
