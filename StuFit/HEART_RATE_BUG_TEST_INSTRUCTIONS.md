# Heart Rate Bug Condition Exploration Test Instructions

## Overview

This document provides instructions for running the bug condition exploration test for the heart rate tracking freeze issue.

**CRITICAL**: These tests are EXPECTED TO FAIL on unfixed code. Test failure confirms the bug exists.

## Test File

- **Location**: `FullFitness/StuFit/HealthStoreHeartRateBugTests.swift`
- **Validates**: Requirements 2.1, 2.2, 2.3 from bugfix.md
- **Bug Condition**: Heart rate updates freeze during active workouts when stale heartRateAnchor is reused

## Setup Instructions

### 1. Add Test Target to Xcode Project

Since the project doesn't currently have a test target, you need to add one:

1. Open `FullFitness.xcodeproj` in Xcode
2. Go to File → New → Target
3. Select "Unit Testing Bundle" under iOS
4. Name it "StuFitTests"
5. Set the target to be tested as "StuFit"
6. Click Finish

### 2. Add Test File to Test Target

1. In Xcode's Project Navigator, locate `HealthStoreHeartRateBugTests.swift`
2. Select the file
3. In the File Inspector (right panel), check the box next to "StuFitTests" under Target Membership
4. Ensure the file is also a member of the "StuFit" target for @testable import to work

### 3. Configure Test Target Capabilities

The tests require HealthKit access:

1. Select the "StuFitTests" target in Xcode
2. Go to "Signing & Capabilities" tab
3. Add "HealthKit" capability (if not already present)
4. Ensure the test target has the same entitlements as the main app

### 4. Run on Physical Device or Simulator

HealthKit tests work best on:
- **Physical iOS device** (recommended) - provides real heart rate data
- **iOS Simulator** - may require mock data or will timeout

## Running the Tests

### Option 1: Run All Tests

