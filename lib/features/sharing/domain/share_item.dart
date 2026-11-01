enum ShareItem {
  activityTargets,
  progress,
  aboutMe;

  String get stored => switch (this) {
    activityTargets => 'activity_targets',
    progress => 'progress',
    aboutMe => 'about_me',
  };

  static ShareItem? parse(String value) => switch (value) {
    'activity_targets' => activityTargets,
    'progress' => progress,
    'about_me' => aboutMe,
    _ => null,
  };
}
