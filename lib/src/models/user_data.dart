/// Model representing the user's demographic data and metadata context.
/// This context is sent to the chatbot backend to personalize responses.
class SupportUserData {
  final String? name;
  final String? email;
  final Map<String, dynamic>? metadata;

  const SupportUserData({
    this.name,
    this.email,
    this.metadata,
  });

  SupportUserData copyWith({
    String? name,
    String? email,
    Map<String, dynamic>? metadata,
  }) {
    return SupportUserData(
      name: name ?? this.name,
      email: email ?? this.email,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converts user data to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (metadata != null) ...metadata!,
    };
  }

  @override
  String toString() {
    return 'SupportUserData(name: $name, email: $email, metadata: $metadata)';
  }
}
