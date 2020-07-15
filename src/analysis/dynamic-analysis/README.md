# Dynamic Analysis

A dynamic analysis tool that analyzes the use of eval and invokeLatest in the Julia language

## Analyze Packages

1. Simply populate the `PKGS_TO_ANALYZE` array in the `analyze-packages.jl` file with the names of the packages you'd like to analyze.

2. Run the following command `julia analyze-packages.jll` (NOTE: your julia version must be >= 1.5.0).

3. The analyzed data of each package will be written to the `output.json` file in the form:

```
{
  "eval_info": {
    "call_count": Int,
    "stack_traces": [
      {
        "count": Int,
        "last_call": String
      }
    ],
    "func_specific_data": {
      "ast_heads": [
        {
          "count": Int,
          "ast_head": String
        }
      ]
    }
  },
  "invokelatest_info": {
    "call_count": Int,
    "stack_traces": [
      {
        "count": Int,
        "last_call": String
      }
    ],
    "func_specific_data": {
      "function_names": [
          {
            "count": Int,
            "function_name": String
          }
      ]
    }
  }
}
```
