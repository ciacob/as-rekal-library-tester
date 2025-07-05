package {

    import com.github.ciacob.asrekallibrary.Preset;
    import flash.filesystem.File;

    /**
     * Unit tests for the Rekal library.
     *
     */
    public class RekalTest {

        public function RekalTest() {
        }

        /**
         * Test results storage.
         */
        private const _results:Object = {pass: [],
                fail: []};

        /**
         * Registers a passing test result.
         * @param info Description of the test.
         * @param result Actual result of the test.
         * @param expectedResult Expected result of the test.
         */
        private function _registerPassResult(info:String, result:*, expectedResult:*):void {
            _results.pass.push({info: info,
                    result: result,
                    expectedResult: expectedResult});
        }

        /**
         * Registers a failing test result.
         * @param info Description of the test.
         * @param result Actual result of the test.
         * @param expectedResult Expected result of the test.
         */
        private function _registerFailResult(info:String, result:*, expectedResult:*):void {
            _results.fail.push({info: info,
                    result: result,
                    expectedResult: expectedResult});
        }

        /**
         * Runs a test with the given info, injected data provider, and an expected
         * result or validator.
         *
         * @param   info
         *          Description of the test.
         *
         * @param   provider
         *          Function to obtain a finite value that will be subjected to testing.
         *          Expects no arguments and can return any value.
         *
         * @param   expected
         *          Expected result of the test. Can be a value or a function.
         *          If a value is provided, it must match exactly the result of
         *          `provider()` for the test to pass.
         *          If a function is provided, it will be called with the result of
         *          `provider()` and must actually decide whether the test passed or failed
         *          by returning `true` or `false`.
         *
         * @return  Returns `true` if the test passed, `false` otherwise.
         */
        public function test(info:String, provider:Function, expected:*):Boolean {
            var valueToTest:* = provider();
            var testPassed:Boolean = false;

            // If `expected` is a function, call it with the result.
            if (expected is Function) {
                testPassed = expected(valueToTest);
            } else {
                // Otherwise, compare the value directly
                testPassed = (valueToTest === expected);
            }
            if (testPassed) {
                _registerPassResult(info, valueToTest, expected);
                trace("[PASS] " + info);
                return true;
            } else {
                _registerFailResult(info, valueToTest, expected);
                trace("[FAIL] " + info + " - Expected: " + expected + ", Got: " + valueToTest);
                return false;
            }
        }

        /**
         * Runs all tests in the ShardTest class.
         * Outputs the results to the console.
         */
        public function run():Object {
            _results.pass.length = 0;
            _results.fail.length = 0;

            // Call test suite functions from in-here, e.g.:
            testSuite_PresetBasic();
            testSuite_PresetPersistence();
            testSuite_PresetCloning();

            trace('--------------------');
            trace('Results:');
            trace('Passed: ' + _results.pass.length);
            trace('Failed: ' + _results.fail.length);
            if (_results.fail.length > 0) {
                trace('Failures:');
                for each (var fail:Object in _results.fail) {
                    trace(' - ' + fail.info + ' | Expected: ' + fail.expectedResult + ', Got: ' + fail.result);
                }
            } else {
                trace('ALL TESTS PASSED!');
            }

            return _results;
        }


        /**
         * Tests basic functionality.
         */
        private function testSuite_PresetBasic():void {
            trace("Running Preset Basic Tests...");

            test("Constructor accepts name and shallow settings", function():* {
                const p:Preset = new Preset("Test1", {brightness: 90});
                return p.name == "Test1" && p.settings.$get("brightness") == 90;
            }, true);

            test("Constructor defaults to mutable", function():* {
                const p:Preset = new Preset("Test2", {volume: 50});
                p.name = "NewName";
                p.settings.$set("volume", 75);
                return p.name == "NewName" && p.settings.$get("volume") == 75;
            }, true);

            test("Constructor applies readonly if conditions met", function():* {
                const p:Preset = new Preset("Locked", {contrast: 100}, true);
                p.name = "Changed";
                p.settings.$set("contrast", 0);
                return p.name == "Locked" && p.settings.$get("contrast") == 100;
            }, true);

            const initialSettings:Object = {volume: 75,
                    theme: "dark"};
            const preset:Preset = new Preset("UserPreset1", initialSettings);
            test("Name is assigned correctly", function():* {
                return preset.name;
            }, "UserPreset1");

            test("Settings object exposes correct volume", function():* {
                return preset.settings.$get("volume");
            }, 75);

            test("Settings object exposes correct theme", function():* {
                return preset.settings.$get("theme");
            }, "dark");

            test("Hash reflects settings only, not name", function():* {
                const p1:Preset = new Preset("A", {x: 1});
                const p2:Preset = new Preset("B", {x: 1});
                return p1.hash == p2.hash;
            }, true);

            test("Hash differs on settings change", function():* {
                const p1:Preset = new Preset("P1", {a: 1});
                const p2:Preset = new Preset("P2", {a: 2});
                return p1.hash != p2.hash;
            }, true);

            test("Hash changes after mutation", function():* {
                const originalHash:String = preset.hash;
                preset.settings.$set("volume", 20);
                return (preset.hash != originalHash);
            }, true);

            test("Readonly prevents name change", function():* {
                const locked:Preset = new Preset("SystemPreset", initialSettings, true);
                const originalName:String = locked.name;
                locked.name = "Tampered";
                return (locked.name == originalName);
            }, true);

            test("Readonly prevents settings change", function():* {
                const locked:Preset = new Preset("Locked", initialSettings, true);
                locked.settings.$set("volume", 100);
                return (locked.settings.$get("volume") == 75);
            }, true);

            test("Readonly returns false when conditions not met", function():* {
                const p : Preset = new Preset(null, null, true);
                return p.readonly;
            }, false);

            test("Readonly returns true when all conditions met", function():* {
                const p : Preset = new Preset("System", {lang: "EN"}, true);
                return p.readonly;
            }, true);
        }

        /**
         * Test persistence-related functionality.
         */
        private function testSuite_PresetPersistence():void {
            trace("Running Preset Persistence Tests...");

            const initialSettings:Object = {brightness: 50,
                    resolution: "1080p"};

            const file:File = File.applicationStorageDirectory.resolvePath("temp_preset_test.rekal");
            if (file.exists) {
                file.deleteFile();
            }

            const original:Preset = new Preset("PersistMe", initialSettings, true);

            test("Preset can be written to disk", function():* {
                return original.toDisk(file);
            }, true);

            test("File exists after toDisk()", function():* {
                return file.exists;
            }, true);

            const restored:Preset = Preset.fromDisk(file);

            test("Restored Preset is not null", function():* {
                return restored != null;
            }, true);

            test("Restored Preset has same name", function():* {
                if (!restored) {
                    return null;
                }
                return restored.name;
            }, "PersistMe");

            test("Restored Preset preserves readonly flag", function():* {
                if (!restored) {
                    return null;
                }
                return restored.readonly;
            }, true);

            test("Restored Preset has same hash as original", function():* {
                if (!restored) {
                    return null;
                }
                return restored.hash == original.hash;
            }, true);

            test("Restored Preset preserves setting (resolution)", function():* {
                if (!restored) {
                    return null;
                }
                return restored.settings.$get("resolution");
            }, "1080p");

            test("Overriding file works", function():* {
                if (!restored) {
                    return null;
                }
                return original.toDisk(file, true);
            }, true);

            test("Preset.fromDisk returns null on missing file", function():* {
                const missingFile:File = File.applicationStorageDirectory.resolvePath("doesNotExist.preset");
                return Preset.fromDisk(missingFile) == null;
            }, true);

            // Clean up
            if (file.exists) {
                try {
                    file.deleteFile();
                } catch (e:Error) {
                    trace("Cleanup failed for test file.");
                }
            }
        }

        /**
         * Test clone-related functionality.
         */
        private function testSuite_PresetCloning():void {
            test("Clone preserves structure", function():* {
                const p1:Preset = new Preset("Original", {z: 99});
                const p2:Preset = p1.clone();
                return p2.name == "Original" && p2.settings.$get("z") == 99;
            }, true);

            test("Clone allows readonly override", function():* {
                const p1:Preset = new Preset("System", {x: 10}, true);
                const p2:Preset = p1.clone(false);
                p2.name = "Editable";
                p2.settings.$set("x", 20);
                return p2.name == "Editable" && p2.settings.$get("x") == 20;
            }, true);
        }

    }
}
