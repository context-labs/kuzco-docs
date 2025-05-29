import os, sys
import re
from pathlib import Path
from argparse import ArgumentParser
from collections import defaultdict

# This is the url that gets subbed into the extracted code blocks, and then subbed back out when importing code blocks back into the docs.
# If you update this, double check that the code blocks, after imported, are using the correct base URL
# There's a reason why this is a const, and not a CLI parameter.
BASE_URL_OVERRIDE =  "https://api.kuzco.cool/v1" # None # "http://localhost:3001/v1"

BASE_URL_FOR_DOCS = "https://api.inference.net/v1"

# Get file extension for language
extensions = {
    'javascript': 'js', 
    'python': 'py',
    'typescript': 'ts',
    'bash': 'sh',
    'json': 'json',
    'jsonl': 'jsonl',
    'txt': 'txt'
}

comment = {
    'js': '//',
    'py': '#',
    'ts': '//',
    'sh': '#',
    'json': '//',
    'jsonl': '//',
    'txt': '//'
}

# Regular expression to match metadata and code blocks
metadata_pattern = r'<Metadata\s*text="([^"]+)"\s*/>'
code_pattern = r"```(\w+)[^\S\r\n]*([^\n]*)[^\S\r\n]*\n([\s\S]*?)```"

non_series_code_filepaths = []

