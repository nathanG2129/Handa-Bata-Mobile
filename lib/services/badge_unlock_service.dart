import 'package:handabatamae/models/user_model.dart';
import 'package:handabatamae/services/auth_service.dart';
import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';

class QuestBadgeRange {
  final int stageStart;     // First badge ID for normal stages
  final int completeStart;  // Badge ID for completion
  final int fullClearStart; // Badge ID for full clear
  
  const QuestBadgeRange(this.stageStart, this.completeStart, this.fullClearStart);
}

class BadgeUnlockService {
  final AuthService _authService;
  static final Queue<int> _pendingBadgeNotifications = Queue<int>();
  static bool _isShowingNotification = false;
  
  // Quest badge ranges
  static const Map<String, QuestBadgeRange> questBadgeRanges = {
    'Quake Quest': QuestBadgeRange(0, 14, 16),
    'Storm Quest': QuestBadgeRange(18, 32, 34),
    'Volcano Quest': QuestBadgeRange(40, 54, 56),
    'Drought Quest': QuestBadgeRange(58, 72, 74),
    'Tsunami Quest': QuestBadgeRange(76, 90, 92),
    'Flood Quest': QuestBadgeRange(94, 108, 110),
  };

  BadgeUnlockService(this._authService);

  Future<void> _unlockBadges(List<int> badgeIds) async {
    if (badgeIds.isEmpty) return;
    print('🏅 Attempting to unlock badges: $badgeIds');

    try {
      // Try local profile first
      UserProfile? profile = await _authService.getLocalUserProfile();
      
      // If no local profile, try to get from Firestore
      if (profile == null) {
        profile = await _authService.getUserProfile();
      }
      
      if (profile == null) {
        print('❌ No user profile found locally or on server');
        return;
      }

      // Pre-check which badges actually need unlocking
      List<int> badgesToUnlock = [];
      List<int> unlockedBadges = List<int>.from(profile.unlockedBadge);
      
      // Ensure array is large enough
      int maxBadgeId = badgeIds.reduce((a, b) => a > b ? a : b);
      while (unlockedBadges.length <= maxBadgeId) {
        unlockedBadges.add(0);
      }

      // Get current online state if available
      var connectivityResult = await Connectivity().checkConnectivity();
      List<int>? onlineBadges;
      if (connectivityResult != ConnectivityResult.none) {
        UserProfile? onlineProfile = await _authService.getUserProfile();
        if (onlineProfile != null) {
          onlineBadges = List<int>.from(onlineProfile.unlockedBadge);
          // Merge online unlocks into local array
          for (int i = 0; i < onlineBadges.length && i < unlockedBadges.length; i++) {
            if (onlineBadges[i] == 1) {
              unlockedBadges[i] = 1;
            }
          }
        }
      }

      // Check which badges need unlocking
      for (int badgeId in badgeIds) {
        bool isAlreadyUnlocked = badgeId < unlockedBadges.length && unlockedBadges[badgeId] == 1;
        if (!isAlreadyUnlocked) {
          print('🔍 Badge $badgeId needs unlocking');
          badgesToUnlock.add(badgeId);
        } else {
          print('✅ Badge $badgeId is already unlocked, skipping');
        }
      }

      // If no new badges to unlock, return early
      if (badgesToUnlock.isEmpty) {
        print('✨ No new badges to unlock');
        return;
      }

      // Process new unlocks
      bool hasNewUnlocks = false;
      for (int badgeId in badgesToUnlock) {
        print('🏅 New badge unlocked: $badgeId');
        unlockedBadges[badgeId] = 1;
        hasNewUnlocks = true;
        _pendingBadgeNotifications.add(badgeId);
      }

      if (hasNewUnlocks) {
        // Calculate total unlocked by counting all 1s
        int totalUnlocked = unlockedBadges.where((badge) => badge == 1).length;
        print('🏅 Updating user profile with new unlocks. Total unlocked: $totalUnlocked');
        
        // Create updated profile
        UserProfile updatedProfile = profile.copyWith(updates: {
          'unlockedBadge': unlockedBadges,
          'totalBadgeUnlocked': totalUnlocked,
        });

        // Always update local storage first
        await _authService.saveUserProfileLocally(updatedProfile);
        print('💾 Saved to local storage');

        // Try to update Firestore if online
        if (connectivityResult != ConnectivityResult.none) {
          await Future.wait([
            _authService.updateUserProfile('unlockedBadge', unlockedBadges),
            _authService.updateUserProfile('totalBadgeUnlocked', totalUnlocked)
          ]);
          print('🌐 Updated Firestore');
        } else {
          print('📴 Offline - changes saved locally');
        }
      }
    } catch (e) {
      print('❌ Error in _unlockBadges: $e');
    }
  }

