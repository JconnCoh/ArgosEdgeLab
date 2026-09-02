function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}
$root = 'D:\R31VAL2'
$casePath = Join-Path $root 'FROZEN_CASES.json'
$summaryPath = Join-Path $root 'SUMMARY.json'
$jobPath = Join-Path $root 'J92.json'
$resultPath = Join-Path $root 'O92\RESULT.json'
$cases = Get-Content -LiteralPath $casePath -Raw | ConvertFrom-Json
$case = @($cases)[92]
$job = Get-Content -LiteralPath $jobPath -Raw | ConvertFrom-Json
[ordered]@{
    schema = 'argos_r31val2_case_92_lock_v1'
    computerName = $env:COMPUTERNAME
    frozenCasesSha256 = Sha $casePath
    summarySha256 = Sha $summaryPath
    jobSha256 = Sha $jobPath
    resultSha256 = Sha $resultPath
    id = $case.id
    bf = $job.bf
    bfSha256 = $job.bfSha256
    df = $job.df
    dfSha256 = $job.dfSha256
    expectedPairedCandidateCount = $case.expectedPairedCandidateCount
    imageBytesRead = $false
    taskOrProcessActionPerformed = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Compress
