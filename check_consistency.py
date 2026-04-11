import os
import re

overlay_dir = r"C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

files = sorted([f for f in os.listdir(overlay_dir) if f.endswith('.ini')])

print(f"Checking {len(files)} preset files for consistency...\n")

issues = []
total_issues = 0

for filename in files:
    filepath = os.path.join(overlay_dir, filename)
    file_issues = []

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')

    # Check 1: OVERLAYINFO section exists
    if '[OVERLAYINFO]' not in content:
        file_issues.append("Missing [OVERLAYINFO] section")

    # Check 2: Required fields in OVERLAYINFO
    required_fields = ['UIName', 'UIGroups', 'UIDesc', 'UIOrdering', 'NeedsNoApply', 'IncompatibleOverlays']
    for field in required_fields:
        if f'{field} =' not in content and f'{field}=' not in content:
            file_issues.append(f"Missing required field: {field}")

    # Check 3: OVERLAYPARAM numbering
    param_matches = re.findall(r'\[OVERLAYPARAM(\d+)\]', content)
    if param_matches:
        param_nums = [int(n) for n in param_matches]
        expected = list(range(1, len(param_nums) + 1))
        if param_nums != expected:
            file_issues.append(f"OVERLAYPARAM numbering issue: found {param_nums[:5]}{'...' if len(param_nums) > 5 else ''}, expected sequential from 1")

    # Check 4: Each OVERLAYPARAM has required fields
    param_blocks = re.findall(r'\[OVERLAYPARAM\d+\](.*?)(?=\[OVERLAYPARAM|\[OVERLAYINFO|$)', content, re.DOTALL)
    for i, block in enumerate(param_blocks, 1):
        has_category = 'Category =' in block or 'Category=' in block
        has_filename = 'FileName =' in block or 'FileName=' in block
        has_name = 'Name =' in block or 'Name=' in block
        has_operation = 'Operation =' in block or 'Operation=' in block

        if not has_category and not has_filename:
            file_issues.append(f"OVERLAYPARAM{i}: Missing Category/FileName")
        if not has_name:
            file_issues.append(f"OVERLAYPARAM{i}: Missing Name")
        if not has_operation:
            file_issues.append(f"OVERLAYPARAM{i}: Missing Operation")

    # Check 5: Multiple trailing blank lines
    trailing_blanks = 0
    for line in reversed(lines):
        if line.strip() == '':
            trailing_blanks += 1
        else:
            break
    if trailing_blanks > 1:
        file_issues.append(f"Multiple trailing blank lines: {trailing_blanks}")

    # Check 6: UIOrdering matches filename number
    filename_match = re.match(r'^(\d+)\.', filename)
    if filename_match:
        filename_num = int(filename_match.group(1))
        ordering_match = re.search(r'UIOrdering\s*=\s*(\d+)', content)
        if ordering_match:
            ordering_num = int(ordering_match.group(1))
            if filename_num != ordering_num:
                file_issues.append(f"UIOrdering mismatch: filename={filename_num}, UIOrdering={ordering_num}")

    if file_issues:
        issues.append((filename, file_issues))
        total_issues += len(file_issues)

# Print results
if issues:
    print(f"Found {total_issues} issues in {len(issues)} files:\n")
    for filename, file_issues in issues:
        print(f"  {filename}:")
        for issue in file_issues:
            print(f"    - {issue}")
        print()
else:
    print("All files passed consistency checks!")

print(f"\nSummary: {len(files)} files checked, {len(issues)} files with issues, {total_issues} total issues")
