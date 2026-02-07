public enum ParseError: Error, Equatable {
    case emptyExpression
    // Parsing
    case missingWrapperArgument, invalidWrapperArgument, missingFragmentArguments, invalidFragmentArguments, invalidFragmentArgument, unrecognizedSymbol, unrecognizedSymbolsAtEnd
    // Evaluating
    case wrongArgumentCount(fragment: String), unrecognizedWrapper(String), unrecognizedFragment(String), invalidWrapperArgumentType, invalidFragmentArgumentType
    case invalidArgumentValue
}
