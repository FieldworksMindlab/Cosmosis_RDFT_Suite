#!/usr/bin/env python3
"""Compile the real Processing sketch and run headless portal regressions.

Uses Processing's own PDE preprocessor, Java runtime and libraries. No hand
translation or mocked geometry. Outputs compiler files to a temporary directory.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--processing', type=Path, default=Path('/Applications/Processing.app'))
parser.add_argument('--compile-only', action='store_true', help='Compile the full sketch and regression runner without running tests')
parser.add_argument('--fit-output', type=Path, help='Write the dodeca F6 mating pair and validation JSON here')
args = parser.parse_args()
sketch = Path(__file__).resolve().parents[1]
app = args.processing / 'Contents/app'
java = app / 'resources/jdk/bin/java'
javac = app / 'resources/jdk/bin/javac'
with tempfile.TemporaryDirectory(prefix='cosmosis-portals-') as tmp:
    tmp = Path(tmp)
    cp = str(app / '*') + os.pathsep + str(tmp)
    preprocess = tmp / 'Preprocess.java'
    preprocess.write_text('''
import java.nio.file.*;
import java.io.*;
import processing.mode.java.preproc.*;
public class Preprocess {
 public static void main(String[] args) throws Exception {
  Path dir=Paths.get(args[0]);
  StringBuilder code=new StringBuilder(Files.readString(dir.resolve("Cosmosis_Visual_Observatory.pde")));
  try(var files=Files.list(dir)) {
   for(Path p:files.filter(p->p.toString().endsWith(".pde")&&!p.getFileName().toString().equals("Cosmosis_Visual_Observatory.pde")).sorted().toList())
    code.append("\\n").append(Files.readString(p));
  }
  try(var out=new FileWriter(args[1])) {
   PdePreprocessor.builderFor("Cosmosis_Visual_Observatory").setIsTesting(true).build().write(out,code.toString());
  }
 }
}
''')
    def run(*cmd):
        subprocess.run([str(x) for x in cmd], check=True)
    run(javac, '-cp', cp, preprocess)
    generated = tmp / 'Cosmosis_Visual_Observatory.java'
    run(java, '-cp', cp, 'Preprocess', sketch, generated)
    run(javac, '-cp', cp, '-d', tmp, generated, sketch / 'tools/StraightPortalRegression.java')
    if args.compile_only:
        print('FULL SKETCH COMPILE PASS')
        raise SystemExit(0)
    command = [java, '-Xmx3g', '-Djava.awt.headless=true', '-cp', cp, 'StraightPortalRegression']
    if args.fit_output:
        args.fit_output.mkdir(parents=True, exist_ok=True)
        command.append(args.fit_output.resolve())
    run(*command)
