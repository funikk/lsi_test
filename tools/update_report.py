import sys
import os
from pathlib import Path
import json

# Add tools to sys.path so we can import from run_trial_plan
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_trial_plan

# Mock check_and_reexec_nix
run_trial_plan.check_and_reexec_nix = lambda x: None

# Call main with mocked args
sys.argv = ['run_trial_plan.py', 'VDRV_v1_core', '--update-report-only']
run_trial_plan.main()
