
# Checking

collect everything from all files
score files


In Order

## Ordering

Parse
    - Job per file
    - Created when the file is first imported
Collect
    - Job per file
    - Created when parser finishes a file
Costing
    - Single Job
    - Created when parser finishes everything
Check
    - Job per file
    - Created for a file after all files in a package have been Costed.
    - Costings order jobs to favor leaf files first
Output
    - Job per package
    - Created after all files in a package have been checked

## Job Creation
