/// Selects which detection pipeline mode is active.
///
/// - [ruleOnly]: Rule-based detection only (default).
/// - [rulePlusMl]: Rule-based detection first, with optional ML refinement.
enum DetectorMode {
  ruleOnly,
  rulePlusMl,
}

