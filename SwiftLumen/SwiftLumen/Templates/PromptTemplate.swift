import Foundation

/// A template for generating prompts with variable substitution
public struct PromptTemplate {
    /// The template string with placeholders
    private let template: String
    
    /// Regular expression for finding placeholders
    private static let placeholderRegex = try! NSRegularExpression(
        pattern: "\\{\\{\\s*([a-zA-Z0-9_]+)\\s*\\}\\}",
        options: []
    )
    
    /// Initialize a new prompt template
    /// - Parameter template: The template string with placeholders in the format {{variable}}
    public init(_ template: String) {
        self.template = template
    }
    
    /// Format the template with the provided variables
    /// - Parameter variables: Dictionary of variable names and their values
    /// - Returns: The formatted prompt string
    /// - Throws: LumenError.templateError if a required variable is missing
    public func format(variables: [String: String]) throws -> String {
        var result = template
        let matches = Self.placeholderRegex.matches(
            in: template,
            options: [],
            range: NSRange(template.startIndex..., in: template)
        )
        
        // Process matches in reverse order to avoid invalidating ranges
        for match in matches.reversed() {
            guard let variableRange = Range(match.range(at: 1), in: template) else {
                continue
            }
            
            let variableName = String(template[variableRange])
            
            guard let value = variables[variableName] else {
                throw LumenError.templateError(message: "Missing variable: \(variableName)")
            }
            
            guard let matchRange = Range(match.range, in: template) else {
                continue
            }
            
            let nsRange = NSRange(matchRange, in: result)
            result = (result as NSString).replacingCharacters(in: nsRange, with: value)
        }
        
        return result
    }
    
    /// Format the template with the provided variables
    /// - Parameters: Variable names and values as key-value pairs
    /// - Returns: The formatted prompt string
    /// - Throws: LumenError.templateError if a required variable is missing
    public func format(_ variables: [String: String]) throws -> String {
        return try format(variables: variables)
    }
    
    /// Format the template with the provided variables
    /// - Parameters: Variable names and values as key-value pairs
    /// - Returns: The formatted prompt string
    /// - Throws: LumenError.templateError if a required variable is missing
    public func format(_ variables: Any...) throws -> String {
        guard variables.count % 2 == 0 else {
            throw LumenError.templateError(message: "Variables must be provided as key-value pairs")
        }
        
        var variablesDict: [String: String] = [:]
        
        for i in stride(from: 0, to: variables.count, by: 2) {
            guard let key = variables[i] as? String else {
                throw LumenError.templateError(message: "Variable name must be a string")
            }
            
            let value = String(describing: variables[i + 1])
            variablesDict[key] = value
        }
        
        return try format(variables: variablesDict)
    }
} 