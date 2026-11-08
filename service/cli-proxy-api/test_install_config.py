import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch


class InstallConfigTest(unittest.TestCase):
    def test_rendered_secrets_are_yaml_strings(self):
        script = Path(__file__).with_name("install-config.py")
        with tempfile.TemporaryDirectory() as directory:
            previous = Path.cwd()
            try:
                os.chdir(directory)
                Path("config.yaml").write_text("key: ${TEST_KEY}\n", encoding="utf-8")
                with patch.dict(os.environ, {"TEST_KEY": 'a"b\nc'}), patch("subprocess.run") as run:
                    run.side_effect = lambda args, **kwargs: self.assertEqual(
                        Path(args[2]).read_text(encoding="utf-8"), 'key: "a\\"b\\nc"\n'
                    )
                    runpy.run_path(str(script))
            finally:
                os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
