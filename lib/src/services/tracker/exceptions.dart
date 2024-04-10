/// Exception for validly formatted riot ids that don't have an
/// associated team.
class PremierTeamDoesntExistException implements Exception {
  final String team;

  const PremierTeamDoesntExistException(this.team);
}

/// Exception for invalidly formatted riot id
class InvalidRiotIdException implements Exception {
  final String id;

  const InvalidRiotIdException(this.id);
}

/// Miscellaneous tracker errors
class TrackerApiException implements Exception {
  final int statusCode;

  const TrackerApiException(this.statusCode);
}
