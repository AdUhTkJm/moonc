import subprocess
import sys
from pathlib import Path

def check_file(file_path):
  print(f"Checking {file_path}")
  result = subprocess.run(
    ["moon", "run", "src/test", str(file_path)],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
  )
  if "error:" in result.stdout or result.returncode != 0:
    print(f"Error in {file_path}.")
    return False

  return True

def main():
  test_dirs = [Path("test"), Path("mbtcorelib")]
  passed = True
  for directory in test_dirs:
    for file in directory.glob("*.txt"):
      if not check_file(file):
        passed = False
  
  if not passed:
    sys.exit(1)
  print("Passed.")

if __name__ == "__main__":
  main()
