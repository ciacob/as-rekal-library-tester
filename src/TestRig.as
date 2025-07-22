package {

    /**
     * Generic-purpose unit testing facility.
     */
    public class TestRig {

        private static const PROVIDER_RTE:String = 'providerRTE';
        private static const VALIDATOR_RTE:String = 'validatorRTE';
        private static const SKIP:String = 'skip';

        /**
         * @constructor
         * @param   handleFaultyTests
         *          Optional, default `true`.
         *          Whether to wrap all executed tests in `try...catch`
         *          blocks, and report as faulty those that throw
         *          exceptions.
         *
         *          Note that, for debug purposes, it could also be useful
         *          to simply let such tests throw errors, as your
         *          IDE probably provides superior debug facilities for RTEs.
         *          When this is the case, set this argument to `false`.
         */
        public function TestRig(handleFaultyTests:Boolean = true) {
            _handleFaultyTests = handleFaultyTests;
        }

        /**
         * Whether to `try...catch` tests execution instead of simply
         * permitting them to throw RTEs..
         */
        private var _handleFaultyTests:Boolean;

        /**
         * Internal storage for optional user-provided function to receive the final
         * report on tests execution. Will be called with a text summary and the
         * full results dataset.
         */
        private var _reportDelegate:Function;

        /**
         * Internal tests registry.
         */
        private const _tests:Array = [];

        /**
         * Test results storage.
         */
        private const _results:Object = {pass: [],
                fail: [],
                error: []};

        /**
         * Helper, trims a string. Returns an empty string for `null`.
         */
        private function _trim(str:String):String {
            if (!str) {
                return '';
            }
            return str.replace(/^\s+|\s+$/g, '');
        }

        /**
         * Helper, for sorting two Objects by their `order` field.
         */
        private function _byOrder(a:Object, b:Object):int {
            return (!a || !b) ? 0 : (a.order || 0) - (b.order || 0);
        }

        /**
         * Registers a test that needs to be executed.
         *
         * @param   info
         *          Description of the test.
         *
         * @param   validator
         *          Expected outcome of the test, or function that validates
         *          whether test passes. It will be called with `testValue` and
         *          `commit` (see next).
         *
         * @param   testValue
         *          A value that is relevant for testing purposes, i.e., the
         *          "actual result" of the test. Calculated when registering
         *          the test (see `addTest`).
         *
         * @param   commit
         *          Dedicated closure for reporting this test's outcome. Built
         *          when registering the test (see `addTest`).
         * 
         * @param   order
         *          Numeric value to use for sorting.
         */
        private function _registerTest(info:String, validator:*, testValue:*, commit:Function, order:int):void {
            _tests.push({order: order,
                    info: info,
                    validator: validator,
                    testValue: testValue,
                    commit: commit});
        }

        /**
         * Registers a test that caused a Run Time Error (RTE) while it was added or executed.
         *
         * @param   info
         *          Description of the test.
         *
         * @param   failureType
         *          Whether failure occurred when adding or executing. Expects one of the
         *          constants `PROVIDER_RTE` or `VALIDATOR_RTE`.
         *
         * @param   error
         *          The originally thrown Error.
         * 
         * @param   order
         *          Numeric value to use for sorting.
         */
        private function _registerFaultyTest(info:String, failureType:String, error:Error, order:int):void {
            _results.error.push({order: order,
                    info: info,
                    kind: failureType,
                    message: error.message,
                    stack: error.getStackTrace()});
        }

        /**
         * Registers a passing test result.
         * @param   info
         *          Description of the test.
         *
         * @param   result
         *          Actual result of the test.
         *
         * @param   expectedResult
         *          Expected result of the test.
         *
         * @param   order
         *          Numeric value to use for sorting.
         */
        private function _registerPassResult(info:String, result:*, expectedResult:*, order:int):void {
            _results.pass.push({order: order,
                    info: info,
                    result: result,
                    expectedResult: expectedResult});
        }

        /**
         * Registers a failing test result.
         * @param   info
         *          Description of the test.
         *
         * @param   result
         *          Actual result of the test.
         *
         * @param   expectedResult
         *          Expected result of the test.
         *
         * @param   order
         *          Numeric value to use for sorting.
         */
        private function _registerFailResult(info:String, result:*, expectedResult:*, order:int):void {
            _results.fail.push({order: order,
                    info: info,
                    result: result,
                    expectedResult: expectedResult});
        }

        /**
         * Compiles, returns and (optionally) traces information about a passed test.
         *
         * @param   detail
         *          Detail about the test. Will be prefixed by "[PASS] ".
         *
         * @param   print
         *          Optional, default true. Whether to also trace.
         *
         * @return  Compiled information.
         */
        private function _doPassInfo(detail:String, print:Boolean = true):String {
            const info:String = "[PASS] " + detail;
            if (print) {
                trace(info);
            }
            return info;
        }

        /**
         * Compiles, returns and (optionally) traces information about a failed test.
         *
         * @param   detail
         *          Detail about the test. Will be prefixed by "[FAIL] ".
         *
         * @param   testValue
         *          If `validator` is not a function, will be included in compiled information
         *          as "Got: <testValue>".
         *
         * @param   validator
         *          If a function, will not be included in the compiled information. Otherwise,
         *          included as "Expected: <validator>".
         *
         * @param   print
         *          Optional, default true. Whether to also trace.
         *
         * @return  Compiled information.
         */
        private function _doFailInfo(detail:String, testValue:*, validator:*, print:Boolean = true):String {
            const info:String = "[FAIL] " + detail + ((validator is Function) ? '' : " - Expected: " + validator + ", Got: " + testValue);
            if (print) {
                trace(info);
            }
            return info;
        }

        /**
         * Compiles, returns and (optionally) traces information about a malfunctioning test.
         * @param   detail
         *          Detail about the test. Will be prefixed by "[ERROR] ".
         *
         * @param   kind
         *          String, one of `PROVIDER_RTE` or `VALIDATOR_RTE`, to indicate whether either
         *          the test's provider function or validator function threw a Run Time Exception.
         *
         * @param   message
         *          The original message of the thrown and caught RTE.
         *
         * @param   stack
         *          If available, the original stacktrace of the thrown and caught RTE.
         *
         * @param   print
         *          Optional, default true. Whether to also trace.
         *
         * @return  Compiled information.
         */
        private function _doErrorInfo(detail:String, kind:String, message:String, stack:String, print:Boolean = true):String {
            const info:String = '[ERROR][' + kind + ']' + detail + '\n' + message + (stack ? '\n' + stack : '');
            if (print) {
                trace(info);
            }
            return message;
        }

        /**
         * Compiles, returns and (optionally) traces summary about all executed tests,
         * detailing all the failures.
         */
        private function _doSummary(print:Boolean = true):String {
            const lines:Array = ['--------------------',
                'Results:',
                'Passed: ' + _results.pass.length,
                'Failed: ' + _results.fail.length,
                'Errors: ' + _results.error.length];
            if (_results.error.length > 0) {
                lines.push('Tests with errors:');
                _results.error.sort(_byOrder);
                for each (var error:Object in _results.error) {
                    lines.push('- ' + _doErrorInfo(error.info, error.kind, error.message, null, false));
                }
            }
            if (_results.fail.length > 0) {
                lines.push('Failures:');
                _results.fail.sort(_byOrder);
                for each (var fail:Object in _results.fail) {
                    lines.push('- ' + _doFailInfo(fail.info, fail.result, fail.expectedResult, false));
                }
            }
            if (!_results.error.length && !_results.fail.length) {
                lines.push('ALL TESTS PASSED!');
            }
            lines.push('--------------------');
            const summary:String = lines.join('\n');
            if (print) {
                trace(summary);
            }
            return summary;
        }

        /**
         * Registers a test to be executed.
         *
         * @param   info
         *          Description of the test.
         *
         * @param   provider
         *          Function to produce and return a finite value that will later be
         *          subjected to testing. Should expect no arguments and can return
         *          any value.
         *
         * @param   validator
         *          Essentially the expected result of the test. Can be a value or a function.
         *
         *          If a value is provided, it must match exactly the result returned by
         *          `provider()` for the test to pass.
         *
         *          If a function is provided, it will be called with the result of
         *          `provider()` and with a closure that MUST be sent either `true` or `false`
         *          based on whether test execution should be considered successful or not.
         *
         *          NOTE:
         *          Async tests MUST use a function for `validator` (but sync tests can leverage
         *          that as well).
         */
        public function addTest(info:String, provider:Function, validator:*):void {
            const order:int = _tests.length;
            info = _trim(info) || "Test " + (order + 1);
            var testValue:* = SKIP; // Assume test as faulty unless proven otherwise

            // Handle RTEs thrown by the `provider` function if `_handleFaultyTests` is `true`.
            if (_handleFaultyTests) {
                try {
                    testValue = provider();
                } catch (e:Error) {
                    _registerFaultyTest(info, PROVIDER_RTE, e, order);
                    _doErrorInfo(info, PROVIDER_RTE, e.message, e.getStackTrace());
                }
            } else {
                testValue = provider();
            }

            // Async adapter. Provides unified handling for both sync and async tests.
            const commit:Function = function(testPassed:Boolean):void {

                // Individually register tests as passed or failed
                if (testPassed) {
                    _registerPassResult(info, testValue, validator, order);
                    _doPassInfo(info);
                } else {
                    _registerFailResult(info, testValue, validator, order);
                    _doFailInfo(info, testValue, validator);
                }

                // Produce a summary once all tests were executed
                if (_results.pass.length + _results.fail.length + _results.error.length == _tests.length) {
                    const summary:String = _doSummary();
                    if (_reportDelegate !== null) {
                        _reportDelegate(summary, _results);
                    }
                }
            };

            _registerTest(info, validator, testValue, commit, order);
        }

        /**
         * Executes all registered tests.
         * Outputs partial test results to the console and a summary after all tests complete.
         *
         * NOTES:
         * If there are async tests being executed, the order of the outputted partial test
         * results cannot be predicted.
         *
         * If all tests do not get executed (i.e., due to faulty tests), the summary will not
         * be provided.
         *
         * @param   report
         *          Optional, function to be called when all tests have completed. Will be
         *          called with a text summary and the  full results dataset.
         *
         *          The dataset is an Object with `pass` and `fail` Object Arrays. Each
         *          Object will contain `info`, `result` and `expectedResult`.
         */
        public function execute(report:Function = null):void {
            _reportDelegate = null;
            _results.pass.length = 0;
            _results.fail.length = 0;

            if (report !== null) {
                _reportDelegate = report;
            }

            for each (var test:Object in _tests) {
                const testValue:* = test.testValue;

                // Skip tests that threw RTEs in their producer function
                if (testValue == SKIP) {
                    continue;
                }

                const info:String = test.info;
                const validator:* = test.validator;
                const commit:Function = test.commit;

                // If `expected` is a function, call it with the result.
                if (validator is Function) {

                    // Handle RTEs thrown by the `validator` function if `_handleFaultyTests` is `true`.
                    if (_handleFaultyTests) {
                        try {
                            validator(testValue, commit);
                        } catch (e:Error) {
                            _registerFaultyTest(info, VALIDATOR_RTE, e, test.order);
                            _doErrorInfo(info, VALIDATOR_RTE, e.message, e.getStackTrace());
                        }
                    } else {
                        validator(testValue, commit);
                    }

                } else {
                    // Otherwise, compare the value directly and call the commit closure with the
                    // result of the comparison.
                    commit(testValue === validator);
                }
            }
        }

        /**
         * Removes all registered tests and all gathered results, allowing this `TestRig` instance
         * to be reused.
         *
         * Note:
         * If there are hung async tests, calling `reset` does not cancel their execution. To cope
         * with such a situation, destroy the `TestRig` instance and create a fresh one.
         */
        public function reset():void {
            _tests.length = 0;
            _results.pass.length = 0;
            _results.fail.length = 0;
            _results.error.length = 0;
        }
    }
}