```bash
cd FullFitness
xcodebuild test -scheme StuFit -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Option 2: Run in Xcode

1. Open the project in Xcode
2. Select Product → Test (⌘U)
3. Or click the diamond icon next to each test method to run individually

### Option 3: Run Specific Test

```bash
cd FullFitness
xcodebuild test -scheme StuFit \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:StuFitTests/HealthStoreHeartRateBugTests/testHeartRateUpdatesContinuouslyDuringActiveWorkout
```

## Expected Test Results on UNFIXED Code

### Test 1: `testHeartRateUpdatesContinuouslyDuringActiveWorkout`

**Expected Result**: ❌ FAIL (timeout or assertion failure)

**Why it fails**:
- The test expects at least 3 heart rate updates during an active workout
- On unfixed code, the stale `heartRateAnchor` causes the HKAnchoredObjectQuery to skip new samples
- Heart rate freezes at the initial value
- The expectation times out waiting for updates that never arrive

**Counterexample Output**:
```
Test Case '-[StuFitTests.HealthStoreHeartRateBugTests testHeartRateUpdatesContinuouslyDuringActiveWorkout]' failed (10.XXX seconds).
Asynchronous wait failed: Exceeded timeout of 10 seconds, with unfulfilled expectations: "Heart rate updates received".
```

### Test 2: `testStaleAnchorCausesHeartRateFreeze`

**Expected Result**: ❌ FAIL (timeout or assertion failure)

**Why it fails**:
- The test verifies that heart rate updates occur AFTER workout start time
- On unfixed code, the stale anchor prevents new samples from being delivered
- The test times out waiting for updates

**Counterexample Output**:
```
Test Case '-[StuFitTests.HealthStoreHeartRateBugTests testStaleAnchorCausesHeartRateFreeze]' failed (10.XXX seconds).
Asynchronous wait failed: Exceeded timeout of 10 seconds, with unfulfilled expectations: "Heart rate updates after workout start".
```

### Test 3: `testMultipleConsecutiveWorkoutsReceiveHeartRateUpdates`

**Expected Result**: ❌ FAIL on second workout (timeout or assertion failure)

**Why it fails**:
- First workout may receive updates (if no prior anchor exists)
- Second workout fails because the anchor from the first workout is reused
- The test demonstrates that the bug occurs across multiple workout sessions

**Counterexample Output**:
```
Test Case '-[StuFitTests.HealthStoreHeartRateBugTests testMultipleConsecutiveWorkoutsReceiveHeartRateUpdates]' failed (20.XXX seconds).
Asynchronous wait failed: Exceeded timeout of 10 seconds, with unfulfilled expectations: "Second workout heart rate updates".
XCTAssertGreaterThanOrEqual failed: ("0") is not greater than or equal to ("2") - Second workout should receive heart rate updates (bug: anchor not reset)
```

## Documenting Counterexamples

When tests fail, document the following:

1. **Test name** that failed
2. **Failure message** from Xcode
3. **Timeout duration** (indicates no updates received)
4. **Number of updates received** (should be 0 or very few)
5. **Workout state** (isWorkoutActive should be true)

Example documentation:

```
Bug Condition Confirmed:
- Test: testHeartRateUpdatesContinuouslyDuringActiveWorkout
- Result: FAILED (timeout after 10 seconds)
- Updates received: 0
- Workout active: true
- Conclusion: Heart rate updates freeze during active workout, confirming bug exists
```

## Expected Test Results on FIXED Code

After implementing the fix (resetting heartRateAnchor when starting workout):

### All Tests Should PASS ✅

- `testHeartRateUpdatesContinuouslyDuringActiveWorkout`: PASS - receives 3+ updates
- `testStaleAnchorCausesHeartRateFreeze`: PASS - receives updates after workout start
- `testMultipleConsecutiveWorkoutsReceiveHeartRateUpdates`: PASS - both workouts receive updates

## Troubleshooting

### Tests Don't Run

- Ensure test target is properly configured
- Check that HealthKit capability is enabled
- Verify @testable import works (file must be in both targets)

### Tests Pass Unexpectedly on Unfixed Code

This indicates:
- The bug may not be reproducible in the test environment
- HealthKit may not be providing data (simulator limitation)
- The root cause analysis may need revision

If this happens, try:
1. Run on a physical device with active heart rate monitoring
2. Ensure HealthKit authorization is granted
3. Check that heart rate data is available in the Health app

### HealthKit Authorization Issues

- Grant HealthKit permissions when prompted
- Check Settings → Privacy → Health → StuFit
- Ensure heart rate read permission is enabled

## Preservation Tests (Task 2)

### Overview

Preservation tests verify that non-workout heart rate functionality remains unchanged after the fix. These tests should PASS on both unfixed and fixed code.

### Test Methods

1. **`testBackgroundHeartRateMonitoringWorksWithoutWorkout`**
   - Validates: Requirements 3.1, 3.2, 3.3
   - Tests heart rate monitoring when isWorkoutActive == false
   - Expected: PASS on both unfixed and fixed code

2. **`testHeartRateQueriesWorkOutsideWorkoutSessions`**
   - Validates: Requirements 3.2, 3.3
   - Tests HealthKit queries outside workout context
   - Expected: PASS on both unfixed and fixed code

3. **`testInitialHeartRateDisplayAtWorkoutStart`**
   - Validates: Requirement 3.1
   - Tests initial heart rate display at workout start
   - Expected: PASS on both unfixed and fixed code

4. **`testHealthKitDataRetrievalWorksForAllQueryTypes`**
   - Validates: Requirement 3.2
   - Tests various HealthKit query types (steps, workouts, heart rate aggregates)
   - Expected: PASS on both unfixed and fixed code

5. **`testHeartRateTrackingWorksAcrossMultipleWorkoutTypes`**
   - Validates: Requirement 3.4
   - Tests heart rate tracking across different workout types
   - Expected: PASS on both unfixed and fixed code

### Running Preservation Tests

Run all preservation tests:

```bash
cd FullFitness
xcodebuild test -scheme StuFit -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:StuFitTests/HealthStoreHeartRateBugTests/testBackgroundHeartRateMonitoringWorksWithoutWorkout \
  -only-testing:StuFitTests/HealthStoreHeartRateBugTests/testHeartRateQueriesWorkOutsideWorkoutSessions \
  -only-testing:StuFitTests/HealthStoreHeartRateBugTests/testInitialHeartRateDisplayAtWorkoutStart \
  -only-testing:StuFitTests/HealthStoreHeartRateBugTests/testHealthKitDataRetrievalWorksForAllQueryTypes \
  -only-testing:StuFitTests/HealthStoreHeartRateBugTests/testHeartRateTrackingWorksAcrossMultipleWorkoutTypes
```

### Expected Results

All preservation tests should PASS on unfixed code, confirming:
- Background heart rate monitoring works correctly
- Heart rate queries outside workouts function properly
- Initial heart rate display at workout start is correct
- HealthKit integration works for all query types
- Heart rate tracking works across all workout types

## Next Steps

1. Run the bug condition exploration tests on unfixed code (Task 1 - COMPLETED)
2. Run the preservation tests on unfixed code (Task 2 - CURRENT)
3. Document that preservation tests pass (confirms baseline behavior)
4. Proceed to Task 3: Implement the fix
5. Re-run bug condition tests on fixed code to verify they pass
6. Re-run preservation tests on fixed code to verify no regressions

## Notes

- These tests use real HealthKit APIs and require proper device setup
- Test execution time may vary based on HealthKit data availability
- The 10-second timeout is intentionally short to quickly identify the bug
- On fixed code, tests should complete in 2-3 seconds with successful updates
