#######################################
# Function Override Data Structures
#######################################

# Represents a counter
Count = Int64

# Represents an ast head distribution
AstInfo = Dict{Symbol, Count}

# Represents the a function name distribution
FunctionInfo = Dict{String, Count}

# Represents the distribution of function definition types
mutable struct FuncDefTracker
    newFuncCount :: Count
    funcRedefCount :: Count
    miscCount :: Count
    bodylessFuncCount :: Count
end
# Initializes a base representation of function type tracker
FuncDefTracker() = FuncDefTracker(0,0,0,0)

# Represents the information collected regarding eval function calls
mutable struct EvalInfo
    astHeads :: AstInfo
    funcDefTypes :: FuncDefTracker
end

# Represents the information collected regarding eval function calls
mutable struct InvokeLatestInfo
    funcNames :: FunctionInfo
end

# Represents the information collected regarding the stacktrace of a function call
mutable struct StackTraceInfo{T}
    count :: Count
    auxillary  :: T
end
# Initializes a base representation of stacktrace information
StackTraceInfo(funcSpecificData) = StackTraceInfo(0, funcSpecificData)

# Represents the information collected regarding overriden function calls
mutable struct FuncMetadata{T, U}
    callCount :: Count
    stackTraces :: Dict{StackTraces.StackFrame, StackTraceInfo{U}}
    funcSpecificData :: T
end
# Initializes a base representation of function metadata
FuncMetadata(funcSpecificData;
        initialTrace=Dict{StackTraces.StackFrame, StackTraceInfo{Nothing}}()
    ) = FuncMetadata(0, initialTrace, funcSpecificData)

# Represents the information being analyzed when running packages
mutable struct OverrideInfo
    identifier :: String
    # Determines if frame particular classification (ie. source-file, internal-file, external-file)
    stackFramePredicate :: Function
    evalInfo :: FuncMetadata{EvalInfo}
    invokeLatestInfo :: FuncMetadata{InvokeLatestInfo}
end
# Initializes a base representation of override information
OverrideInfo(identifier :: String, functionDataFilter :: Function) =
    OverrideInfo(identifier, functionDataFilter,
        FuncMetadata(EvalInfo(Dict(), FuncDefTracker());
            initialTrace=Dict{StackTraces.StackFrame,StackTraceInfo{AstInfo}}()),
        FuncMetadata(InvokeLatestInfo(Dict());
            initialTrace=Dict{StackTraces.StackFrame,StackTraceInfo{FunctionInfo}}())
    )
