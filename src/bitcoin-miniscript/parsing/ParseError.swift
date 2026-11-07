public enum ParseError: Error, Equatable {
    case emptyExpression
    // Parsing
    case missingWrapperArgument, invalidWrapperArgument, missingFragmentArguments, invalidFragmentArguments,
        invalidFragmentArgument, unrecognizedSymbol, unrecognizedSymbolsAtEnd
    // Evaluating
    case wrongArgumentCount(fragment: String)
    case unrecognizedWrapper(String)
    case unrecognizedFragment(String)
    case invalidWrapperArgumentType, invalidFragmentArgumentType
    case invalidArgumentValue
}
