class AppSettings {
  String githubToken;
  String repositoryOwner;
  String repositoryName;
  String branch;
  String tripsDataPath;
  String whatsappNumber;
  String upiId;
  bool darkMode;

  AppSettings({
    this.githubToken = '',
    this.repositoryOwner = 'teamweekendtrekkers-png',
    this.repositoryName = 'teamweekendtrekkerwebsite',
    this.branch = 'main',
    this.tripsDataPath = 'js/trips-data.js',
    this.whatsappNumber = '7019235581',
    this.upiId = '9538236581@ybl',
    this.darkMode = false,
  });

  bool get isConfigured => githubToken.isNotEmpty;

  AppSettings copyWith({
    String? githubToken,
    String? repositoryOwner,
    String? repositoryName,
    String? branch,
    String? tripsDataPath,
    String? whatsappNumber,
    String? upiId,
    bool? darkMode,
  }) {
    return AppSettings(
      githubToken: githubToken ?? this.githubToken,
      repositoryOwner: repositoryOwner ?? this.repositoryOwner,
      repositoryName: repositoryName ?? this.repositoryName,
      branch: branch ?? this.branch,
      tripsDataPath: tripsDataPath ?? this.tripsDataPath,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      upiId: upiId ?? this.upiId,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'githubToken': githubToken,
    'repositoryOwner': repositoryOwner,
    'repositoryName': repositoryName,
    'branch': branch,
    'tripsDataPath': tripsDataPath,
    'whatsappNumber': whatsappNumber,
    'upiId': upiId,
    'darkMode': darkMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    githubToken: json['githubToken'] ?? '',
    repositoryOwner: json['repositoryOwner'] ?? 'teamweekendtrekkers-png',
    repositoryName: json['repositoryName'] ?? 'teamweekendtrekkerwebsite',
    branch: json['branch'] ?? 'main',
    tripsDataPath: json['tripsDataPath'] ?? 'js/trips-data.js',
    whatsappNumber: json['whatsappNumber'] ?? '7019235581',
    upiId: json['upiId'] ?? '9538236581@ybl',
    darkMode: json['darkMode'] ?? false,
  );
}
