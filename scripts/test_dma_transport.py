#!/usr/bin/env python3
"""Exercise dma_codex transport boundaries without invoking a model."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

LIB = Path(__file__).with_name('dma-lib.sh')
MOCK = r'''#!/usr/bin/env bash
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then out="$2"; shift; fi
  shift
done
cat > "$MOCK_INPUT"
case "$MOCK_MODE" in
  success) printf '## Answer\nFresh content\n' > "$out" ;;
  partial) printf 'partial' > "$out"; exit 7 ;;
  empty) : ;;
esac
'''

class TransportTests(unittest.TestCase):
    def invoke(self, mode, stale=False):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'codex').write_text(MOCK)
            (root / 'codex').chmod(0o700)
            prompt = root / 'prompt.md'
            prompt.write_text('中文 prompt\n' * 2000)
            out = root / 'output.md'
            if stale:
                out.write_text('existing artifact')
            env = dict(os.environ, PATH=d + os.pathsep + os.environ['PATH'],
                       MOCK_MODE=mode, MOCK_INPUT=str(root / 'stdin.txt'))
            result = subprocess.run(['bash', '-c',
                'source "$1"; dma_codex "$2" "$3" "$4" "$5"',
                'test', str(LIB), d, str(prompt), str(out), str(root / 'run.log')],
                env=env, capture_output=True, text=True)
            if stale:
                self.assertEqual(out.read_text(), 'existing artifact')
                self.assertFalse((root / 'stdin.txt').exists())
            else:
                self.assertEqual((root / 'stdin.txt').read_text(), prompt.read_text())
            return result

    def test_success_preserves_long_stdin(self):
        self.assertEqual(self.invoke('success').returncode, 0)

    def test_partial_output_cannot_mask_failure(self):
        self.assertEqual(self.invoke('partial').returncode, 7)

    def test_empty_success_rejected(self):
        self.assertNotEqual(self.invoke('empty').returncode, 0)

    def test_stale_artifact_rejected(self):
        self.assertNotEqual(self.invoke('success', stale=True).returncode, 0)

if __name__ == '__main__':
    unittest.main()
