import 'package:handabatamae/models/user_model.dart';
import 'package:handabatamae/services/auth_service.dart';
import 'package:handabatamae/shared/connection_quality.dart';
import 'package:handabatamae/services/badge_service.dart';

class QuestBadgeRange {
  final int stageStart;     // First badge ID for normal stages
  final int completeStart;  // Badge ID for completion
  final int fullClearStart; // Badge ID for full clear
  
  const QuestBadgeRange(this.stageStart, this.completeStart, this.fullClearStart);
}

enum UnlockPriority {
  ACHIEVEMENT,     // Important achievements (100% completion)
  QUEST_COMPLETE,  // Quest completion badges
  MILESTONE,       // Progress milestones
  REGULAR         // Regular gameplay unlocks
}

class BadgeUnlockService {
  // Singleton pattern
  static final BadgeUnlockService _instance = BadgeUnlockService._internal();
  factory BadgeUnlockService() => _instance;

  final AuthService _authService;
  final ConnectionManager _connectionManager = ConnectionManager();
  final BadgeService _badgeService = BadgeService();

  static const Map<String, QuestBadgeRange> questBadgeRanges = {
    'Quake Quest': QuestBadgeRange(0, 14, 16),
    'Storm Quest': QuestBadgeRange(18, 32, 34),
    'Volcano Quest': QuestBadgeRange(40, 54, 56),
    'Drought Quest': QuestBadgeRange(58, 72, 74),
    'Tsunami Quest': QuestBadgeRange(76, 90, 92),
    'Flood Quest': QuestBadgeRange(94, 108, 110),
  };

  BadgeUnlockService._internal() : _authService = AuthService();

  Future<void> unlockBadges(List<int> badgeIds) async {
    if (badgeIds.isEmpty) return;
    print('🏅 Attempting to unlock badges: $badgeIds');

    try {
      // Check connection quality
      final quality = await _connectionManager.checkConnectionQuality();
      print('📡 Connection quality: $quality');

      UserProfile? profile = await _authService.getUserProfile();
      if (profile == null) return;

      List<int> updatedUnlockedBadges = List<int>.from(profile.unlockedBadge);
      int maxBadgeId = badgeIds.reduce((max, id) => id > max ? id : max);
      
      if (maxBadgeId >= updatedUnlockedBadges.length) {
        updatedUnlockedBadges.addAll(
          List<int>.filled(maxBadgeId - updatedUnlockedBadges.length + 1, 0)
        );
      }
      
      // Pre-fetch badge data if online
      if (quality != ConnectionQuality.OFFLINE) {
        for (var id in badgeIds) {
          await _badgeService.getBadgeDetails(id);
        }
      }
      
      for (var id in badgeIds) {
        updatedUnlockedBadges[id] = 1;
      }

      if (quality == ConnectionQuality.OFFLINE) {
        // Store locally only
        print('📱 Offline mode: Saving unlocks locally');
        await _authService.saveUserProfileLocally(profile.copyWith(
          updates: {'unlockedBadge': updatedUnlockedBadges}
        ));
      } else {
        // Update both local and server
        print('🌐 Online mode: Updating profile');
        await _authService.updateUserProfile('unlockedBadge', updatedUnlockedBadges);
      }
    } catch (e) {
      print('❌ Error unlocking badges: $e');
    }
  }

  Future<void> checkAdventureBadges({
    required String questName,
    required String stageName,
    required String difficulty,
    required int stars,
    required List<int> allStageStars,
  }) async {
    try {
      print('🎮 Checking adventure badges for $questName, $stageName');
      
      int stageNumber = int.parse(stageName.replaceAll(RegExp(r'[^0-9]'), '')) - 1;
      List<int> updatedStageStars = List<int>.from(allStageStars);
      if (stageNumber < updatedStageStars.length) {
        updatedStageStars[stageNumber] = stars;
      }

      final questRange = questBadgeRanges[questName];
      if (questRange == null) return;

      List<int> badgesToUnlock = [];
      
      // Stage badge
      int stageBadgeId = questRange.stageStart + (stageNumber * 2) + (difficulty == 'hard' ? 1 : 0);
      if (stars > 0) {
        badgesToUnlock.add(stageBadgeId);
      }
      
      // Complete badge
      if (_hasAllStagesCleared(updatedStageStars)) {
        int completeBadgeId = difficulty == 'hard' 
            ? questRange.completeStart + 1
            : questRange.completeStart;
        badgesToUnlock.add(completeBadgeId);
      }
      
      // Full clear badge
      if (_hasAllStagesFullyCleared(updatedStageStars)) {
        int fullClearBadgeId = difficulty == 'hard'
            ? questRange.fullClearStart + 1
            : questRange.fullClearStart;
        badgesToUnlock.add(fullClearBadgeId);
      }

      if (badgesToUnlock.isNotEmpty) {
        await unlockBadges(badgesToUnlock);
      }
    } catch (e) {
      print('❌ Error checking adventure badges: $e');
    }
  }

  Future<void> checkArcadeBadges({
    required int totalTime,
    required double accuracy,
    required int streak,
    required double averageTimePerQuestion,
  }) async {
    try {
      List<int> badgesToUnlock = [];

      if (accuracy >= 100) {
        badgesToUnlock.add(37);  // Perfect Accuracy
      }
      
      if (totalTime <= 120) {
        badgesToUnlock.add(36);  // Speed Demon
      }
      
      if (averageTimePerQuestion <= 15) {
        badgesToUnlock.add(39);  // Quick Thinker
      }
      
      if (streak >= 15) {
        badgesToUnlock.add(38);  // Streak Master
      }

      if (badgesToUnlock.isNotEmpty) {
        await unlockBadges(badgesToUnlock);
      }
    } catch (e) {
      print('Error checking arcade badges: $e');
    }
  }

  bool _hasAllStagesCleared(List<int> stageStars) {
    List<int> normalStages = stageStars.sublist(0, stageStars.length - 1);
    return !normalStages.contains(0);
  }

  bool _hasAllStagesFullyCleared(List<int> stageStars) {
    List<int> normalStages = stageStars.sublist(0, stageStars.length - 1);
    return normalStages.every((stars) => stars == 3);
  }

  void dispose() {
    // Implement dispose logic if needed
  }
} 