def import_code_blocks(mdx_file):
    """Import code blocks from extracted files and update MDX file"""

    print("Importing code blocks into ", mdx_file)
    
    # Read the MDX file
    with open(mdx_file, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    new_lines = []
    i = 0
    
    while i < len(lines):
        metadata_match = re.search(metadata_pattern, lines[i])
        
        if not metadata_match:
            new_lines.append(lines[i])
            i += 1
            continue
            
        code_filepath = metadata_match.group(1)
        code_filepath, _ = maybe_extract_series(code_filepath)
        new_lines.append(lines[i])  # Keep metadata line
        i += 1
        
        # Look for code block after metadata
        rest_of_file = '\n'.join(lines[i:])
        code_match = re.search(code_pattern, rest_of_file, re.MULTILINE)
        
        if not code_match:
            continue
            
        # Get the full code block
        code_block_lines = code_match.group(0).split('\n')
        
        language = code_match.group(1).lower()
        ext = extensions.get(language, language)

        # Try to read corresponding code file
        full_path = Path("test/code_blocks") / (code_filepath + "." + ext)
        try:
            with open(full_path, 'r', encoding='utf-8') as f:
                imported_code = f.read().rstrip()
                
            # Replace code content but keep language markers
            new_lines.append(code_block_lines[0])  # Keep opening ```language line
            imported_code = imported_code.replace("http://localhost:3001/v1", BASE_URL_FOR_DOCS)
            if BASE_URL_OVERRIDE is not None:
                imported_code = imported_code.replace(BASE_URL_OVERRIDE, BASE_URL_FOR_DOCS)
            new_lines.extend(imported_code.split('\n'))
            new_lines.append('```')
            
        except FileNotFoundError:
            print(f"Warning: Could not find code file {full_path}")
            # Keep original code block if file not found
            new_lines.extend(code_block_lines)
            
        i += len(code_block_lines)
        
    # Write updated content back to file
    with open(mdx_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

    print("Done.")


def extract_code_blocks(mdx_file):
    """Extract code blocks from MDX file and save to appropriate directories"""

    print("Extracting code blocks from ", mdx_file)
    
    # Create base test/code_blocks directory if it doesn't exist
    base_dir = Path("test/code_blocks")
    base_dir.mkdir(parents=True, exist_ok=True)

    series_blocks = defaultdict(list)

    # Read the MDX file
    with open(mdx_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all code blocks with their preceding metadata
    lines = content.split('\n')
    
    for i, line in enumerate(lines):
        metadata_match = re.search(metadata_pattern, line)
        if not metadata_match:
            continue

        code_filepath = metadata_match.group(1)
        code_filepath, series = maybe_extract_series(code_filepath)

        rest_of_file = '\n'.join(lines[i:])
        code_match = re.search(code_pattern, rest_of_file, re.MULTILINE)

        language = code_match.group(1).lower()
        languageDisplay = code_match.group(2)
        code = code_match.group(3) 

        if code_filepath and not code:
            print("WARNING: No code found for metadata: ", code_filepath)
            continue

        if not code:
            continue
        
        if BASE_URL_OVERRIDE:
            code = code.replace(BASE_URL_FOR_DOCS, BASE_URL_OVERRIDE)

        ext = extensions.get(language, language)

        if series is not None:
            series_blocks[series].append(dict(code = code, ext = ext, code_filepath = code_filepath))

        # Use metadata path for directory structure
        file_path = Path.joinpath(base_dir, Path(code_filepath + "." + ext))
        dirname = os.path.dirname(file_path)
        os.makedirs(dirname, exist_ok=True)
        
        # Write code to file
        with open(file_path, 'w+', encoding='utf-8') as f:
            f.write(code)
        if series is None:
            non_series_code_filepaths.append(file_path)

        print("   Wrote code block to file: ", file_path)

    series_filepaths = set()
    for series, blocks in series_blocks.items():
        for i, block in enumerate(blocks):
            code = block["code"]
            ext = block["ext"]
            code_filepath = block["code_filepath"]
            mdx_filename = os.path.splitext(os.path.basename(mdx_file))[0]
            file_path = Path.joinpath(base_dir, "series", mdx_filename, Path(series + ".SERIES." + ext))
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            write_mode = "w" if file_path not in series_filepaths else "a"
            if file_path not in series_filepaths:
                series_filepaths.add(file_path)    
            with open(file_path, write_mode, encoding='utf-8') as f:
                f.write("\n\n")
                f.write(f"{comment[ext]} {series} {i} ({code_filepath})")
                f.write("\n\n")
                f.write(code)
            series_filepaths.add(file_path)

    print("Wrote the following series files:")
    for filepath in series_filepaths:
        print("  ", filepath)

    print("Done.")
        

def maybe_extract_series(code_filepath):
    """Extract series from code filepath if it exists"""
    series_regex = r"\[series=(\w+)\]"
    series_match = re.search(series_regex, code_filepath)
    if series_match:
        code_filepath_no_series = code_filepath[:series_match.start()]
        return code_filepath_no_series, series_match.group(1)
    else:
        return code_filepath,None


def parse_args():
    parser = ArgumentParser(description='Extract or import code blocks from MDX files')
    parser.add_argument('--import_code_blocks', action='store_true', help='Import code blocks from extracted files and update MDX file')
    parser.add_argument('--extract_code_blocks', action='store_true', help='Extract code blocks from MDX files')
    return parser.parse_args()

if __name__ == "__main__":

    args = parse_args()

    if not args.import_code_blocks and not args.extract_code_blocks:
        print("No action specified. Please specify either --import_code_blocks or --extract_code_blocks.")
        sys.exit(1)

    if args.import_code_blocks and args.extract_code_blocks:
        print("Cannot specify both --import_code_blocks and --extract_code_blocks.")
        sys.exit(1)

    if args.import_code_blocks:

        mdx_file = "features/function-calling.mdx"
        import_code_blocks(mdx_file)

        mdx_file = "features/structured-outputs.mdx"
        import_code_blocks(mdx_file)

        mdx_file = "features/batch-api.mdx"
        import_code_blocks(mdx_file)    

        mdx_file = "features/vision.mdx"
        import_code_blocks(mdx_file)

    if args.extract_code_blocks:
        mdx_file = "features/function-calling.mdx"
        extract_code_blocks(mdx_file)

        mdx_file = "features/structured-outputs.mdx"
        extract_code_blocks(mdx_file)

        mdx_file = "features/batch-api.mdx"
        extract_code_blocks(mdx_file)    

        mdx_file = "features/vision.mdx"
        extract_code_blocks(mdx_file)

        js_commands = []
        py_commands = []
        ts_commands = []
        sh_commands = []
        for filepath in non_series_code_filepaths:
            filepath = str(filepath)
            if filepath.endswith(".js"):
                js_commands.append(f"bun run {filepath}")
            elif filepath.endswith(".py"):
                py_commands.append(f"python3 {filepath}")
            elif filepath.endswith(".ts"):
                ts_commands.append(f"bun run {filepath}")
            elif filepath.endswith(".sh"):
                sh_commands.append(f"bash {filepath}")

        with open("test/code_blocks/ts_commands.sh", "w") as f:
            for command in ts_commands:
                f.write(command + "\n")
        with open("test/code_blocks/sh_commands.sh", "w") as f:
            for command in sh_commands:
                f.write(command + "\n")
        with open("test/code_blocks/py_commands.sh", "w") as f:
            for command in py_commands:
                f.write(command + "\n")
        with open("test/code_blocks/js_commands.sh", "w") as f:
            for command in js_commands:
                f.write(command + "\n")
