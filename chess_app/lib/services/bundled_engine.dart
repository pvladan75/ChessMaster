/// The engine built into the app (`packages/stockfish`), named by that
/// package's version and the upstream tag of its sources.
///
/// The engine's answers are kept under this name (`EvalCache`), and they are a
/// function of exactly the binary — so **a change to the package's sources
/// bumps its version**, and `engine_answer_name_test` holds this name to it.
/// Its own file because the service is two files behind a conditional export,
/// and the name is one.
const String bundledEngine = 'stockfish-1.9.0-sf_19';