  // Check Adventure Mode badges
  Future<void> checkAdventureBadges({
    required String questName,
    required String stageName,
    required String difficulty,
    required int stars,
    required List<int> allStageStars,
  }) async {
    try {
      UserProfile? profile = await _authService.getUserProfile();
      if (profile == null) return;

      final questRange = questBadgeRanges[questName];
      if (questRange == null) return;

      List<int> badgesToUnlock = [];
      
      // Extract stage number from stageName (e.g., "Stage 1" -> 1)
      int stageNumber = int.parse(stageName.replaceAll(RegExp(r'[^0-9]'), '')) - 1;
      
      // 1. Stage badge (any stars)
      int stageBadgeId = questRange.stageStart + (stageNumber * 2) + (difficulty == 'hard' ? 1 : 0);
      if (stars > 0) {
        badgesToUnlock.add(stageBadgeId);
      }
      
      // 2. Complete badge (all stages with stars)
      if (_hasAllStagesCleared(allStageStars)) {
        int completeBadgeId = difficulty == 'hard' 
            ? questRange.completeStart + 1
            : questRange.completeStart;
        badgesToUnlock.add(completeBadgeId);
      }
      
      // 3. Full clear badge (all stages with 3 stars)
      if (_hasAllStagesFullyCleared(allStageStars)) {
        int fullClearBadgeId = difficulty == 'hard'
            ? questRange.fullClearStart + 1
            : questRange.fullClearStart;
        badgesToUnlock.add(fullClearBadgeId);
      }

      // Use the helper method to unlock badges
      if (badgesToUnlock.isNotEmpty) {
        await _unlockBadges(badgesToUnlock);
      }
    } catch (e) {
      print('Error checking adventure badges: $e');
    }
  }

  // Check Arcade Mode badges
  Future<void> checkArcadeBadges({
    required int totalTime,
    required double accuracy,
    required int streak,
    required double averageTimePerQuestion,
  }) async {
    try {
      List<int> badgesToUnlock = [];

      // Speed Demon - Complete under 2 minutes
      if (totalTime <= 120) {
        badgesToUnlock.add(36);
      }
      
      // Perfect Accuracy - 100% accuracy
      if (accuracy >= 100) {
        badgesToUnlock.add(37);
      }
      
      // Streak Master - 15+ streak
      if (streak >= 15) {
        badgesToUnlock.add(38);
      }
      
      // Quick Thinker - Average time per question under 15 seconds
      if (averageTimePerQuestion <= 15) {
        badgesToUnlock.add(39);
      }

      // Use the helper method to unlock badges
      if (badgesToUnlock.isNotEmpty) {
        await _unlockBadges(badgesToUnlock);
      }
    } catch (e) {
      print('Error checking arcade badges: $e');
    }
  }

  bool _hasAllStagesCleared(List<int> stageStars) {
    return !stageStars.contains(0);
  }

  bool _hasAllStagesFullyCleared(List<int> stageStars) {
    return stageStars.every((stars) => stars == 3);
  }

  // Add this method to get pending notifications
  static Queue<int> get pendingNotifications => _pendingBadgeNotifications;

  // Add this method to check notification status
  static bool get isShowingNotification => _isShowingNotification;

  // Add this method to set notification status
  static set isShowingNotification(bool value) {
    _isShowingNotification = value;
  }
} 