class GameLevel {
  final int level;
  final String topic;
  final bool isBoss;
  final bool isLocked;

  GameLevel({
    required this.level,
    required this.topic,
    required this.isBoss,
    this.isLocked = true,
  });
}

// Generate 30 Levels with diverse IT topics
List<GameLevel> generateLevels() {
  // 10 Topics for 30 Levels (3 levels per topic)
  List<String> topics = [
    "IT Fundamentals",        // Levels 1-3
    "Networking Basics",      // Levels 4-6
    "Cybersecurity",          // Levels 7-9
    "Cloud Computing",        // Levels 10-12
    "Artificial Intelligence",// Levels 13-15
    "Automation & DevOps",    // Levels 16-18
    "Software Development",   // Levels 19-21
    "Database Systems",       // Levels 22-24
    "Web Technologies",       // Levels 25-27
    "Future Tech (IoT/5G)"    // Levels 28-30
  ];

  List<GameLevel> levels = [];
  for (int i = 1; i <= 30; i++) {
    // Calculate which topic index to use
    // (Level 1-3 = Index 0, Level 4-6 = Index 1, etc.)
    int topicIndex = (i - 1) ~/ 3; 
    
    // Every 3rd level is a Boss Level (Harder)
    bool isBoss = (i % 3 == 0);
    
    levels.add(GameLevel(
      level: i,
      // Safely get the topic (using modulo just in case)
      topic: topics[topicIndex % topics.length],
      isBoss: isBoss,
      // For testing, Level 1 is unlocked. 
      // In a real app with Firebase, you would check the user's progress here.
      isLocked: i > 1, 
    ));
  }
  return levels;
}